import CryptoKit
import Foundation

struct ExternalArtifactReport: Codable, Equatable, Identifiable {
    let id: UUID
    let filename: String
    let byteCount: Int64
    let sha256: String
    let validatedAt: Date
    let storageURL: URL
    var diagnosticEnabled: Bool
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

    // MARK: - CHZ PRIV-only External Menu operations

    /// Resources shipped with CHZ PRIV. They are treated as inert data and never
    /// resolved as paths outside the app's own container.
    static func embeddedExternalArtifacts() -> [URL] {
        (Bundle.main.urls(forResourcesWithExtension: "3105", subdirectory: nil) ?? [])
            .filter { $0.pathExtension.lowercased() == "3105" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Validates a bundled artifact and copies it into the app-private quarantine.
    static func validateEmbeddedExternalArtifact(_ bundledURL: URL) throws -> ExternalArtifactReport {
        guard bundledURL.isFileURL, bundledURL.pathExtension.lowercased() == "3105" else {
            throw PatchPackageError.unsupportedFormat
        }
        return try validateExternalArtifact(at: bundledURL)
    }

    /// Installs only into the app-private working area. The operation is
    /// transactional: write temporary data, verify its digest, then replace.
    static func installExternalArtifact(_ report: ExternalArtifactReport, editionKey: String) throws -> URL {
        let source = try privateOwnedFile(report.storageURL)
        let root = try externalRoot()
        let working = root.appendingPathComponent("Working", isDirectory: true)
        try FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)

        let safeKey = editionKey.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let destination = working.appendingPathComponent("\(safeKey).3105")
        let temporary = working.appendingPathComponent(".\(safeKey).\(UUID().uuidString).tmp")
        let original = working.appendingPathComponent("\(safeKey).original.3105")

        if FileManager.default.fileExists(atPath: destination.path),
           !FileManager.default.fileExists(atPath: original.path) {
            try FileManager.default.copyItem(at: destination, to: original)
        }
        try FileManager.default.copyItem(at: source, to: temporary)
        let copiedData = try Data(contentsOf: temporary, options: [.mappedIfSafe])
        guard sha256(copiedData) == report.sha256 else {
            try? FileManager.default.removeItem(at: temporary)
            throw PatchPackageError.restoreFailed
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        log("external: installed \(report.filename) into private working file \(destination.lastPathComponent)")
        return destination
    }

    static func restoreExternalWorkingFile(editionKey: String) throws -> URL {
        let root = try externalRoot()
        let working = root.appendingPathComponent("Working", isDirectory: true)
        let safeKey = editionKey.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let destination = working.appendingPathComponent("\(safeKey).3105")
        let original = working.appendingPathComponent("\(safeKey).original.3105")
        guard FileManager.default.fileExists(atPath: original.path) else {
            throw PatchPackageError.invalidProject
        }
        let temporary = working.appendingPathComponent(".restore-\(UUID().uuidString).tmp")
        try FileManager.default.copyItem(at: original, to: temporary)
        let restoredData = try Data(contentsOf: temporary, options: [.mappedIfSafe])
        guard !restoredData.isEmpty else {
            try? FileManager.default.removeItem(at: temporary)
            throw PatchPackageError.restoreFailed
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        log("external: restored private working file \(destination.lastPathComponent)")
        return destination
    }

    static func validateExternalArtifact(at sourceURL: URL) throws -> ExternalArtifactReport {
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
