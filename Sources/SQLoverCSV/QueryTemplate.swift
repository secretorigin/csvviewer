import Foundation

/// Параметр шаблона запроса.
struct TemplateParameter: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var label: String
    var defaultValue: String
    
    init(id: UUID = UUID(), name: String, label: String = "", defaultValue: String = "") {
        self.id = id
        self.name = name
        self.label = label.isEmpty ? name : label
        self.defaultValue = defaultValue
    }
}

/// Шаблон SQL-запроса с параметрами.
struct QueryTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var sql: String
    var parameters: [TemplateParameter]
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), name: String, sql: String, parameters: [TemplateParameter] = []) {
        self.id = id
        self.name = name
        self.sql = sql
        self.parameters = parameters
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Извлекает параметры из SQL по паттерну $name или $1.
    static func extractParameters(from sql: String) -> [TemplateParameter] {
        let pattern = #"\$([a-zA-Z_][a-zA-Z0-9_]*|\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let matches = regex.matches(in: sql, range: NSRange(sql.startIndex..., in: sql))
        var seen = Set<String>()
        var params: [TemplateParameter] = []
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: sql) {
                let name = String(sql[range])
                if !seen.contains(name) {
                    seen.insert(name)
                    params.append(TemplateParameter(name: name))
                }
            }
        }
        return params
    }
    
    /// Подставляет значения параметров в SQL.
    func render(with values: [String: String]) -> String {
        var result = sql
        for param in parameters {
            let value = values[param.name] ?? param.defaultValue
            let escaped = value.replacingOccurrences(of: "'", with: "''")
            result = result.replacingOccurrences(of: "$\(param.name)", with: "'\(escaped)'")
        }
        return result
    }
}

/// Менеджер шаблонов с сохранением в UserDefaults.
@MainActor
final class TemplateStore: ObservableObject {
    @Published var templates: [QueryTemplate] = []
    
    private let storageKey = "com.sqlovercsv.templates"
    
    init() {
        load()
    }
    
    func save(_ template: QueryTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            var updated = template
            updated.updatedAt = Date()
            templates[index] = updated
        } else {
            templates.append(template)
        }
        persist()
    }
    
    func delete(_ template: QueryTemplate) {
        templates.removeAll { $0.id == template.id }
        persist()
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([QueryTemplate].self, from: data) else {
            return
        }
        templates = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    private func persist() {
        guard let data = try? JSONEncoder().encode(templates) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
