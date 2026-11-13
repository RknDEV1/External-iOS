import Foundation

enum ExploitSupportPolicy {
    static let verifiedIOS17Range = "17.0–17.7.x"
    static let verifiedIOS18Range = "18.0–18.7.1"
    static let verifiedIOS26Range = "26.0.x"

    static func supportReason(major: Int, minor: Int, patch: Int, build: String) -> String {
        if major == 27 {
            return "iOS 27 beta (\(build)) detectado: offsets nativos ainda não foram validados para este build"
        }
        if major > 27 {
            return "iOS \(major).\(minor).\(patch) não possui offsets nativos validados"
        }
        if major == 26 && minor > 0 {
            return "iOS 26.\(minor) não possui offsets nativos validados; somente iOS 26.0.x"
        }
        return "iOS \(major).\(minor).\(patch) (\(build)) não está na faixa validada"
    }

    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 17 {
            return minor <= 7
        }

        if major == 18 {
            return minor < 7 || (minor == 7 && patch <= 1)
        }

        return false
    }

    static func isRecognizedSystemFamily(major: Int) -> Bool {
        [17, 18, 26, 27].contains(major)
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return true
        }

        // offsets.m aborts above iOS 26.0.x; do not advertise later builds.
        if major == 26 {
            return minor == 0 && patch >= 0
        }

        // No native offsets for iOS 27 are bundled in this target.
        return false
    }
}
