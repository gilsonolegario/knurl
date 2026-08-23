// FloatingRail.swift — Vertical sidebar with icon-only navigation buttons and hover tooltips.

import SwiftUI

/// Navigation tabs exposed by the floating sidebar rail.
enum RailItem: String, CaseIterable {
    case status
    case packages
    case log
    case updates

    var icon: String {
        switch self {
        case .status: return "heart.text.square"
        case .packages: return "shippingbox"
        case .log: return "doc.text"
        case .updates: return "arrow.triangle.2.circlepath"
        }
    }

    var label: String {
        switch self {
        case .status: return "Status"
        case .packages: return "Packages"
        case .log: return "Log"
        case .updates: return "Updates"
        }
    }

    @MainActor
    var color: Color {
        switch self {
        case .status: return Brand.green
        case .packages: return Brand.accent
        case .log: return Brand.orange
        case .updates: return Brand.blue
        }
    }
}

/// Floating vertical sidebar that renders `RailItem` buttons with a hover label.
struct FloatingRail: View {
    @Binding var selectedTab: RailItem

    var body: some View {
        VStack(spacing: 8) {
            // App icon
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)
                .padding(.top, 20)

            Divider()
                .background(Brand.hairline)
                .padding(.horizontal, 8)

            // Navigation items
            ForEach(RailItem.allCases, id: \.self) { item in
                RailButton(
                    item: item,
                    isSelected: selectedTab == item
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = item
                    }
                }
            }

            Spacer()
        }
        .frame(width: 60)
        .background(Brand.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: Brand.rLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.rLarge, style: .continuous)
                .stroke(Brand.hairline, lineWidth: 1)
        )
    }
}

// MARK: - RailButton

/// Single rail button with selected highlight and a trailing hover label.
struct RailButton: View {
    let item: RailItem
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? item.color : Color.clear)
                    .frame(width: 44, height: 44)

                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? Brand.onAccent : Brand.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .overlay(alignment: .trailing) {
            if isHovering && !isSelected {
                Text(item.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Brand.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Brand.cardFill)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Brand.hairline, lineWidth: 1))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .offset(x: 54)
                    .transition(.opacity)
            }
        }
    }
}
