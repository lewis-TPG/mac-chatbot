import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isTyping = false
    @Published var currentResponse = ""
    @Published var savedChats: [SavedChat] = []
    @Published var streamedResponses: [UUID: String] = [:]
    
    private let ollamaService = OllamaService()
    private var cancellables = Set<AnyCancellable>()
    private var currentStreamUUID: UUID?
    
    init() {
        loadSavedChats()
        loadLastChat()
        
        // Welcome message
        if messages.isEmpty {
            let welcomeMessage = ChatMessage(
                content: "Hello! I'm your local AI assistant powered by Ollama. How can I help you today?",
                isUser: false
            )
            messages.append(welcomeMessage)
        }
    }
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(content: inputText, isUser: true)
        messages.append(userMessage)
        
        let messageToSend = inputText
        inputText = ""
        isTyping = true
        
        // Start streaming response
        streamResponse(to: messageToSend)
    }
    
    private func streamResponse(to prompt: String) {
        currentStreamUUID = UUID()
        guard let streamId = currentStreamUUID else { return }
        
        ollamaService.streamMessage(prompt)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isTyping = false
                
                if case .failure(let error) = completion {
                    let errorMessage = ChatMessage(
                        content: "Error: \(error.localizedDescription)",
                        isUser: false
                    )
                    self?.messages.append(errorMessage)
                } else {
                    // Save the completed response
                    if let fullResponse = self?.streamedResponses[streamId] {
                        let aiMessage = ChatMessage(content: fullResponse, isUser: false)
                        self?.messages.append(aiMessage)
                        self?.saveCurrentChat()
                    }
                }
                
                self?.streamedResponses.removeValue(forKey: streamId)
                self?.currentStreamUUID = nil
                
            }, receiveValue: { [weak self] chunk in
                if self?.streamedResponses[streamId] == nil {
                    self?.streamedResponses[streamId] = ""
                }
                self?.streamedResponses[streamId]? += chunk
            })
            .store(in: &cancellables)
    }
    
    func cancelStreaming() {
        if let streamId = currentStreamUUID {
            streamedResponses.removeValue(forKey: streamId)
            currentStreamUUID = nil
        }
        isTyping = false
    }
    
    func clearChat() {
        messages.removeAll()
        let welcomeMessage = ChatMessage(
            content: "Hello! I'm your local AI assistant powered by Ollama. How can I help you today?",
            isUser: false
        )
        messages.append(welcomeMessage)
        saveCurrentChat()
    }
    
    func saveCurrentChat() {
        guard !messages.isEmpty else { return }
        
        let chat = SavedChat(
            id: UUID(),
            title: messages.first?.content.prefix(30).appending("...") ?? "New Chat",
            messages: messages,
            lastModified: Date(),
            lastMessagePreview: messages.last?.content.prefix(50).appending("...") ?? ""
        )
        
        // Remove existing chats with same preview
        savedChats.removeAll { $0.lastMessagePreview == chat.lastMessagePreview }
        savedChats.insert(chat, at: 0)
        
        // Keep only last 20 chats
        if savedChats.count > 20 {
            savedChats = Array(savedChats.prefix(20))
        }
        
        saveChatsToDisk()
    }
    
    func loadChat(_ chat: SavedChat) {
        messages = chat.messages
    }
    
    private func loadSavedChats() {
        if let data = UserDefaults.standard.data(forKey: "savedChats"),
           let chats = try? JSONDecoder().decode([SavedChat].self, from: data) {
            savedChats = chats
        }
    }
    
    private func loadLastChat() {
        if let lastChat = savedChats.first {
            messages = lastChat.messages
        }
    }
    
    private func saveChatsToDisk() {
        if let data = try? JSONEncoder().encode(savedChats) {
            UserDefaults.standard.set(data, forKey: "savedChats")
        }
    }
}

struct SavedChat: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var lastModified: Date
    var lastMessagePreview: String
}