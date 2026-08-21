import Foundation

public enum InstallStrategy: Equatable, Sendable {
    case tlmgr(package: String)
    case tectonicHandled(package: String)
    case ctanToUserTree(package: String, kind: TeXElementKind)
    case unavailable
}

public enum InstallPlanner {
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

public enum InstallVerification {
    public static func isVerified(kpsewhichFound: Bool, artifactFound: Bool) -> Bool {
        kpsewhichFound || artifactFound
    }
}