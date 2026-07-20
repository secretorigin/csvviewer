import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {

    @Published var tables: [LoadedTable] = []
    @Published var query: String = AppState.welcomeQuery
    @Published var result: QueryResult?
    @Published var infoMessage: String?
    @Published var errorMessage: String?
    @Published var isRunning = false
    @Published var isExporting = false
    @Published var loadingFileCount = 0
    @Published var selectedTableID: LoadedTable.ID?

    /// SQL, породивший текущий результат (нужен для экспорта полного среза).
    @Published var lastResultQuery: String?
    /// Короткий статус последнего экспорта для отображения в интерфейсе.
    @Published var exportStatus: String?
    
    /// История сообщений AI-чата (сохраняется при скрытии панели).
    @Published var chatMessages: [ChatMessage] = []
    @Published var chatError: String?

    private let engine = SQLEngine()
    private let persistenceKey = "com.sqlovercsv.openedFiles"

    var isLoadingFiles: Bool { loadingFileCount > 0 }
    var hasTables: Bool { !tables.isEmpty }
    var canExport: Bool { result != nil && lastResultQuery != nil && !isExporting }

    // MARK: - Инициализация и восстановление сессии

    init() {
        restoreSession()
    }

    /// Загружает CSV-файлы, которые были открыты в прошлый раз.
    private func restoreSession() {
        guard let paths = UserDefaults.standard.stringArray(forKey: persistenceKey) else { return }
        var urlsToLoad: [URL] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                urlsToLoad.append(url)
            }
        }
        if !urlsToLoad.isEmpty {
            load(urls: urlsToLoad)
        }
    }

    /// Сохраняет список открытых файлов.
    private func saveSession() {
        let paths = tables.map { $0.path }
        UserDefaults.standard.set(paths, forKey: persistenceKey)
    }

    static let welcomeQuery = """
    -- Открой CSV-файл (кнопка сверху или перетащи его в окно),
    -- затем напиши SQL-запрос в стиле PostgreSQL и нажми ⌘↵.
    """

    // MARK: - Открытие файлов

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Выбери CSV-файлы"
        var types: [UTType] = [.commaSeparatedText, .plainText, .text]
        if let tsv = UTType(filenameExtension: "tsv") { types.append(tsv) }
        panel.allowedContentTypes = types
        panel.allowsOtherFileTypes = true

        if panel.runModal() == .OK {
            load(urls: panel.urls)
        }
    }

    func load(urls: [URL]) {
        for url in urls {
            loadingFileCount += 1
            let tableName = uniqueTableName(for: url)
            engine.loadCSV(url: url, tableName: tableName) { [weak self] result in
                guard let self else { return }
                self.loadingFileCount -= 1
                switch result {
                case .success(let table):
                    self.tables.append(table)
                    self.selectedTableID = table.id
                    self.query = self.defaultQuery(for: table)
                    self.errorMessage = nil
                    self.saveSession()
                case .failure(let error):
                    self.errorMessage = "Не удалось загрузить \(url.lastPathComponent): \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Запросы

    func runQuery() {
        let sql = AppState.normalizeQuotes(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sql.isEmpty else { return }
        guard !isRunning else { return }

        isRunning = true
        errorMessage = nil
        infoMessage = nil
        exportStatus = nil

        engine.run(sql: sql) { [weak self] result in
            guard let self else { return }
            self.isRunning = false
            switch result {
            case .success(let outcome):
                switch outcome {
                case .table(let queryResult):
                    self.result = queryResult
                    self.lastResultQuery = sql
                    self.infoMessage = nil
                case .message(let message):
                    self.result = nil
                    self.lastResultQuery = nil
                    self.infoMessage = message
                }
                self.errorMessage = nil
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Экспорт результата в CSV

    func exportResult() {
        guard let sql = lastResultQuery, result != nil, !isExporting else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "query_result.csv"
        panel.title = "Сохранить результат как CSV"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExporting = true
        exportStatus = nil
        engine.exportCSV(sql: sql, to: url) { [weak self] result in
            guard let self else { return }
            self.isExporting = false
            switch result {
            case .success:
                self.exportStatus = "Сохранено: \(url.lastPathComponent)"
                NSWorkspace.shared.activateFileViewerSelecting([url])
            case .failure(let error):
                self.errorMessage = "Не удалось экспортировать: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Удаление таблицы

    func removeTable(_ table: LoadedTable) {
        engine.dropTable(name: table.name) { [weak self] _ in
            guard let self else { return }
            self.tables.removeAll { $0.id == table.id }
            if self.selectedTableID == table.id {
                self.selectedTableID = self.tables.first?.id
            }
            self.saveSession()
        }
    }

    // MARK: - Получение примеров данных для AI

    /// Возвращает примеры строк из таблицы (первые N строк).
    func getSampleRows(tableName: String, limit: Int = 3) async -> [[String?]] {
        await withCheckedContinuation { continuation in
            let sql = "SELECT * FROM \(SQLEngine.quotedIdentifier(tableName)) LIMIT \(limit)"
            engine.run(sql: sql) { result in
                switch result {
                case .success(let outcome):
                    if case .table(let queryResult) = outcome {
                        continuation.resume(returning: queryResult.rows)
                    } else {
                        continuation.resume(returning: [])
                    }
                case .failure:
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Собирает информацию о таблицах с примерами данных для AI.
    @MainActor
    func getTablesWithSamples() async -> [TableWithSamples] {
        // Копируем таблицы чтобы избежать проблем с concurrency
        let currentTables = self.tables
        var result: [TableWithSamples] = []
        for table in currentTables {
            let sampleRows = await getSampleRows(tableName: table.name, limit: 3)
            result.append(TableWithSamples(table: table, sampleRows: sampleRows))
        }
        return result
    }

    // MARK: - Вспомогательное

    func insertSnippet(_ text: String) {
        query = text
    }

    func defaultQuery(for table: LoadedTable) -> String {
        "SELECT *\nFROM \(SQLEngine.quotedIdentifier(table.name))\nLIMIT 100;"
    }

    private func uniqueTableName(for url: URL) -> String {
        let base = sanitizeIdentifier(url.deletingPathExtension().lastPathComponent)
        let existing = Set(tables.map { $0.name })
        if !existing.contains(base) { return base }
        var index = 2
        while existing.contains("\(base)_\(index)") { index += 1 }
        return "\(base)_\(index)"
    }

    /// Заменяет типографские (умные) кавычки на обычные ASCII, чтобы SQL,
    /// набранный или вставленный с ‘ ’ “ ”, корректно понимался DuckDB.
    static func normalizeQuotes(_ input: String) -> String {
        var result = input
        for smart in ["\u{2018}", "\u{2019}", "\u{201A}", "\u{201B}", "\u{2032}"] {
            result = result.replacingOccurrences(of: smart, with: "'")
        }
        for smart in ["\u{201C}", "\u{201D}", "\u{201E}", "\u{201F}", "\u{2033}"] {
            result = result.replacingOccurrences(of: smart, with: "\"")
        }
        return result
    }

    private func sanitizeIdentifier(_ raw: String) -> String {
        var cleaned = raw.lowercased().map { char -> Character in
            if char.isLetter || char.isNumber || char == "_" { return char }
            return "_"
        }
        while let first = cleaned.first, first.isNumber {
            cleaned.insert("t", at: cleaned.startIndex)
            break
        }
        let string = String(cleaned)
        return string.isEmpty ? "table" : string
    }
}
