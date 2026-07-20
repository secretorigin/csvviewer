import Foundation

/// Сообщение в чате с ассистентом.
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    var role: Role
    var content: String
    
    enum Role: String {
        case user
        case assistant
        case system
    }
}

/// Клиент для генерации SQL через OpenAI Codex CLI.
actor AIAssistant {
    
    init() {}
    
    var hasAPIKey: Bool { true }  // Codex CLI использует свою авторизацию
    
    /// Генерирует SQL на основе схемы таблиц, истории чата и запроса пользователя.
    func generateSQL(userQuery: String, tables: [TableWithSamples], chatHistory: [ChatMessage]) async throws -> String {
        return try await generateWithCodex(userQuery: userQuery, tables: tables, chatHistory: chatHistory)
    }
    
    // MARK: - Codex CLI (через Python-скрипт)
    
    private func generateWithCodex(userQuery: String, tables: [TableWithSamples], chatHistory: [ChatMessage]) async throws -> String {
        let tablesJSON = try buildTablesJSON(tables: tables)
        let historyJSON = try buildHistoryJSON(chatHistory: chatHistory)
        
        // Путь к скрипту
        let scriptPath = findScript()
        guard let scriptPath else {
            throw AIError.scriptNotFound
        }
        
        // Запускаем Python-скрипт
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", scriptPath, userQuery, tablesJSON, historyJSON]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw AIError.parseError
        }
        
        // Парсим JSON-ответ
        guard let jsonData = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw AIError.apiError("Неверный ответ скрипта: \(output)")
        }
        
        if let error = json["error"] as? String {
            throw AIError.apiError(error)
        }
        
        guard let sql = json["sql"] as? String else {
            throw AIError.parseError
        }
        
        return sql
    }
    
    private func findScript() -> String? {
        // Ищем скрипт относительно бинарника или в известных местах
        let candidates = [
            Bundle.main.bundlePath + "/../scripts/generate_sql.py",
            Bundle.main.bundlePath + "/Contents/Resources/scripts/generate_sql.py",
            FileManager.default.currentDirectoryPath + "/scripts/generate_sql.py",
            NSHomeDirectory() + "/Desktop/projects/sql-over-csv/scripts/generate_sql.py",
        ]
        
        for path in candidates {
            let resolved = (path as NSString).standardizingPath
            if FileManager.default.fileExists(atPath: resolved) {
                return resolved
            }
        }
        return nil
    }
    
    private func buildTablesJSON(tables: [TableWithSamples]) throws -> String {
        let tablesData: [[String: Any]] = tables.map { item in
            [
                "name": item.table.name,
                "rowCount": item.table.rowCount,
                "columns": item.table.columns.map { ["name": $0.name, "type": $0.type] },
                "sampleRows": item.sampleRows.map { row in
                    row.map { $0 ?? "NULL" }
                }
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: tablesData)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    
    private func buildHistoryJSON(chatHistory: [ChatMessage]) throws -> String {
        let historyData: [[String: String]] = chatHistory.map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        }
        let data = try JSONSerialization.data(withJSONObject: historyData)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

enum AIError: LocalizedError {
    case apiError(String)
    case parseError
    case scriptNotFound
    
    var errorDescription: String? {
        switch self {
        case .apiError(let msg):
            return msg
        case .parseError:
            return "Не удалось разобрать ответ от Codex."
        case .scriptNotFound:
            return "Скрипт generate_sql.py не найден."
        }
    }
}
