import Foundation

import CryptoKit

enum PatchCategory: String, CaseIterable, Identifiable {
    case avatar = "Avatar"
    case cache = "Cache"
    case external = "External"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .avatar: return "scope"
        case .cache: return "antenna.radiowaves.left.and.right"
        case .external: return "rectangle.3.group.fill"
        }
    }

    static func from(packageURL: URL) -> PatchCategory {
        PatchCategory(rawValue: packageURL.deletingLastPathComponent().lastPathComponent) ?? .avatar
    }
}

struct PatchLibraryItem: Identifiable {
    let summary: PatchPackageSummary
    var project: PatchProject?
    var contentKey: Data?
    var packageURL: URL

    var id: UUID { summary.packageID }
    var isLocked: Bool { project == nil }
    var category: PatchCategory { PatchCategory.from(packageURL: packageURL) }
    var workspaceURL: URL? {
        PatchWorkspaceService.workspaceURL(projectID: id)
    }
}

struct PatchPasswordRequest: Identifiable {
    let summary: PatchPackageSummary
    var id: UUID { summary.packageID }
}

enum PatchProjectLibrary {
    static func packageRootURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent("PatchProjects", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func backupRootURL(fileManager: FileManager = .default) throws -> URL {
        let root = try packageRootURL(fileManager: fileManager)
            .appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func installBundledFreeFirePatches(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) {
        let urls = (bundle.urls(forResourcesWithExtension: "bin", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("P") }
        guard !urls.isEmpty else {
            log("patch: no bundled Free Fire packages found")
            return
        }

        do {
            let root = try packageRootURL(fileManager: fileManager)
            for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                do {
                    let encryptedData = try Data(contentsOf: url, options: .mappedIfSafe)
                    let data = try decryptBundledPatch(encryptedData)
                    let summary = try PatchPackageCodec.inspect(data)
                    let decoded: DecodedPatchPackage
                    if let contentKey = try PatchKeyStore.load(for: summary) {
                        decoded = try PatchPackageCodec.decode(data, contentKey: contentKey)
                    } else {
                        decoded = try PatchPackageCodec.decode(data, password: nil)
                    }

                    let destinationName = sanitizedFilename(decoded.project.name) + ".3105"
                    let destination = root.appendingPathComponent(destinationName)
                    let shouldInstall: Bool
                    if fileManager.fileExists(atPath: destination.path) {
                        shouldInstall = (try? readPackage(at: destination)) != data
                    } else {
                        shouldInstall = true
                    }
                    if shouldInstall {
                        try installImportedPackage(
                            data: data,
                            decoded: decoded,
                            summary: summary,
                            existingURL: destination,
                            fileManager: fileManager
                        )
                        log("patch: bundled Free Fire package installed — \(decoded.project.name)")
                    }
                } catch {
                    log("patch: bundled Free Fire package skipped — \(url.lastPathComponent)")
                }
            }
        } catch {
            log("patch: unable to prepare bundled Free Fire packages")
        }
    }

    static func installBundledOriginalFreeFirePatches(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) {
        var discoveredURLs = bundle.urls(forResourcesWithExtension: "3105", subdirectory: nil) ?? []
        for category in PatchCategory.allCases {
            discoveredURLs += bundle.urls(
                forResourcesWithExtension: "3105",
                subdirectory: category.rawValue
            ) ?? []
        }
        var uniqueURLs: [URL] = []
        var seenPaths = Set<String>()
        for url in discoveredURLs where seenPaths.insert(url.path).inserted {
            uniqueURLs.append(url)
        }
        let urls = uniqueURLs
        guard !urls.isEmpty else {
            log("patch: no bundled original Free Fire packages found")
            return
        }

        do {
            let root = try packageRootURL(fileManager: fileManager)
            let manifestCategories = bundledManifestCategories(bundle: bundle)
            for source in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let category = manifestCategories[source.lastPathComponent]
                    ?? PatchCategory.from(packageURL: source)
                let categoryRoot = root.appendingPathComponent(category.rawValue, isDirectory: true)
                try fileManager.createDirectory(at: categoryRoot, withIntermediateDirectories: true)
                let destination = categoryRoot.appendingPathComponent(source.lastPathComponent)
                let sourceData = try Data(contentsOf: source, options: .mappedIfSafe)
                let needsCopy: Bool
                if fileManager.fileExists(atPath: destination.path) {
                    needsCopy = (try? readPackage(at: destination)) != sourceData
                } else {
                    needsCopy = true
                }
                if needsCopy {
                    try sourceData.write(to: destination, options: [.atomic, .completeFileProtection])
                    log("patch: bundled original package imported — \(source.deletingPathExtension().lastPathComponent)")
                }
            }
        } catch {
            log("patch: unable to import bundled original Free Fire packages")
        }
    }

    private static func bundledManifestCategories(bundle: Bundle) -> [String: PatchCategory] {
        guard let manifestURL = bundle.url(forResource: "manifest", withExtension: "json"),
              let data = try? Data(contentsOf: manifestURL),
              let entries = try? JSONDecoder().decode([BundledManifestEntry].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
            guard let category = PatchCategory(rawValue: entry.category) else { return nil }
            return (entry.file, category)
        })
    }

    private struct BundledManifestEntry: Decodable {
        let category: String
        let file: String
    }

