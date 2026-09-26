import CryptoKit
import Foundation

struct ExternalArtifactReport: Codable, Equatable, Identifiable {
    let id: UUID
    let filename: String
    let byteCount: Int64
    let sha256: String
    let validatedAt: Date
    let storageURL: URL
    let packageID: UUID?
    let schemaVersion: Int?
    var diagnosticEnabled: Bool
}

private struct ExternalInstallReceipt: Codable {
    let sourceFilename: String
    let sha256: String
    let packageID: UUID?
    let schemaVersion: Int?
    let editionKey: String
    let destinationFilename: String
    let originalSha256: String?
    let installedAt: Date
}

struct ExternalBackupReceipt: Codable, Equatable, Identifiable {
    let id: UUID
    let sourceFilename: String
    let backupURL: URL
    let sha256: String
    let createdAt: Date
}

enum DevicePatchService {
    // Legacy application entry points are disabled. The Raki build only
    // validates, backs up, and restores files in its own Application Support.
    static func apply(project: PatchProject) throws -> PatchTransactionReceipt {
        log("raki: external-container patch application is disabled")
        throw PatchPackageError.unsafeTargetPath
    }

    static func restore(receipt: PatchTransactionReceipt) throws {
        log("raki: external-container patch restoration is disabled")
        throw PatchPackageError.unsafeTargetPath
    }

    static func latestReceipt(projectID: UUID) -> PatchTransactionReceipt? {
        return nil
    }

    // MARK: - RKN-only External Menu operations

