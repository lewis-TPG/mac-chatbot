import SwiftUI

struct StatusView: View {
    @ObservedObject var ollamaManager = OllamaManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(ollamaManager.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text("Ollama Status:")
                    .font(.headline)
                
                Text(ollamaManager.statusMessage)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            if !ollamaManager.installedModels.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Installed Models:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(ollamaManager.installedModels.prefix(3), id: \.self) { model in
                        Text("• \(model)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if ollamaManager.installedModels.count > 3 {
                        Text("+ \(ollamaManager.installedModels.count - 3) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                if !ollamaManager.isRunning {
                    Button("Start Ollama") {
                        ollamaManager.startOllama()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Stop Ollama") {
                        ollamaManager.stopOllama()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Refresh") {
                    ollamaManager.checkStatus()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onAppear {
            ollamaManager.checkStatus()
        }
    }
}