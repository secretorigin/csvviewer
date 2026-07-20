import SwiftUI

struct QueryEditorView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var templateStore: TemplateStore
    @State private var showTemplateEditor = false

    var body: some View {
        VStack(spacing: 10) {
            editor
            controlBar
        }
        .padding(16)
    }

    private var editor: some View {
        CodeEditor(text: $state.query)
            .frame(minHeight: 120, maxHeight: 210)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Text("PostgreSQL-совместимый SQL (движок DuckDB)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let status = state.exportStatus {
                Label(status, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .lineLimit(1)
            }

            if let result = state.result {
                Text(resultSummary(result))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button {
                showTemplateEditor = true
            } label: {
                Label("Сохранить как шаблон", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Сохранить запрос как шаблон с параметрами")

            if state.result != nil {
                Button {
                    state.exportResult()
                } label: {
                    if state.isExporting {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Экспорт CSV", systemImage: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!state.canExport)
                .help("Сохранить результат запроса в CSV (⌘S)")
            }

            Button {
                state.runQuery()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("Выполнить")
                    Text("⌘↵")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(state.isRunning || state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .sheet(isPresented: $showTemplateEditor) {
            TemplateEditorSheet(store: templateStore, initialSQL: state.query)
        }
    }

    private func resultSummary(_ result: QueryResult) -> String {
        let rows = result.truncated
            ? "\(result.displayedRows) из \(result.totalRows) строк"
            : "\(result.totalRows) строк"
        let ms = String(format: "%.0f мс", result.elapsed * 1000)
        return "\(rows) · \(ms)"
    }
}