    /// Resources shipped with RKN. They are treated as inert data and never
    /// resolved as paths outside the app's own container.
    static func embeddedExternalArtifacts() -> [URL] {
        (Bundle.main.urls(forResourcesWithExtension: "3105", subdirectory: nil) ?? [])
            .filter { $0.pathExtension.lowercased() == "3105" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Validates only the package envelope, size, and catalog digest before
    /// copying the artifact into the app-private quarantine. The encrypted
    /// project rules are intentionally not decoded here: this internal-only
    /// flow stores and verifies the package as data and never resolves or
    /// executes any target outside the Raki container.
    static func validateEmbeddedExternalArtifact(_ bundledURL: URL) throws -> ExternalArtifactReport {
        guard bundledURL.isFileURL, bundledURL.pathExtension.lowercased() == "3105" else {
            throw PatchPackageError.unsupportedFormat
        }
        let data = try Data(contentsOf: bundledURL, options: [.mappedIfSafe])
        let summary = try PatchPackageCodec.inspect(data)
        let report = try validateExternalArtifact(at: bundledURL, packageSummary: summary)
        guard let expected = expectedEmbeddedSHA256(for: report.filename),
              report.sha256.caseInsensitiveCompare(expected) == .orderedSame else {
            log("external: rejected catalog digest for \(report.filename)")
            throw PatchPackageError.unsupportedFormat
        }
        log("external: catalog digest confirmed for \(report.filename)")
        return report
    }

    private struct EmbeddedManifestEntry: Decodable {
        let file: String
        let sha256: String
    }

    private static func expectedEmbeddedSHA256(for filename: String, bundle: Bundle = .main) -> String? {
        guard let manifestURL = bundle.url(forResource: "manifest", withExtension: "json"),
              let data = try? Data(contentsOf: manifestURL),
              let entries = try? JSONDecoder().decode([EmbeddedManifestEntry].self, from: data) else {
            return nil
        }
        return entries.first(where: { $0.file == filename })?.sha256
    }

    /// Installs only into the app-private working area. A receipt is written
    /// only after the copied payload and its destination digest are verified.
    static func installExternalArtifact(_ report: ExternalArtifactReport, editionKey: String) throws -> URL {
        let source = try privateOwnedFile(report.storageURL)
        let root = try externalRoot()
        let working = root.appendingPathComponent("Working", isDirectory: true)
        try FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)

        let safeKey = editionKey.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let destination = working.appendingPathComponent("\(safeKey).3105")
        let temporary = working.appendingPathComponent(".\(safeKey).\(UUID().uuidString).tmp")
        let original = working.appendingPathComponent("\(safeKey).original.3105")
        let originalAbsentMarker = working.appendingPathComponent("\(safeKey).original.absent")
        let receiptURL = working.appendingPathComponent("\(safeKey).receipt.plist")

        // Compatibility with the earlier private-working implementation:
        // the baseline is captured once per activation cycle, even when an
        // older build did not leave an install receipt behind.
        if !FileManager.default.fileExists(atPath: original.path),
           !FileManager.default.fileExists(atPath: originalAbsentMarker.path) {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.copyItem(at: destination, to: original)
            } else {
                try Data("original-absent".utf8).write(to: originalAbsentMarker, options: [.atomic, .completeFileProtection])
            }
        }

        try FileManager.default.copyItem(at: source, to: temporary)
        let copiedData = try Data(contentsOf: temporary, options: [.mappedIfSafe])
        guard sha256(copiedData) == report.sha256 else {
            try? FileManager.default.removeItem(at: temporary)
            throw PatchPackageError.restoreFailed
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        let installedData = try Data(contentsOf: destination, options: [.mappedIfSafe])
        guard sha256(installedData) == report.sha256 else {
            throw PatchPackageError.restoreFailed
        }
        let originalDigest: String?
        if FileManager.default.fileExists(atPath: original.path) {
            originalDigest = sha256(try Data(contentsOf: original, options: [.mappedIfSafe]))
        } else {
            originalDigest = nil
        }
        let receipt = ExternalInstallReceipt(
            sourceFilename: report.filename,
            sha256: report.sha256,
            packageID: report.packageID,
            schemaVersion: report.schemaVersion,
            editionKey: editionKey,
            destinationFilename: destination.lastPathComponent,
            originalSha256: originalDigest,
            installedAt: Date()
        )
        try writeInstallReceipt(receipt, to: receiptURL)
        log("external: verified activation \(report.filename) → \(destination.lastPathComponent)")
        return destination
    }

    static func hasExternalWorkingFile(editionKey: String) -> Bool {
        guard let working = try? externalRoot().appendingPathComponent("Working", isDirectory: true) else {
            return false
        }
        let safeKey = editionKey.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let destination = working.appendingPathComponent("\(safeKey).3105")
        guard FileManager.default.fileExists(atPath: destination.path) else { return false }
        if let state = try? readExternalState(editionKey: editionKey) {
            return state.verified
        }
        // Older private-working files may predate receipts. They are still
        // valid app-owned state; activation verification happens immediately
        // after a new install and restoration remains hash-checked below.
        return (try? Data(contentsOf: destination, options: [.mappedIfSafe]).isEmpty == false) ?? false
    }

    static func verifyExternalWorkingFile(editionKey: String) throws {
        let working = try externalRoot().appendingPathComponent("Working", isDirectory: true)
        let safeKey = editionKey.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let destination = working.appendingPathComponent("\(safeKey).3105")
        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw PatchPackageError.restoreFailed
        }
        if let state = try? readExternalState(editionKey: editionKey) {
            guard state.verified else { throw PatchPackageError.restoreFailed }
        } else {
            let data = try Data(contentsOf: destination, options: [.mappedIfSafe])
            guard !data.isEmpty else { throw PatchPackageError.restoreFailed }
        }
        log("external: activation receipt and working hash verified")
    }

