import Foundation
import DuckDB

func printResult(_ rs: ResultSet, title: String) {
    print("=== \(title) ===")
    var cols: [Column<String>] = []
    var names: [String] = []
    var c: DBInt = 0
    while c < rs.columnCount {
        names.append(rs.columnName(at: c))
        cols.append(rs.column(at: c).cast(to: String.self))
        c += 1
    }
    print(names.joined(separator: " | "))
    var r: DBInt = 0
    while r < rs.rowCount {
        var row: [String] = []
        for col in cols { row.append(col[r] ?? "NULL") }
        print(row.joined(separator: " | "))
        r += 1
    }
    print("rows=\(rs.rowCount)\n")
}

do {
    let db = try Database(store: .inMemory)
    let conn = try db.connect()

    let path = "examples/sales.csv"
    try conn.execute("""
    CREATE OR REPLACE TABLE sales AS
    SELECT * FROM read_csv_auto('\(path)', SAMPLE_SIZE=-1, header=true)
    """)

    printResult(try conn.query("SELECT name, type FROM pragma_table_info('sales')"),
                title: "pragma_table_info")

    printResult(try conn.query("SELECT count(*)::VARCHAR FROM sales"),
                title: "count")

    let q1 = """
    SELECT category, sum(quantity * price) AS revenue, count(*) AS orders
    FROM sales GROUP BY category ORDER BY revenue DESC
    """
    printResult(try conn.query("SELECT COLUMNS(*)::VARCHAR FROM (\n\(q1)\n) AS _q"),
                title: "wrapped group by")

    let q2 = """
    SELECT product, sum(quantity * price) AS revenue,
           rank() OVER (ORDER BY sum(quantity * price) DESC) AS rnk
    FROM sales GROUP BY product QUALIFY rnk <= 3
    """
    printResult(try conn.query("SELECT COLUMNS(*)::VARCHAR FROM (\n\(q2)\n) AS _q"),
                title: "wrapped window + qualify")

    print("SMOKE TEST OK")
} catch {
    print("SMOKE TEST FAILED: \(error)")
    exit(1)
}
