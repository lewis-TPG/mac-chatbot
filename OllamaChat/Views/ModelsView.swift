import SwiftUI
import Combine

struct ModelsView: View {
    @EnvironmentObject var ollamaManager: OllamaManager
    @EnvironmentObject var settings: AppSettings
    @State private var newModelName = ""
    @State private var isDownloading = false
    @State private var downloadProgress: ProgressUpdate?
    @State private var downloadCancellable: AnyCancellable?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Models")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    ollamaManager.loadModels()
                }
                .buttonStyle(.borderless)
            }
            .padding()
            
            Divider()
            
            // Models list
            List {
                ForEach(ollamaManager.installedModels, id: \.self) { model in
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(settings.selectedModel == model ? .blue : .secondary)
                        Text(model)
                            .font(.body)
                        
                        Spacer()
                        
                        if settings.selectedModel == model {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        settings.selectedModel = model
                    }
                }
                
                if ollamaManager.installedModels.isEmpty {
                    Text("No models installed")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .listStyle(.plain)
            
            Divider()
            
            // Download section
            VStack(alignment: .leading, spacing: 12) {
                Text("Download New Model")
                    .font(.headline)
                
                HStack {
                    TextField("Model name (e.g., llama3.2, mistral)", text: $newModelName)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isDownloading)
                    
                    Button("Download") {
                        downloadModel()
                    }
                    .disabled(newModelName.isEmpty || isDownloading)
                }
                
                if isDownloading, let progress = downloadProgress {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: progress.percentage, total: 100)
                            .progressViewStyle(.linear)
                        
                        Text(progress.status)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if progress.percentage == 100 {
                            Text("Model downloaded successfully!")
                                .foregroundColor(.green)
                                .font(.caption)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        isDownloading = false
                                        downloadProgress = nil
                                        newModelName = ""
                                    }
                                }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .onDisappear {
            downloadCancellable?.cancel()
        }
    }
    
    private func downloadModel() {
        isDownloading = true
        downloadProgress = ProgressUpdate(status: "Starting download...", percentage: nil)
        
        downloadCancellable = ollamaManager.pullModel(newModelName)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    downloadProgress = ProgressUpdate(status: "Download complete!", percentage: 100)
                case .failure(let error):
                    downloadProgress = ProgressUpdate(
                        status: "Error: \(error.localizedDescription)",
                        percentage: nil
                    )
                    isDownloading = false
                }
            }, receiveValue: { progress in
                downloadProgress = progress
            })
    }
}