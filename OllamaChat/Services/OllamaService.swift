import Foundation
import Combine

class OllamaService: ObservableObject {
    private let baseURL = "http://localhost:11434"
    @Published var currentModel = "llama3.2"
    
    func streamMessage(_ message: String) -> AnyPublisher<String, Error> {
        let request = OllamaRequest(
            model: currentModel,
            prompt: message,
            stream: true,
            options: [
                "temperature": 0.7,
                "num_predict": 2048
            ]
        )
        
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 300 // 5 minutes for long responses
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { output -> Data in
                guard let response = output.response as? HTTPURLResponse,
                      response.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return output.data
            }
            .flatMap { data -> AnyPublisher<String, Error> in
                let lines = String(data: data, encoding: .utf8)?
                    .components(separatedBy: "\n")
                    .filter { !$0.isEmpty } ?? []
                
                let publishers = lines
                    .compactMap { line -> String? in
                        guard let data = line.data(using: .utf8),
                              let response = try? JSONDecoder().decode(StreamResponse.self, from: data) else {
                            return nil
                        }
                        return response.response
                    }
                    .map { Just($0).setFailureType(to: Error.self).eraseToAnyPublisher() }
                
                return Publishers.MergeMany(publishers).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func generateMessage(_ message: String) -> AnyPublisher<String, Error> {
        let request = OllamaRequest(
            model: currentModel,
            prompt: message,
            stream: false,
            options: [
                "temperature": 0.7,
                "num_predict": 2048
            ]
        )
        
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse,
                      response.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return output.data
            }
            .decode(type: OllamaResponse.self, decoder: JSONDecoder())
            .map { $0.response }
            .eraseToAnyPublisher()
    }
}

struct StreamResponse: Codable {
    let model: String
    let createdAt: String
    let response: String
    let done: Bool
    
    enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case response
        case done
    }
}