import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            QueryEditorView()
            Divider().opacity(0.4)
            ResultArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
}

/// Область под редактором: результат, сообщение, ошибка, загрузка или подсказка.
private struct ResultArea: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Group {
            if state.isRunning {
                statusView {
                    ProgressView()
                        .controlSize(.large)
                    Text("Выполняю запрос…")
                        .foregroundStyle(.secondary)
                }
            } else if let error = state.errorMessage {
                errorView(error)
            } else if let message = state.infoMessage {
                statusView {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.green)
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            } else if let result = state.result {
                ResultTableView(result: result)
            } else if !state.hasTables {
                EmptyStateView()
            } else {
                statusView {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("Напиши запрос и нажми ⌘↵")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func statusView<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 14) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ошибка запроса", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
            ScrollView {
                Text(text)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.08))
                .padding(16)
        )
    }
}

/// Экран приветствия, когда ничего не загружено.
private struct EmptyStateView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text("Открой CSV, чтобы начать")
                    .font(.title2.weight(.semibold))
                Text("Перетащи файл сюда или нажми кнопку ниже.\nЗатем пиши SQL-запросы в стиле PostgreSQL.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Button {
                state.presentOpenPanel()
            } label: {
                Label("Открыть CSV", systemImage: "plus")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
