import Foundation
import Combine

class OllamaManager: ObservableObject {
    static let shared = OllamaManager()
    
    @Published var isRunning = false
    @Published var installedModels: [String] = []
    @Published var isLoadingModels = false
    @Published var statusMessage = "Initializing..."
    @Published var serverVersion = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkStatus()
        setupStatusPolling()
    }
    
    private func setupStatusPolling() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                if self?.isRunning == true {
                    self?.checkStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    func checkStatus() {
        guard let url = URL(string: "http://localhost:11434/api/tags") else {
            statusMessage = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.isRunning = false
                    self?.statusMessage = "Not connected: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 {
                    self?.isRunning = true
                    self?.statusMessage = "Connected to Ollama"
                    self?.loadModels()
                    self?.getServerVersion()
                } else {
                    self?.isRunning = false
                    self?.statusMessage = "Connection failed"
                }
            }
        }.resume()
    }
    
    func startOllama() {
        statusMessage = "Starting Ollama..."
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
        task.arguments = ["serve"]
        
        do {
            try task.run()
            
            // Give it time to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.checkStatus()
            }
        } catch {
            statusMessage = "Failed to start: \(error.localizedDescription)"
        }
    }
    
    func stopOllama() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
        task.arguments = ["stop"]
        
        do {
            try task.run()
            isRunning = false
            statusMessage = "Ollama stopped"
        } catch {
            statusMessage = "Failed to stop: \(error.localizedDescription)"
        }
    }
    
    func loadModels() {
        isLoadingModels = true
        
        guard let url = URL(string: "http://localhost:11434/api/tags") else {
            isLoadingModels = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoadingModels = false
                
                if let error = error {
                    print("Error loading models: \(error)")
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    let response = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
                    self.installedModels = response.models.map { $0.name }.sorted()
                } catch {
                    print("Failed to decode models: \(error)")
                }
            }
        }.resume()
    }
    
    func pullModel(_ modelName: String) -> AnyPublisher<ProgressUpdate, Error> {
        let subject = PassthroughSubject<ProgressUpdate, Error>()
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
        task.arguments = ["pull", modelName]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                let progress = ProgressUpdate.parseFromOutput(output)
                subject.send(progress)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let error = String(data: data, encoding: .utf8), !error.isEmpty {
                subject.send(completion: .failure(NSError(domain: "Ollama", code: 1, userInfo: [NSLocalizedDescriptionKey: error])))
            }
        }
        
        task.terminationHandler = { process in
            if process.terminationStatus == 0 {
                subject.send(completion: .finished)
                DispatchQueue.main.async {
                    self.loadModels()
                }
            }
        }
        
        do {
            try task.run()
        } catch {
            subject.send(completion: .failure(error))
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    private func getServerVersion() {
        guard let url = URL(string: "http://localhost:11434/api/version") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data,
               let versionInfo = try? JSONDecoder().decode(VersionInfo.self, from: data) {
                DispatchQueue.main.async {
                    self.serverVersion = versionInfo.version
                }
            }
        }.resume()
    }
}

struct ProgressUpdate {
    let status: String
    let percentage: Double?
    
    static func parseFromOutput(_ output: String) -> ProgressUpdate {
        if output.contains("pulling manifest") {
            return ProgressUpdate(status: "Downloading manifest...", percentage: nil)
        } else if let range = output.range(of: "\\d+\\.\\d+%", options: .regularExpression) {
            let percentString = String(output[range]).replacingOccurrences(of: "%", with: "")
            let percentage = Double(percentString) ?? 0
            return ProgressUpdate(status: "Downloading layers...", percentage: percentage)
        } else if output.contains("verifying sha256 digest") {
            return ProgressUpdate(status: "Verifying...", percentage: nil)
        } else if output.contains("writing manifest") {
            return ProgressUpdate(status: "Writing manifest...", percentage: nil)
        } else if output.contains("success") {
            return ProgressUpdate(status: "Success!", percentage: 100)
        }
        return ProgressUpdate(status: output.trimmingCharacters(in: .whitespacesAndNewlines), percentage: nil)
    }
}

struct VersionInfo: Codable {
    let version: String
}