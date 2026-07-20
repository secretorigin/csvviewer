# SQL over CSV

Минималистичное macOS-приложение (SwiftUI) для открытия CSV-файлов и выполнения
по ним SQL-запросов в диалекте PostgreSQL. Под капотом — движок
[DuckDB](https://duckdb.org), чей SQL максимально близок к PostgreSQL и умеет
читать CSV напрямую.

Интерфейс в стиле macOS: блюр-фон как у Finder, боковая панель со списком
загруженных таблиц и их схемой, редактор запроса и таблица результатов.

## Быстрый старт

Собрать приложение, установить его в `/Applications` и сразу открыть:

```bash
make install
```

## Возможности

- Открытие CSV/TSV кнопкой (⌘O) или перетаскиванием файла в окно.
- Автоопределение типов колонок и заголовков.
- SQL-запросы в стиле PostgreSQL: `JOIN`, оконные функции, CTE (`WITH`),
  агрегации, `GROUP BY`, приведение типов `::`, и т.д.
- Несколько файлов одновременно — можно джойнить таблицы между собой.
- Боковая панель со схемой каждой таблицы.
- Значения `NULL` отображаются отдельно, результат приводится к строкам
  универсально (числа, даты, списки, структуры).

## Требования

- macOS 13+
- Swift 6 / Swift toolchain (входит в Command Line Tools или Xcode)

## Запуск в режиме разработки

```bash
swift run
```

Первая сборка компилирует DuckDB и занимает пару минут; последующие — быстрые.

## Сборка приложения (.app)

```bash
./build_app.sh
```

Скрипт соберёт релиз и упакует `SQL over CSV.app`. Путь к бандлу выводится
в конце. Открыть:

```bash
open "$(swift build -c release --show-bin-path)/SQL over CSV.app"
```

При желании перетащи получившийся `.app` в `/Applications`.

## Пример

В папке `examples/` лежит `sales.csv`. Открой его в приложении и попробуй:

```sql
-- Выручка по категориям
SELECT category,
       sum(quantity * price) AS revenue,
       count(*)              AS orders
FROM sales
GROUP BY category
ORDER BY revenue DESC;
```

```sql
-- Топ-3 товара по выручке с оконной функцией
SELECT product,
       sum(quantity * price) AS revenue,
       rank() OVER (ORDER BY sum(quantity * price) DESC) AS rnk
FROM sales
GROUP BY product
QUALIFY rnk <= 3;
```

## Как это устроено

- `Sources/SQLoverCSV/SQLEngine.swift` — обёртка над DuckDB: загрузка CSV
  (`read_csv_auto`), выполнение запросов на выделенном потоке, приведение
  результата к строкам через `COLUMNS(*)::VARCHAR`.
- `Sources/SQLoverCSV/AppState.swift` — состояние приложения (список таблиц,
  текст запроса, результат).
- `Sources/SQLoverCSV/*View.swift` — интерфейс SwiftUI: блюр-фон
  (`NSVisualEffectView`), сайдбар, редактор и таблица результатов.
