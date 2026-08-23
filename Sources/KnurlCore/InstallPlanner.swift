// InstallPlanner.swift — Decides the installation strategy for a missing package based on the available TeX tools.

import Foundation

/// The chosen installation strategy for a missing package.
public enum InstallStrategy: Equatable, Sendable {
    /// Install via `tlmgr install` (TeX Live).
    case tlmgr(package: String)
    /// Tectonic handles this package automatically on first compile.
    case tectonicHandled(package: String)
    /// Download from CTAN and place in the user's TEXMF tree.
    case ctanToUserTree(package: String, kind: TeXElementKind)
    /// No TeX toolchain found to perform the install.
    case unavailable
}

/// Selects the best available installation strategy for a given package.
public enum InstallPlanner {
    /// Picks a strategy based on which TeX tools are present on the system.
    public static func plan(for package: String, kind: TeXElementKind, environment: EnvironmentInfo) -> InstallStrategy {
        if kind == .engine {
            return environment.tlmgr ? .tlmgr(package: package) : .unavailable
        }
        let hasAnyTeX = environment.kpsewhich || environment.tlmgr || environment.tectonic
        guard hasAnyTeX else { return .unavailable }
        if environment.tlmgr { return .tlmgr(package: package) }
        if environment.tectonic { return .tectonicHandled(package: package) }
        return .ctanToUserTree(package: package, kind: kind)
    }
}

/// Checks whether a package installation was successful by probing kpsewhich and the filesystem.
public enum InstallVerification {
    /// Returns true if the package was found by either kpsewhich or direct file lookup.
    public static func isVerified(kpsewhichFound: Bool, artifactFound: Bool) -> Bool {
        kpsewhichFound || artifactFound
    }
}
