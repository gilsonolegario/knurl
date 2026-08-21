import Foundation

public enum AnalysisPhase {
    case idle, loading, error, hasLog, hasReport
}

public struct LayoutMetrics {
    public static let windowHeight: CGFloat = 440
    public static let compactWindowHeight: CGFloat = 226
    public static let headerHeight: CGFloat = 56
    public static let statusBarHeight: CGFloat = 40
    public static let titleBarHeight: CGFloat = 28
    public static let outerPadding: CGFloat = 48
    public static let dropZoneHeightLoading: CGFloat = 64
    public static let slimDropZoneHeight: CGFloat = 52
    public static let bannerHeight: CGFloat = 44
    public static let segmentedRowHeight: CGFloat = 28
    public static let statusLineHeight: CGFloat = 20
    public static let actionRowHeight: CGFloat = 32
    public static let tableMinHeight: CGFloat = 160
    public static let tableMaxHeight: CGFloat = 320
    public static let bottomInset: CGFloat = 14
    public static let heightSlack: CGFloat = 40
    public static let vStackSpacingPrimary: CGFloat = 12
    public static let progressHeight: CGFloat = 16
    public static let vStackSpacingSecondary: CGFloat = 8
    public static let rollingLogMaxHeight: CGFloat = 200
    public static let rollingLogCollapsedHeight: CGFloat = 28
    public static let logLineHeight: CGFloat = 16
    public static let logPadding: CGFloat = 16
    public static let logBufferLimit: Int = 200

    // Sidebar layout
    public static let sidebarWidth: CGFloat = 60
    public static let railButtonSize: CGFloat = 44
    public static let railSpacing: CGFloat = 8
    public static let contentPaddingLeading: CGFloat = 88
    public static let contentPaddingTop: CGFloat = 12
    public static let contentPaddingTrailing: CGFloat = 24
    public static let contentPaddingBottom: CGFloat = 28

    public static func availableLogHeight(phase: AnalysisPhase) -> CGFloat {
        switch phase {
        case .loading:
            let used = headerHeight + outerPadding + dropZoneHeightLoading
                + vStackSpacingPrimary + progressHeight + vStackSpacingSecondary
            let available = windowHeight - used
            return max(0, min(available, rollingLogMaxHeight))
        case .idle:
            return 0
        case .error, .hasLog, .hasReport:
            return rollingLogCollapsedHeight
        }
    }
}