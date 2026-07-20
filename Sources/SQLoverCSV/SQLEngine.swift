import Foundation
import DuckDB

/// Ошибки движка с человекочитаемым описанием.
struct EngineError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Обёртка над DuckDB. Все обращения к базе идут через один последовательный
/// поток, поэтому соединение используется потокобезопасно. Результаты
/// возвращаются в completion-хендлерах на главном потоке.
final class SQLEngine {

    private let queue = DispatchQueue(label: "com.sqlovercsv.duckdb")
    private var database: Database?
    private var connection: Connection?

    /// Максимум строк, которые вытягиваем в UI (сам запрос не ограничивается).
    private let displayRowLimit: DBInt = 10_000

    // MARK: - Публичный API (async, completion на main)

    func loadCSV(url: URL, tableName: String,
                 completion: @escaping (Result<LoadedTable, Error>) -> Void) {
        queue.async {
            let result = Result { try self.loadCSVSync(url: url, tableName: tableName) }
                .mapError(self.engineError)
            DispatchQueue.main.async { completion(result) }
        }
    }

    func run(sql: String, completion: @escaping (Result<QueryOutcome, Error>) -> Void) {
        queue.async {
            let result = Result { try self.runSync(sql: sql) }
                .mapError(self.engineError)
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// Выгружает полный результат запроса в CSV-файл средствами DuckDB
    /// (`COPY ... TO`). Экспортируется весь результат, а не только строки,
    /// показанные в таблице.
    func exportCSV(sql: String, to url: URL,
                   completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            let result = Result {
                let conn = try self.ensureConnection()
                let normalizedSQL = sql.precomposedStringWithCanonicalMapping
                let trimmed = self.trimStatement(normalizedSQL)
                guard !trimmed.isEmpty else { throw EngineError(message: "Пустой запрос") }
                let escapedPath = Self.escapedString(url.path)
                try conn.execute("""
                COPY (
                \(trimmed)
                ) TO '\(escapedPath)' (FORMAT CSV, HEADER)
                """)
            }
            .mapError(self.engineError)
            DispatchQueue.main.async { completion(result) }
        }
    }

    func dropTable(name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            let result = Result {
                let conn = try self.ensureConnection()
                try conn.execute("DROP TABLE IF EXISTS \(Self.quotedIdentifier(name))")
            }
            .mapError(self.engineError)
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - Реализация (выполняется на serial queue)

    private func ensureConnection() throws -> Connection {
        if let connection { return connection }
        let db = try Database(store: .inMemory)
        let conn = try db.connect()
        database = db
        connection = conn
        return conn
    }

    private func loadCSVSync(url: URL, tableName: String) throws -> LoadedTable {
        let conn = try ensureConnection()
        let escapedPath = Self.escapedString(url.path)
        
        // Сначала загружаем во временную таблицу
        let tempTable = "_temp_\(tableName)"
        try conn.execute("""
        CREATE OR REPLACE TABLE \(Self.quotedIdentifier(tempTable)) AS
        SELECT * FROM read_csv_auto('\(escapedPath)', SAMPLE_SIZE=-1, header=true)
        """)
        
        // Получаем оригинальные названия колонок
        let originalColumns = try tableColumns(name: tempTable, conn: conn)
        
        // Создаём маппинг: оригинальное имя -> очищенное имя
        var renames: [(original: String, clean: String)] = []
        var seenNames = Set<String>()
        
        for col in originalColumns {
            var cleanName = Self.sanitizeColumnName(col.name)
            // Убедимся, что имя уникально
            var uniqueName = cleanName
            var counter = 2
            while seenNames.contains(uniqueName) {
                uniqueName = "\(cleanName)_\(counter)"
                counter += 1
            }
            seenNames.insert(uniqueName)
            renames.append((original: col.name, clean: uniqueName))
        }
        
        // Создаём финальную таблицу с очищенными именами
        let selectCols = renames.map { rename in
            "\(Self.quotedIdentifier(rename.original)) AS \(Self.quotedIdentifier(rename.clean))"
        }.joined(separator: ", ")
        
        try conn.execute("""
        CREATE OR REPLACE TABLE \(Self.quotedIdentifier(tableName)) AS
        SELECT \(selectCols) FROM \(Self.quotedIdentifier(tempTable))
        """)
        
        // Удаляем временную таблицу
        try conn.execute("DROP TABLE \(Self.quotedIdentifier(tempTable))")

        let rowCount = try scalarInt("SELECT count(*) FROM \(Self.quotedIdentifier(tableName))", conn: conn)
        let columns = try tableColumns(name: tableName, conn: conn)

        return LoadedTable(
            name: tableName,
            displayName: url.lastPathComponent,
            path: url.path,
            rowCount: rowCount,
            columns: columns
        )
    }
    
    /// Очищает название колонки от невидимых символов и мусора.
    static func sanitizeColumnName(_ name: String) -> String {
        var result = name
        
        // Убираем невидимые символы (кроме обычного пробела)
        let invisibleChars = CharacterSet.controlCharacters
            .union(CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}\u{00A0}\u{2060}"))
        result = result.unicodeScalars.filter { !invisibleChars.contains($0) }.map { String($0) }.joined()
        
        // Нормализуем Unicode (NFC)
        result = result.precomposedStringWithCanonicalMapping
        
        // Убираем ведущие/замыкающие пробелы
        result = result.trimmingCharacters(in: .whitespaces)
        
        // Заменяем множественные пробелы на один
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Если имя пустое, даём дефолтное
        if result.isEmpty {
            result = "column"
        }
        
        return result
    }

    private func tableColumns(name: String, conn: Connection) throws -> [ColumnInfo] {
        let sql = "SELECT name, type FROM pragma_table_info('\(Self.escapedString(name))')"
        let rs = try conn.query(sql)
        let names = rs.column(at: 0).cast(to: String.self)
        let types = rs.column(at: 1).cast(to: String.self)
        var result: [ColumnInfo] = []
        var i: DBInt = 0
        while i < rs.rowCount {
            result.append(ColumnInfo(name: names[i] ?? "?", type: types[i] ?? "?"))
            i += 1
        }
        return result
    }

    private func scalarInt(_ sql: String, conn: Connection) throws -> Int {
        let rs = try conn.query(sql)
        guard rs.rowCount > 0 else { return 0 }
        let col = rs.column(at: 0).cast(to: String.self)
        return Int(col[0] ?? "0") ?? 0
    }

    private func runSync(sql: String) throws -> QueryOutcome {
        let conn = try ensureConnection()
        // Нормализуем SQL (NFC) — решает проблему с кириллицей, которую AI
        // может выдавать в другой Unicode-форме
        let normalizedSQL = sql.precomposedStringWithCanonicalMapping
        let trimmed = trimStatement(normalizedSQL)
        guard !trimmed.isEmpty else {
            throw EngineError(message: "Пустой запрос")
        }

        let start = Date()

        if isStatementReturningRows(trimmed) {
            let resultSet = try queryReturningRows(trimmed, conn: conn)
            let result = try buildResult(from: resultSet, elapsed: Date().timeIntervalSince(start))
            return .table(result)
        } else {
            try conn.execute(trimmed)
            return .message("Запрос выполнен успешно")
        }
    }

    /// Для запросов, возвращающих строки, оборачиваем запрос так, чтобы все
    /// колонки пришли как VARCHAR — это позволяет единообразно показывать
    /// значения любого типа (числа, даты, списки, структуры).
    private func queryReturningRows(_ sql: String, conn: Connection) throws -> ResultSet {
        let wrapped = "SELECT COLUMNS(*)::VARCHAR FROM (\n\(sql)\n) AS _sqlovercsv_q"
        do {
            return try conn.query(wrapped)
        } catch {
            // DESCRIBE / SHOW / PRAGMA нельзя обернуть в подзапрос — пробуем как есть.
            return try conn.query(sql)
        }
    }

    private func buildResult(from rs: ResultSet, elapsed: TimeInterval) throws -> QueryResult {
        let columnCount = rs.columnCount
        var columnNames: [String] = []
        var stringColumns: [Column<String>] = []
        var c: DBInt = 0
        while c < columnCount {
            columnNames.append(rs.columnName(at: c))
            stringColumns.append(rs.column(at: c).cast(to: String.self))
            c += 1
        }

        let totalRows = rs.rowCount
        let displayCount = min(totalRows, displayRowLimit)

        var rows: [[String?]] = []
        rows.reserveCapacity(Int(displayCount))
        var r: DBInt = 0
        while r < displayCount {
            var row: [String?] = []
            row.reserveCapacity(stringColumns.count)
            for column in stringColumns {
                row.append(column[r])
            }
            rows.append(row)
            r += 1
        }

        return QueryResult(
            columns: columnNames,
            rows: rows,
            totalRows: Int(totalRows),
            displayedRows: Int(displayCount),
            elapsed: elapsed,
            truncated: totalRows > displayRowLimit
        )
    }

    // MARK: - Разбор запроса

    private func trimStatement(_ sql: String) -> String {
        var s = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix(";") {
            s.removeLast()
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }

    private func isStatementReturningRows(_ sql: String) -> Bool {
        guard let first = firstKeyword(sql) else { return false }
        let modifying: Set<String> = [
            "CREATE", "INSERT", "UPDATE", "DELETE", "DROP", "ALTER",
            "ATTACH", "DETACH", "COPY", "SET", "RESET", "BEGIN", "START",
            "COMMIT", "ROLLBACK", "INSTALL", "LOAD", "CHECKPOINT",
            "VACUUM", "ANALYZE", "USE", "TRUNCATE", "COMMENT"
        ]
        return !modifying.contains(first)
    }

    private func firstKeyword(_ sql: String) -> String? {
        // Пропускаем ведущие построчные комментарии "-- ...".
        var meaningful = ""
        for line in sql.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("--") { continue }
            meaningful = trimmed
            break
        }
        let token = meaningful.split(whereSeparator: { $0 == " " || $0 == "(" || $0 == "\t" }).first
        return token.map { $0.uppercased() }
    }

    // MARK: - Человекочитаемые ошибки

    private func engineError(_ error: Error) -> Error {
        if error is EngineError { return error }
        return EngineError(message: Self.readableMessage(error))
    }

    /// Достаёт реальный текст ошибки DuckDB (он лежит в associated value),
    /// вместо бесполезного «DuckDB.DatabaseError error 4».
    static func readableMessage(_ error: Error) -> String {
        if let dbError = error as? DatabaseError {
            switch dbError {
            case .connectionQueryError(let reason),
                 .preparedStatementQueryError(let reason),
                 .databaseFailedToInitialize(let reason),
                 .preparedStatementFailedToInitialize(let reason),
                 .preparedStatementFailedToBindParameter(let reason),
                 .appenderFailedToAppendItem(let reason),
                 .appenderFailedToEndRow(let reason),
                 .appenderFailedToFlush(let reason),
                 .appenderFailedToInitialize(let reason):
                return reason ?? "DuckDB не смог выполнить операцию."
            case .connectionFailedToInitialize:
                return "Не удалось подключиться к базе данных."
            case .configurationFailedToSetFlag:
                return "Не удалось применить настройку базы данных."
            case .decimalUnrepresentable:
                return "Число не помещается во внутреннее представление decimal."
            case .valueNotFound(let type):
                return "Значение типа \(type) не найдено."
            case .typeMismatch(let type):
                return "Несоответствие типа: \(type)."
            }
        }
        if let engine = error as? EngineError { return engine.message }
        return error.localizedDescription
    }

    // MARK: - Экранирование

    static func quotedIdentifier(_ name: String) -> String {
        "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func escapedString(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