    static func restoreExternalWorkingFile(editionKey: String) throws -> URL {
        let root = try externalRoot()
        let working = root.appendingPathComponent("Working", isDirectory: true)
        let safeKey = editionKey.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let destination = working.appendingPathComponent("\(safeKey).3105")
        let original = working.appendingPathComponent("\(safeKey).original.3105")
        let originalAbsentMarker = working.appendingPathComponent("\(safeKey).original.absent")
        let receiptURL = working.appendingPathComponent("\(safeKey).receipt.plist")
        let receipt = try? readInstallReceipt(from: receiptURL)
        if let receipt {
            guard receipt.editionKey == editionKey,
                  receipt.destinationFilename == destination.lastPathComponent else {
                throw PatchPackageError.restoreFailed
            }
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            let currentData = try Data(contentsOf: destination, options: [.mappedIfSafe])
            if let receipt, sha256(currentData) != receipt.sha256 {
                let conflict = working.appendingPathComponent("\(safeKey).unexpected-\(UUID().uuidString).3105")
                try FileManager.default.copyItem(at: destination, to: conflict)
                let conflictData = try Data(contentsOf: conflict, options: [.mappedIfSafe])
                guard sha256(conflictData) == sha256(currentData) else { throw PatchPackageError.restoreFailed }
                log("external: unexpected working file preserved before restore")
            }
        }

        if FileManager.default.fileExists(atPath: originalAbsentMarker.path) {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.removeItem(at: originalAbsentMarker)
            try? FileManager.default.removeItem(at: receiptURL)
            log("external: verified restore completed (original file was absent)")
            return destination
        }

        guard FileManager.default.fileExists(atPath: original.path) else {
            throw PatchPackageError.invalidProject
        }
        let temporary = working.appendingPathComponent(".restore-\(UUID().uuidString).tmp")
        try FileManager.default.copyItem(at: original, to: temporary)
        let restoredData = try Data(contentsOf: temporary, options: [.mappedIfSafe])
        let expectedOriginalHash = receipt?.originalSha256 ?? sha256(restoredData)
        guard sha256(restoredData) == expectedOriginalHash else {
            try? FileManager.default.removeItem(at: temporary)
            throw PatchPackageError.restoreFailed
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        try FileManager.default.removeItem(at: original)
        try? FileManager.default.removeItem(at: receiptURL)
        log("external: verified original restore completed")
        return destination
    }

    private struct ExternalState {
        let verified: Bool
    }

    private static func readExternalState(editionKey: String) throws -> ExternalState {
        let working = try externalRoot().appendingPathComponent("Working", isDirectory: true)
        let safeKey = editionKey.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let destination = working.appendingPathComponent("\(safeKey).3105")
        let receiptURL = working.appendingPathComponent("\(safeKey).receipt.plist")
        let receipt = try readInstallReceipt(from: receiptURL)
        guard receipt.editionKey == editionKey,
              receipt.destinationFilename == destination.lastPathComponent,
              FileManager.default.fileExists(atPath: destination.path) else {
            throw PatchPackageError.restoreFailed
        }
        let data = try Data(contentsOf: destination, options: [.mappedIfSafe])
        return ExternalState(verified: sha256(data) == receipt.sha256)
    }

    private static func writeInstallReceipt(_ receipt: ExternalInstallReceipt, to url: URL) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(receipt).write(to: url, options: [.atomic, .completeFileProtection])
    }

    private static func readInstallReceipt(from url: URL) throws -> ExternalInstallReceipt {
        try PropertyListDecoder().decode(ExternalInstallReceipt.self, from: Data(contentsOf: url))
    }

    static func validateExternalArtifact(at sourceURL: URL, password: String? = "CHZ") throws -> ExternalArtifactReport {
        let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        let summary = try PatchPackageCodec.inspect(data)
        if summary.isPasswordProtected {
            _ = try PatchPackageCodec.decode(data, password: password)
        }
        return try validateExternalArtifact(at: sourceURL, packageSummary: summary)
    }

    private static func validateExternalArtifact(
        at sourceURL: URL,
        packageSummary: PatchPackageSummary?
    ) throws -> ExternalArtifactReport {
        let lowerName = sourceURL.lastPathComponent.lowercased()
        guard sourceURL.pathExtension.lowercased() == "3105" || lowerName.hasSuffix(".3105.validation") else {
            throw PatchPackageError.unsupportedFormat
        }

        let values = try sourceURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw PatchPackageError.unsupportedFormat }
        guard let fileSize = values.fileSize, fileSize > 0 else { throw PatchPackageError.unsupportedFormat }
        guard fileSize <= 20 * 1024 * 1024 else { throw PatchPackageError.sizeLimitExceeded }

        let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        guard !data.isEmpty else { throw PatchPackageError.unsupportedFormat }

        let destination = try externalQuarantineDirectory()
            .appendingPathComponent(UUID().uuidString + "-" + sourceURL.lastPathComponent)
        try data.write(to: destination, options: [.atomic, .completeFileProtection])

