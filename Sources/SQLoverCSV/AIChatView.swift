import SwiftUI
import AppKit

// MARK: - Кастомное поле ввода с поддержкой Shift+Enter

struct ChatInputField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = ChatTextView()
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.onSubmit = onSubmit
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        context.coordinator.textView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ChatTextView else { return }
        
        if textView.string != text {
            textView.string = text
        }
        
        // Placeholder
        textView.placeholderString = placeholder
        textView.needsDisplay = true
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputField
        weak var textView: NSTextView?
        
        init(_ parent: ChatInputField) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

class ChatTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var placeholderString: String = ""
    
    override func keyDown(with event: NSEvent) {
        // Enter без Shift — отправка
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
            onSubmit?()
            return
        }
        super.keyDown(with: event)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Рисуем placeholder если текст пустой
        if string.isEmpty && !placeholderString.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: font ?? .systemFont(ofSize: 13)
            ]
            let rect = NSRect(x: 5, y: 0, width: bounds.width - 10, height: bounds.height)
            placeholderString.draw(in: rect, withAttributes: attrs)
        }
    }
}

struct AIChatView: View {
    @EnvironmentObject private var state: AppState
    @State private var userInput = ""
    @State private var isLoading = false
    
    private let assistant = AIAssistant()
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            if state.chatMessages.isEmpty && !isLoading {
                emptyState
            } else {
                messageList
            }
            
            Divider()
            inputArea
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea())
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
    
    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.green)
            Text("SQL Ассистент")
                .font(.headline)
            Spacer()
            Text("Codex")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(12)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 36))
                .foregroundStyle(.green.opacity(0.7))
            Text("Опиши, какой запрос тебе нужен")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if state.hasTables {
                Text("Codex сгенерирует SQL на основе схемы твоих таблиц.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Сначала загрузи CSV-файлы.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(state.chatMessages) { message in
                        MessageBubble(message: message, onInsert: insertSQL)
                            .id(message.id)
                    }
                    
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Генерирую SQL…")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .id("loading")
                    }
                    
                    if let error = state.chatError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 12)
                        .contextMenu {
                            Button("Копировать ошибку") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(error, forType: .string)
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: state.chatMessages.count) { _ in
                if let last = state.chatMessages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ChatInputField(
                text: $userInput,
                placeholder: "Опиши запрос…",
                onSubmit: {
                    if canSend {
                        sendMessage()
                    }
                }
            )
            .frame(minHeight: 20, maxHeight: 80)
            
            Button {
                if isLoading {
                    // TODO: cancel
                } else {
                    sendMessage()
                }
            } label: {
                Image(systemName: isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(canSend || isLoading ? Color.accentColor : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(!canSend && !isLoading)
            .help(canSend ? "Отправить запрос" : (state.hasTables ? "Введи запрос" : "Сначала загрузи CSV"))
        }
        .padding(12)
    }
    
    private var canSend: Bool {
        !userInput.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }
    
    private func sendMessage() {
        let query = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        userInput = ""
        state.chatError = nil
        
        state.chatMessages.append(ChatMessage(role: .user, content: query))
        isLoading = true
        
        Task { @MainActor in
            do {
                // Получаем таблицы с примерами данных
                let tablesWithSamples = await state.getTablesWithSamples()
                // Передаём историю без последнего сообщения (оно уже добавлено выше)
                let history = Array(state.chatMessages.dropLast())
                let sql = try await assistant.generateSQL(userQuery: query, tables: tablesWithSamples, chatHistory: history)
                state.chatMessages.append(ChatMessage(role: .assistant, content: sql))
                isLoading = false
            } catch {
                state.chatError = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func insertSQL(_ sql: String) {
        state.query = sql
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let onInsert: (String) -> Void
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            HStack {
                if message.role == .user { Spacer(minLength: 40) }
                
                Text(message.content)
                    .font(.system(size: 13, design: message.role == .assistant ? .monospaced : .default))
                    .textSelection(.enabled)
                    .padding(10)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if message.role == .assistant { Spacer(minLength: 40) }
            }
            
            if message.role == .assistant {
                HStack(spacing: 12) {
                    Button {
                        onInsert(message.content)
                    } label: {
                        Label("Вставить в редактор", systemImage: "square.and.pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Скопировано" : "Копировать", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.leading, 12)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
    
    private var bubbleBackground: some View {
        Group {
            if message.role == .user {
                Color.accentColor.opacity(0.2)
            } else {
                Color.primary.opacity(0.08)
            }
        }
    }
}