    private static func decryptBundledPatch(_ encrypted: Data) throws -> Data {
        let magic = Data("CHZP1\0".utf8)
        guard encrypted.count > magic.count + 12,
              encrypted.prefix(magic.count) == magic else {
            throw PatchPackageError.unsupportedFormat
        }
        let seed = Data("chz-priv-free-fire-v1-protected".utf8)
        let bundleID = Data("com.apple.mobile.MobileHouseArrest".utf8)
        let keyDigest = SHA256.hash(data: seed + Data("|".utf8) + bundleID)
        let key = SymmetricKey(data: Data(keyDigest))
        let combined = Data(encrypted.dropFirst(magic.count))
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(sealedBox, using: key, authenticating: magic)
    }

    static func load(fileManager: FileManager = .default) -> [PatchLibraryItem] {
        guard let root = try? packageRootURL(fileManager: fileManager),
              let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }

        let urls = enumerator.compactMap { $0 as? URL }
        var byID: [UUID: PatchLibraryItem] = [:]
        for url in urls where url.pathExtension.lowercased() == "3105" {
            do {
                let data = try readPackage(at: url)
                let summary = try PatchPackageCodec.inspect(data)
                let decoded: DecodedPatchPackage?
                if let contentKey = try PatchKeyStore.load(for: summary) {
                    decoded = try PatchPackageCodec.decode(data, contentKey: contentKey)
                } else if summary.isPasswordProtected {
                    decoded = nil
                } else {
                    decoded = try PatchPackageCodec.decode(data, password: nil)
                }
                let item = PatchLibraryItem(
                    summary: summary,
                    project: decoded?.project,
                    contentKey: decoded?.contentKey,
                    packageURL: url
                )
                if summary.schemaVersion >= 2, let project = decoded?.project {
                    do {
                        _ = try PatchWorkspaceService.ensureWorkspace(for: project)
                    } catch {
                        log("patch: workspace unavailable for \(project.id.uuidString)")
                    }
                }
                byID[summary.packageID] = item
            } catch {
                log("patch: skipped invalid local package \(url.lastPathComponent)")
            }
        }
        return byID.values.sorted {
            ($0.project?.updatedAt ?? .distantPast) > ($1.project?.updatedAt ?? .distantPast)
        }
    }

    static func readPackage(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isDirectory != true,
              values.isSymbolicLink != true,
              values.isRegularFile == true else {
            throw PatchPackageError.invalidProject
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    static func save(
        data: Data,
        projectName: String,
        existingURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let destination: URL
        if let existingURL {
            destination = existingURL
        } else {
            let root = try packageRootURL(fileManager: fileManager)
            let baseName = sanitizedFilename(projectName)
            var candidate = root.appendingPathComponent(baseName).appendingPathExtension("3105")
            var suffix = 2
            while fileManager.fileExists(atPath: candidate.path) {
                candidate = root.appendingPathComponent("\(baseName)-\(suffix)").appendingPathExtension("3105")
                suffix += 1
            }
            destination = candidate
        }
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        return destination
    }

    static func installImportedPackage(
        data: Data,
        decoded: DecodedPatchPackage,
        summary: PatchPackageSummary,
        existingURL: URL?,
        fileManager: FileManager = .default
    ) throws {
        let previousData = try existingURL.map { try readPackage(at: $0) }
        var savedURL: URL?
        do {
            savedURL = try save(
                data: data,
                projectName: decoded.project.name,
                existingURL: existingURL,
                fileManager: fileManager
            )
            if summary.schemaVersion >= 2 {
                _ = try PatchWorkspaceService.replaceWorkspace(
                    with: decoded.project,
                    fileManager: fileManager
                )
            } else {
                try? PatchWorkspaceService.deleteWorkspace(
                    projectID: decoded.project.id,
                    fileManager: fileManager
                )
            }
        } catch {
            if let previousData, let existingURL {
                try? previousData.write(
                    to: existingURL,
                    options: [.atomic, .completeFileProtection]
                )
            } else if let savedURL, fileManager.fileExists(atPath: savedURL.path) {
                try? fileManager.removeItem(at: savedURL)
            }
            throw error
        }
    }

    static func delete(_ item: PatchLibraryItem, fileManager: FileManager = .default) throws {
        if fileManager.fileExists(atPath: item.packageURL.path) {
            try fileManager.removeItem(at: item.packageURL)
        }
        try? PatchWorkspaceService.deleteWorkspace(projectID: item.id, fileManager: fileManager)
        try? PatchKeyStore.delete(for: item.summary)
    }

    static func synchronizeWorkspace(
        item: PatchLibraryItem,
        fileManager: FileManager = .default
    ) throws -> PatchProject {
        guard item.summary.schemaVersion >= 2,
              let baseProject = item.project,
              let contentKey = item.contentKey else {
            throw PatchPackageError.invalidProject
        }
        let workspace = try PatchWorkspaceService.ensureWorkspace(
            for: baseProject,
            fileManager: fileManager
        )
        let project = try PatchWorkspaceService.snapshot(
            baseProject: baseProject,
            workspaceURL: workspace,
            fileManager: fileManager
        )
        let original = try readPackage(at: item.packageURL)
        let updated = try PatchPackageCodec.update(
            original,
            project: project,
            contentKey: contentKey,
            schemaVersion: PatchPackageCodec.latestSchemaVersion
        )
        _ = try save(
            data: updated,
            projectName: project.name,
            existingURL: item.packageURL,
            fileManager: fileManager
        )
        return project
    }

    private static func sanitizedFilename(_ rawName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let scalars = rawName.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let result = String(scalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
        return result.isEmpty ? "Patch" : String(result)
    }
}
