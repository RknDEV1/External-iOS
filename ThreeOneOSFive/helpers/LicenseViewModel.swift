import Foundation
import Security
import SwiftUI
import UIKit

struct LicenseSnapshot: Equatable {
    enum Status: Equatable {
        case loading
        case active
        case expired
        case invalid
        case unavailable
    }

    var status: Status = .loading
    var product = "EXTERNAL"
    var expiration: Date?
    var deviceID = "Indisponível"
}

protocol LicenseSessionProviding {
    func loadSnapshot() -> LicenseSnapshot
}

struct CHZLoginKeychainProvider: LicenseSessionProviding {
    private let service = "com.chzpriv.login"
    private let account = "validated_session_v1"

    func loadSnapshot() -> LicenseSnapshot {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let object = try? JSONSerialization.jsonObject(with: data),
              let session = object as? [String: Any] else {
            return LicenseSnapshot(
                status: .unavailable,
                deviceID: currentDeviceID
            )
        }

        let expiryText = session["expiry"] as? String ?? ""
        guard let expiry = parseDate(expiryText) else {
            return LicenseSnapshot(
                status: .invalid,
                expiration: nil,
                deviceID: currentDeviceID
            )
        }

        return LicenseSnapshot(
            status: expiry > Date() ? .active : .expired,
            product: "EXTERNAL",
            expiration: expiry,
            deviceID: currentDeviceID
        )
    }

    private var currentDeviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Indisponível"
    }

    private func parseDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }

        if let timestamp = Double(value) {
            return Date(timeIntervalSince1970: timestamp)
        }

        for format in ["yyyy-MM-dd HH:mm:ss Z", "yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ssXXXXX"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}

@MainActor
final class LicenseViewModel: ObservableObject {
    @Published private(set) var snapshot = LicenseSnapshot()

    private let provider: LicenseSessionProviding

    init(provider: LicenseSessionProviding = CHZLoginKeychainProvider()) {
        self.provider = provider
    }

    var isActive: Bool { snapshot.status == .active }

    var statusText: String {
        switch snapshot.status {
        case .loading: return "VERIFICANDO"
        case .active: return "ATIVA"
        case .expired: return "EXPIRADA"
        case .invalid: return "INVÁLIDA"
        case .unavailable: return "INDISPONÍVEL"
        }
    }

    var statusColor: Color {
        switch snapshot.status {
        case .active: return AppTheme.success
        case .loading, .unavailable: return AppTheme.secondaryText
        case .expired, .invalid: return .red
        }
    }

    var expirationText: String {
        guard let expiration = snapshot.expiration else { return "INDISPONÍVEL" }
        return expiration.formatted(date: .abbreviated, time: .shortened)
    }

    func refresh() {
        snapshot.status = .loading
        let next = provider.loadSnapshot()
        snapshot = next
    }
}
