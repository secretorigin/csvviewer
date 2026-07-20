import SwiftUI
import AppKit

struct ResultTableView: View {
    let result: QueryResult

    private let rowHeight: CGFloat = 26
    private let gutterWidth: CGFloat = 54
    @State private var hoveredColumn: Int?

    private var columnWidths: [CGFloat] {
        let sample = result.rows.prefix(250)
        return result.columns.enumerated().map { index, name in
            var maxChars = name.count
            for row in sample {
                if index < row.count, let value = row[index] {
                    maxChars = max(maxChars, value.count)
                }
            }
            let width = CGFloat(maxChars) * 7.7 + 26
            return min(max(width, 88), 380)
        }
    }

    private var totalWidth: CGFloat {
        gutterWidth + columnWidths.reduce(0, +)
    }

    var body: some View {
        let widths = columnWidths
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow(widths: widths)
                Divider()
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(result.rows.enumerated()), id: \.offset) { rowIndex, row in
                            dataRow(row, index: rowIndex, widths: widths)
                            Divider().opacity(0.12)
                        }
                    }
                }
            }
            .frame(width: max(totalWidth, 0), alignment: .leading)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(16)
    }

    private func headerRow(widths: [CGFloat]) -> some View {
        HStack(spacing: 0) {
            Text("#")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: gutterWidth, height: rowHeight, alignment: .center)

            ForEach(Array(result.columns.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer(minLength: 2)
                    
                    if hoveredColumn == index {
                        Button {
                            copyToClipboard(name)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Скопировать имя колонки")
                    }
                }
                .padding(.horizontal, 8)
                .frame(width: widths[index], height: rowHeight, alignment: .leading)
                .contentShape(Rectangle())
                .onHover { hovering in
                    hoveredColumn = hovering ? index : nil
                }
                Divider().opacity(0.15)
            }
        }
        .frame(height: rowHeight)
        .background(.ultraThinMaterial)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func dataRow(_ row: [String?], index: Int, widths: [CGFloat]) -> some View {
        HStack(spacing: 0) {
            Text("\(index + 1)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: gutterWidth, height: rowHeight, alignment: .center)

            ForEach(Array(result.columns.enumerated()), id: \.offset) { columnIndex, _ in
                cell(value: columnIndex < row.count ? row[columnIndex] : nil)
                    .frame(width: widths[columnIndex], height: rowHeight, alignment: .leading)
                Divider().opacity(0.08)
            }
        }
        .frame(height: rowHeight)
        .background(index.isMultiple(of: 2) ? Color.primary.opacity(0.03) : Color.clear)
    }

    @ViewBuilder
    private func cell(value: String?) -> some View {
        if let value {
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .padding(.horizontal, 8)
        } else {
            Text("NULL")
                .font(.system(size: 11, design: .monospaced))
                .italic()
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
        }
    }
}
