// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SQLoverCSV",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(
            url: "https://github.com/duckdb/duckdb-swift",
            .upToNextMajor(from: .init(1, 0, 0))
        )
    ],
    targets: [
        .executableTarget(
            name: "SQLoverCSV",
            dependencies: [
                .product(name: "DuckDB", package: "duckdb-swift")
            ],
            path: "Sources/SQLoverCSV"
        )
    ]
)
