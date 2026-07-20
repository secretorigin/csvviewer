import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var templateStore: TemplateStore
    @State private var selectedTemplateID: QueryTemplate.ID?
    @State private var templateToRun: QueryTemplate?
    @State private var templateToEdit: QueryTemplate?

    var body: some View {
        List(selection: $state.selectedTableID) {
            Section {
                if state.tables.isEmpty {
                    emptyHint
                } else {
                    ForEach(state.tables) { table in
                        TableRow(table: table)
                            .tag(table.id)
                            .contextMenu {
                                Button("Показать первые 100 строк") {
                                    state.query = state.defaultQuery(for: table)
                                    state.runQuery()
                                }
                                Button("Скопировать имя таблицы") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(table.name, forType: .string)
                                }
                                Divider()
                                Button("Убрать таблицу", role: .destructive) {
                                    state.removeTable(table)
                                }
                            }
                    }
                }
            } header: {
                Text("Таблицы")
            }
            
            Section {
                if templateStore.templates.isEmpty {
                    Text("Нет сохранённых шаблонов")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(templateStore.templates) { template in
                        TemplateRow(template: template)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                templateToRun = template
                            }
                            .contextMenu {
                                Button("Выполнить") {
                                    templateToRun = template
                                }
                                Button("Вставить SQL") {
                                    state.query = template.sql
                                }
                                Divider()
                                Button("Редактировать") {
                                    templateToEdit = template
                                }
                                Button("Удалить", role: .destructive) {
                                    templateStore.delete(template)
                                }
                            }
                    }
                }
            } header: {
                Text("Шаблоны")
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            if state.isLoadingFiles {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Загрузка файлов…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(.ultraThinMaterial)
            }
        }
        .sheet(item: $templateToRun) { template in
            TemplateRunnerSheet(template: template) {
                templateToEdit = template
            }
            .environmentObject(state)
        }
        .sheet(item: $templateToEdit) { template in
            TemplateEditorSheet(store: templateStore, existingTemplate: template)
        }
    }

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Нет загруженных файлов")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Открой CSV кнопкой сверху или перетащи файл в окно.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

private struct TemplateRow: View {
    let template: QueryTemplate
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(template.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if !template.parameters.isEmpty {
                    Text("\(template.parameters.count) парам.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct TableRow: View {
    @EnvironmentObject private var state: AppState
    let table: LoadedTable
    @State private var expanded = false
    @State private var hoveredColumn: ColumnInfo.ID?

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(table.columns) { column in
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 4))
                        .foregroundStyle(.tertiary)
                    Text(column.name)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                    Spacer(minLength: 4)

                    if hoveredColumn == column.id {
                        Button {
                            copyToClipboard(SQLEngine.quotedIdentifier(column.name))
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Скопировать имя колонки")
                    }

                    Text(column.type)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.leading, 4)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onHover { hovering in
                    hoveredColumn = hovering ? column.id : nil
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tablecells")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(table.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text("\(table.rowCount) строк · \(table.columns.count) кол.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Button {
                    state.removeTable(table)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Убрать таблицу")
            }
            .contentShape(Rectangle())
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
