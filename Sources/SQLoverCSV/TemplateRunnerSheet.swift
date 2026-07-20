import SwiftUI

/// Окно запуска шаблона с заполнением параметров.
struct TemplateRunnerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: AppState
    
    let template: QueryTemplate
    var onEdit: () -> Void
    
    @State private var values: [String: String] = [:]
    @State private var showPreview = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if template.parameters.isEmpty {
                        noParamsView
                    } else {
                        parametersForm
                    }
                    
                    previewSection
                }
                .padding(20)
            }
            
            Divider()
            footer
        }
        .frame(width: 480, height: template.parameters.isEmpty ? 340 : 420)
        .onAppear {
            for param in template.parameters {
                values[param.name] = param.defaultValue
            }
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.headline)
                Text("\(template.parameters.count) параметров")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onEdit()
                dismiss()
            } label: {
                Label("Изменить", systemImage: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
    }
    
    private var noParamsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Шаблон без параметров")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Запрос будет выполнен как есть.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var parametersForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Заполни параметры")
                .font(.subheadline.weight(.medium))
            
            ForEach(template.parameters) { param in
                HStack {
                    Text(param.label)
                        .frame(width: 140, alignment: .leading)
                    TextField(param.defaultValue.isEmpty ? "Введи значение" : param.defaultValue, text: binding(for: param.name))
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SQL-запрос")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Toggle("Предпросмотр", isOn: $showPreview)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            
            if showPreview {
                Text(renderedSQL)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.05))
                    )
            } else {
                Text(template.sql)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.03))
                    )
            }
        }
    }
    
    private var footer: some View {
        HStack {
            Button("Вставить SQL") {
                state.query = renderedSQL
                dismiss()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("Отмена") {
                dismiss()
            }
            .keyboardShortcut(.escape)
            
            Button("Выполнить") {
                state.query = renderedSQL
                state.runQuery()
                dismiss()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }
    
    private var renderedSQL: String {
        template.render(with: values)
    }
    
    private func binding(for name: String) -> Binding<String> {
        Binding(
            get: { values[name] ?? "" },
            set: { values[name] = $0 }
        )
    }
}
