import SwiftUI

struct SettingsView: View {
    @StateObject private var service = OllamaService()
    @AppStorage("selectedModel") private var selectedModel = "llama3.2"
    
    var body: some View {
        Form {
            Picker("Model", selection: $selectedModel) {
                ForEach(service.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .onChange(of: selectedModel) { newValue in
                service.currentModel = newValue
            }
            
            Button("Refresh Models") {
                service.loadAvailableModels()
            }
        }
        .padding()
        .frame(width: 300, height: 200)
        .onAppear {
            service.loadAvailableModels()
        }
    }
}