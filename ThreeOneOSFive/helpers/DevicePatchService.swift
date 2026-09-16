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
