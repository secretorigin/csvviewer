import Foundation

/// Описание одной колонки загруженной таблицы (имя + SQL-тип).
struct ColumnInfo: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var type: String
}

/// CSV-файл, загруженный в базу как таблица DuckDB.
struct LoadedTable: Identifiable, Hashable {
    let id = UUID()
    /// Валидный SQL-идентификатор таблицы внутри базы.
    var name: String
    /// Человекочитаемое имя (имя файла).
    var displayName: String
    var path: String
    var rowCount: Int
    var columns: [ColumnInfo]
}

/// Результат запроса, приведённый к строкам для отображения.
struct QueryResult {
    var columns: [String]
    var rows: [[String?]]
    var totalRows: Int
    var displayedRows: Int
    var elapsed: TimeInterval
    var truncated: Bool
}

/// Что вернул запрос: таблицу с данными или просто сообщение (для DDL/DML).
enum QueryOutcome {
    case table(QueryResult)
    case message(String)
}

/// Таблица вместе с примерами данных для отправки в AI.
struct TableWithSamples {
    var table: LoadedTable
    var sampleRows: [[String?]]
}