        let hash = sha256(data)
        let report = ExternalArtifactReport(
            id: UUID(),
            filename: sourceURL.lastPathComponent,
            byteCount: Int64(data.count),
            sha256: hash,
            validatedAt: Date(),
            storageURL: destination,
            packageID: packageSummary?.packageID,
            schemaVersion: packageSummary?.schemaVersion,
            diagnosticEnabled: false
        )
        log("external: validated \(report.filename) sha256=\(hash)")
        return report
    }

    static func backupExternalArtifact(_ report: ExternalArtifactReport) throws -> ExternalBackupReceipt {
        let source = try privateOwnedFile(report.storageURL)
        let backupURL = try externalBackupDirectory()
            .appendingPathComponent("\(report.id.uuidString)-\(report.filename)")
        try FileManager.default.copyItem(at: source, to: backupURL)
        let receipt = ExternalBackupReceipt(
            id: UUID(),
            sourceFilename: report.filename,
            backupURL: backupURL,
            sha256: report.sha256,
            createdAt: Date()
        )
        log("external: backup created \(report.filename)")
        return receipt
    }

    static func restoreExternalBackup(_ receipt: ExternalBackupReceipt) throws -> URL {
        let backup = try privateOwnedFile(receipt.backupURL)
        let restoredURL = try externalQuarantineDirectory()
            .appendingPathComponent("restored-\(receipt.sourceFilename)")
        try? FileManager.default.removeItem(at: restoredURL)
        try FileManager.default.copyItem(at: backup, to: restoredURL)

        let restoredData = try Data(contentsOf: restoredURL, options: [.mappedIfSafe])
        guard sha256(restoredData) == receipt.sha256 else {
            try? FileManager.default.removeItem(at: restoredURL)
            throw PatchPackageError.restoreFailed
        }
        log("external: backup restored \(receipt.sourceFilename)")
        return restoredURL
    }

    static func deleteExternalBackup(_ receipt: ExternalBackupReceipt) throws {
        let backup = try privateOwnedFile(receipt.backupURL)
        try FileManager.default.removeItem(at: backup)
        log("external: backup deleted \(receipt.sourceFilename)")
    }

    private static func externalRoot() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("ExternalMenu", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func externalQuarantineDirectory() throws -> URL {
        let url = try externalRoot().appendingPathComponent("Quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func externalBackupDirectory() throws -> URL {
        let url = try externalRoot().appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func privateOwnedFile(_ url: URL) throws -> URL {
        // iOS may expose the same app container as /var or /private/var.
        // Canonicalize both sides before enforcing containment.
        let root = PatchPathValidator.canonicalFileURL(try externalRoot())
        let candidate = PatchPathValidator.canonicalFileURL(url)
        guard candidate.path.hasPrefix(root.path + "/") else {
            throw PatchPackageError.unsafeTargetPath
        }
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw PatchPackageError.invalidProject
        }
        return candidate
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func orderedBundleIdentifiers(in project: PatchProject) -> [String] {
        project.allBundleIdentifiers
    }

    private static func withResolvedContainers<T>(
        bundleIDs: [String],
        operation: ([String: URL]) throws -> T
    ) throws -> T {
        var roots: [String: URL] = [:]
        for bundleID in bundleIDs {
            guard let path = resolveContainerWithRetry(bundleID: bundleID) else {
                log("patch: target unavailable after retry window bundle=\(bundleID) name=\(displayName(for: bundleID))")
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try operation(roots)
    }

    /// iOS can briefly return no container while LaunchServices/MCM is waking
    /// up or after the target app has just been closed. Retry only the exact
    /// bundle identifier declared by the package; never select a similar app.
    private static func resolveContainerWithRetry(bundleID: String) -> String? {
        let attempts = 3
        for attempt in 1...attempts {
            if let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
               ContainerStore.isApplicationContainerPath(path) {
                log("patch: target resolved bundle=\(bundleID) attempt=\(attempt)")
                return path
            }
            log("patch: target lookup pending bundle=\(bundleID) attempt=\(attempt)/\(attempts)")
            if attempt < attempts {
                Thread.sleep(forTimeInterval: 0.35)
            }
        }
        return nil
    }

    private static func displayName(for bundleID: String) -> String {
        switch bundleID {
        case "com.dts.freefireth": return "Free Fire"
        case "com.dts.freefiremax": return "Free Fire MAX"
        default: return bundleID
        }
    }
}
