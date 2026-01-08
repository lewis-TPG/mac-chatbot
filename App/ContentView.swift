import SwiftUI

struct ContentView: View {
    @EnvironmentObject var ollamaManager: OllamaManager
    @EnvironmentObject var settings: AppSettings
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var showingSettings = false
    @State private var showingModels = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(chatViewModel: chatViewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            // Main chat area
            ChatView(viewModel: chatViewModel)
                .navigationTitle("Ollama Chat")
                .toolbar {
                    ToolbarItemGroup {
                        ConnectionStatusButton()
                        
                        Button(action: {
                            showingModels = true
                        }) {
                            Label("Models", systemImage: "cpu")
                        }
                        
                        Button(action: {
                            showingSettings = true
                        }) {
                            Label("Settings", systemImage: "gear")
                        }
                    }
                }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(ollamaManager)
                .frame(width: 500, height: 400)
        }
        .sheet(isPresented: $showingModels) {
            ModelsView()
                .environmentObject(ollamaManager)
                .environmentObject(settings)
                .frame(width: 400, height: 500)
        }
        .onAppear {
            ollamaManager.checkStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearChat)) { _ in
            chatViewModel.clearChat()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showingSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openModels)) { _ in
            showingModels = true
        }
    }
}

struct SidebarView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @EnvironmentObject var ollamaManager: OllamaManager
    @State private var showingNewChatAlert = false
    
    var body: some View {
        List {
            Section("Chats") {
                Button(action: {
                    chatViewModel.clearChat()
                }) {
                    Label("New Chat", systemImage: "plus.bubble")
                }
                
                ForEach(chatViewModel.savedChats.prefix(5)) { chat in
                    Button(action: {
                        chatViewModel.loadChat(chat)
                    }) {
                        VStack(alignment: .leading) {
                            Text(chat.title)
                                .lineLimit(1)
                            Text(chat.lastMessagePreview)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Section("Status") {
                HStack {
                    Circle()
                        .fill(ollamaManager.isRunning ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(ollamaManager.isRunning ? "Connected" : "Disconnected")
                    Spacer()
                }
                
                if ollamaManager.isRunning {
                    Text("\(ollamaManager.installedModels.count) models")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button(action: ollamaManager.checkStatus) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

struct ConnectionStatusButton: View {
    @EnvironmentObject var ollamaManager: OllamaManager
    
    var body: some View {
        Menu {
            if ollamaManager.isRunning {
                Text("Connected to Ollama")
                    .font(.caption)
                
                Divider()
                
                ForEach(ollamaManager.installedModels.prefix(5), id: \.self) { model in
                    Text(model)
                }
                
                if ollamaManager.installedModels.count > 5 {
                    Text("+ \(ollamaManager.installedModels.count - 5) more...")
                }
                
                Divider()
                
                Button("Stop Ollama") {
                    ollamaManager.stopOllama()
                }
            } else {
                Button("Start Ollama") {
                    ollamaManager.startOllama()
                }
            }
            
            Button("Check Status") {
                ollamaManager.checkStatus()
            }
        } label: {
            HStack {
                Circle()
                    .fill(ollamaManager.isRunning ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(ollamaManager.isRunning ? "Connected" : "Disconnected")
                    .font(.caption)
            }
        }
        .menuStyle(.borderlessButton)
    }
}