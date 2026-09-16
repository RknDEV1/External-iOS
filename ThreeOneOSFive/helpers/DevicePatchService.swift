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
    // Legacy application entry point intentionally remains unavailable to
    // external-menu imports. It is not used by the safe validation flow.
    static func apply(project: PatchProject) throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.apply(
                project: project,
                backupRoot: try PatchProjectLibrary.backupRootURL(),
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func restore(receipt: PatchTransactionReceipt) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.restore(
                receipt: receipt,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func latestReceipt(projectID: UUID) -> PatchTransactionReceipt? {
        guard let backupRoot = try? PatchProjectLibrary.backupRootURL() else { return nil }
        return PatchTransaction.latestReceipt(projectID: projectID, backupRoot: backupRoot)
    }

    // MARK: - RKN-only External Menu operations

    /// Resources shipped with RKN. They are treated as inert data and never
    /// resolved as paths outside the app's own container.
    static func embeddedExternalArtifacts() -> [URL] {
        (Bundle.main.urls(forResourcesWithExtension: "3105", subdirectory: nil) ?? [])
            .filter { $0.pathExtension.lowercased() == "3105" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Validates a bundled artifact against the catalog digest and copies it into
    /// the app-private quarantine. No external container is accessed.
    static func validateEmbeddedExternalArtifact(_ bundledURL: URL) throws -> ExternalArtifactReport {
        guard bundledURL.isFileURL, bundledURL.pathExtension.lowercased() == "3105" else {
            throw PatchPackageError.unsupportedFormat
        }
        let data = try Data(contentsOf: bundledURL, options: [.mappedIfSafe])
        let summary = try PatchPackageCodec.inspect(data)
        if summary.isPasswordProtected {
            _ = try PatchPackageCodec.decode(data, password: "OG")
        } else {
            _ = try PatchPackageCodec.decode(data, password: nil)
        }
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

        if !FileManager.default.fileExists(atPath: receiptURL.path),
           !FileManager.default.fileExists(atPath: original.path),
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
        guard let state = try? readExternalState(editionKey: editionKey) else { return false }
        return state.verified
    }

    static func verifyExternalWorkingFile(editionKey: String) throws {
        let state = try readExternalState(editionKey: editionKey)
        guard state.verified else { throw PatchPackageError.restoreFailed }
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
        let receipt = try readInstallReceipt(from: receiptURL)
        guard receipt.editionKey == editionKey,
              receipt.destinationFilename == destination.lastPathComponent else {
            throw PatchPackageError.restoreFailed
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            let currentData = try Data(contentsOf: destination, options: [.mappedIfSafe])
            if sha256(currentData) != receipt.sha256 {
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
            try FileManager.default.removeItem(at: receiptURL)
            log("external: verified restore completed (original file was absent)")
            return destination
        }

        guard FileManager.default.fileExists(atPath: original.path),
              let expectedOriginalHash = receipt.originalSha256 else {
            throw PatchPackageError.invalidProject
        }
        let temporary = working.appendingPathComponent(".restore-\(UUID().uuidString).tmp")
        try FileManager.default.copyItem(at: original, to: temporary)
        let restoredData = try Data(contentsOf: temporary, options: [.mappedIfSafe])
        guard sha256(restoredData) == expectedOriginalHash else {
            try? FileManager.default.removeItem(at: temporary)
            throw PatchPackageError.restoreFailed
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        try FileManager.default.removeItem(at: original)
        try FileManager.default.removeItem(at: receiptURL)
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

    static func validateExternalArtifact(at sourceURL: URL) throws -> ExternalArtifactReport {
        try validateExternalArtifact(at: sourceURL, packageSummary: nil)
    }

    private static func validateExternalArtifact(
        at sourceURL: URL,
        packageSummary: PatchPackageSummary?
    ) throws -> ExternalArtifactReport {
        guard sourceURL.pathExtension.lowercased() == "3105" else {
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
        let root = try externalRoot().standardizedFileURL
        let candidate = url.standardizedFileURL
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
            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
                  ContainerStore.isApplicationContainerPath(path) else {
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try operation(roots)
    }
}
