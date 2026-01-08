import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject var settings: AppSettings
    @State private var scrollToBottom = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                                .padding(.horizontal)
                        }
                        
                        // Streaming response
                        if let streamId = viewModel.currentStreamUUID,
                           let streamedText = viewModel.streamedResponses[streamId] {
                            MessageView(message: ChatMessage(content: streamedText, isUser: false))
                                .id("streaming-\(streamId)")
                                .padding(.horizontal)
                        }
                        
                        // Typing indicator
                        if viewModel.isTyping && viewModel.currentStreamUUID == nil {
                            TypingIndicator()
                                .padding(.horizontal)
                        }
                        
                        // Scroll anchor
                        Color.clear
                            .frame(height: 20)
                            .id("bottomAnchor")
                    }
                    .padding(.vertical)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.currentStreamUUID) { _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.streamedResponses.count) { _ in
                    scrollToBottom(proxy)
                }
            }
            
            // Input area
            VStack(spacing: 12) {
                Divider()
                
                HStack(alignment: .bottom, spacing: 12) {
                    // Stop button when streaming
                    if viewModel.isTyping {
                        Button(action: {
                            viewModel.cancelStreaming()
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Stop generating")
                    }
                    
                    // Text input
                    TextField("Message Ollama...", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                        .lineLimit(1...6)
                        .onSubmit {
                            if !viewModel.inputText.isEmpty && !viewModel.isTyping {
                                viewModel.sendMessage()
                            }
                        }
                        .disabled(viewModel.isTyping)
                        .overlay(alignment: .trailing) {
                            if !viewModel.inputText.isEmpty {
                                Button(action: {
                                    viewModel.inputText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    
                    // Send button
                    Button(action: {
                        viewModel.sendMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTyping)
                    .keyboardShortcut(.return, modifiers: [])
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(.ultraThinMaterial)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.1)) {
            proxy.scrollTo("bottomAnchor", anchor: .bottom)
        }
    }
}

struct MessageView: View {
    let message: ChatMessage
    @State private var isHovering = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !message.isUser {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                    .padding(.top, 4)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.isUser ? Color.blue : Color.gray.opacity(0.15))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .contextMenu {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        }
                        
                        Button("Copy as JSON") {
                            if let json = try? JSONEncoder().encode(message),
                               let jsonString = String(data: json, encoding: .utf8) {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(jsonString, forType: .string)
                            }
                        }
                    }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.isUser {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                    .frame(width: 24, height: 24)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .padding(.horizontal, 4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}