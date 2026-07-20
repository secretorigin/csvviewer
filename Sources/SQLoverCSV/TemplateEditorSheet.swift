import SwiftUI

/// Окно создания/редактирования шаблона запроса.
struct TemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TemplateStore
    
    var existingTemplate: QueryTemplate?
    var initialSQL: String
    
    @State private var name: String = ""
    @State private var sql: String = ""
    @State private var parameters: [TemplateParameter] = []
    
    init(store: TemplateStore, existingTemplate: QueryTemplate? = nil, initialSQL: String = "") {
        self.store = store
        self.existingTemplate = existingTemplate
        self.initialSQL = initialSQL
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    nameSection
                    sqlSection
                    parametersSection
                }
                .padding(20)
            }
            
            Divider()
            footer
        }
        .frame(width: 560, height: 520)
        .onAppear {
            if let template = existingTemplate {
                name = template.name
                sql = template.sql
                parameters = template.parameters
            } else {
                sql = initialSQL
                parameters = QueryTemplate.extractParameters(from: initialSQL)
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text(existingTemplate == nil ? "Новый шаблон" : "Редактировать шаблон")
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Название")
                .font(.subheadline.weight(.medium))
            TextField("Например: Поиск по issue_key", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var sqlSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SQL-запрос")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button("Найти параметры") {
                    let found = QueryTemplate.extractParameters(from: sql)
                    // Merge: keep existing params with same name, add new ones
                    var merged: [TemplateParameter] = []
                    for foundParam in found {
                        if let existing = parameters.first(where: { $0.name == foundParam.name }) {
                            merged.append(existing)
                        } else {
                            merged.append(foundParam)
                        }
                    }
                    parameters = merged
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            Text("Используй $name или $1 для параметров")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextEditor(text: $sql)
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.1))
                )
        }
    }
    
    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Параметры")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button {
                    parameters.append(TemplateParameter(name: "param\(parameters.count + 1)"))
                } label: {
                    Label("Добавить", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            if parameters.isEmpty {
                Text("Параметры не найдены. Добавь $name в SQL или нажми «Добавить».")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach($parameters) { $param in
                    parameterRow(param: $param)
                }
            }
        }
    }
    
    private func parameterRow(param: Binding<TemplateParameter>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Имя (в SQL)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TextField("name", text: param.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Подпись")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TextField("Отображаемое имя", text: param.label)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("По умолчанию")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TextField("Значение", text: param.defaultValue)
                    .textFieldStyle(.roundedBorder)
            }
            
            Button {
                parameters.removeAll { $0.id == param.wrappedValue.id }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    private var footer: some View {
        HStack {
            if existingTemplate != nil {
                Button("Удалить", role: .destructive) {
                    if let template = existingTemplate {
                        store.delete(template)
                    }
                    dismiss()
                }
            }
            
            Spacer()
            
            Button("Отмена") {
                dismiss()
            }
            .keyboardShortcut(.escape)
            
            Button("Сохранить") {
                saveTemplate()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || sql.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(16)
    }
    
    private func saveTemplate() {
        let template = QueryTemplate(
            id: existingTemplate?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            sql: sql,
            parameters: parameters
        )
        store.save(template)
        dismiss()
    }
}
