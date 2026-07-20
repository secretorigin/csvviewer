import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @State private var isDropTargeted = false
    @State private var showAIChat = false

    var body: some View {
        HStack(spacing: 0) {
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 380)
            } detail: {
                DetailView()
            }
            .frame(maxWidth: .infinity)
            
            if showAIChat {
                Divider()
                    .ignoresSafeArea()
                AIChatView()
                    .ignoresSafeArea(edges: .top)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showAIChat)
        .navigationTitle("")
        .background(WindowConfigurator())
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    state.presentOpenPanel()
                } label: {
                    Label("Открыть CSV", systemImage: "plus")
                }
                .help("Открыть CSV-файл (⌘O)")

                Button {
                    state.runQuery()
                } label: {
                    Label("Выполнить", systemImage: "play.fill")
                }
                .disabled(state.isRunning)
                .help("Выполнить запрос (⌘↵)")

                Button {
                    state.exportResult()
                } label: {
                    Label("Экспорт CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(!state.canExport)
                .help("Сохранить результат запроса в CSV (⌘S)")

                Divider()

                Button {
                    showAIChat.toggle()
                } label: {
                    Label("AI Ассистент", systemImage: "sparkles")
                        .foregroundStyle(showAIChat ? Color.green : Color.primary)
                }
                .help("Показать/скрыть AI-ассистента для генерации SQL")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .background(Color.accentColor.opacity(0.06))
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { urls.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            let csvURLs = urls.filter { url in
                let ext = url.pathExtension.lowercased()
                return ext == "csv" || ext == "tsv" || ext == "txt"
            }
            if !csvURLs.isEmpty {
                state.load(urls: csvURLs)
            }
        }
        return true
    }
}
