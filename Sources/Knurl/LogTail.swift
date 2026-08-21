import SwiftUI

struct LogTail: View {
    let lines: [String]
    let tailCount: Int
    let isLive: Bool

    var body: some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                header
                terminal
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Log")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Brand.textSecondary)

            Text("\(lines.count) lines")
                .font(.caption)
                .foregroundStyle(Brand.textSecondary)

            if isLive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Brand.accent)
                        .frame(width: 6, height: 6)
                    Text("live")
                        .font(.caption)
                        .foregroundStyle(Brand.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Brand.textSecondary)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 6)
    }

    private var terminal: some View {
        let tail = Array(lines.suffix(tailCount))
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(tail.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: Brand.rSmall, style: .continuous)
                .fill(Brand.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.rSmall, style: .continuous)
                        .strokeBorder(Brand.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 7, x: 0, y: 2)
        )
    }
}
