import SwiftUI

@main
struct OllamaChatApp: App {
    @StateObject private var ollamaManager = OllamaManager.shared
    @StateObject private var settings = AppSettings()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ollamaManager)
                .environmentObject(settings)
                .frame(minWidth: 700, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Clear Chat") {
                    NotificationCenter.default.post(name: .clearChat, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command])
                
                Divider()
                
                Button("Settings") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
            
            CommandGroup(replacing: .help) {
                Button("Check Ollama Status") {
                    ollamaManager.checkStatus()
                }
                
                Button("Download Models") {
                    NotificationCenter.default.post(name: .openModels, object: nil)
                }
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(ollamaManager)
        }
    }
}

// Notification extensions
extension Notification.Name {
    static let clearChat = Notification.Name("clearChat")
    static let openSettings = Notification.Name("openSettings")
    static let openModels = Notification.Name("openModels")
}

// App settings
class AppSettings: ObservableObject {
    @AppStorage("selectedModel") var selectedModel = "llama3.2"
    @AppStorage("temperature") var temperature = 0.7
    @AppStorage("maxTokens") var maxTokens = 2048
    @AppStorage("enableStreaming") var enableStreaming = true
    @AppStorage("saveChatHistory") var saveChatHistory = true
    @AppStorage("textSize") var textSize: Double = 14.0
}