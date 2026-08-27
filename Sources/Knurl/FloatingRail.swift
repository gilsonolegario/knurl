// FloatingRail.swift — Legacy stub: NavigationSplitView replaces the floating rail (Davit-style shell).

import SwiftUI

// MARK: - Deprecated compatibility

/// Former navigation item — now an alias for `SidebarSection` to keep old call sites compiling.
@available(*, deprecated, message: "Use SidebarSection instead. FloatingRail was replaced by NavigationSplitView.")
typealias RailItem = SidebarSection

/// Former floating rail — replaced by the native `NavigationSplitView` sidebar.
/// Kept as an `EmptyView` stub so references in old branches or previews do not break.
struct FloatingRail: View {
    var body: some View {
        EmptyView()
    }
}
