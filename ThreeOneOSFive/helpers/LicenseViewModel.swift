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
    var product = "CHZ PRIV"
    var expiration: Date?
    var deviceID = "Indisponível"
}

protocol LicenseSessionProviding {
    func validateSavedLicense(completion: @escaping (LicenseSnapshot) -> Void)
}

struct CHZLoginKeychainProvider: LicenseSessionProviding {
    private var currentDeviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Indisponível"
    }

    func validateSavedLicense(completion: @escaping (LicenseSnapshot) -> Void) {
        CHZAuthManager.shared().validateSavedKey { [currentDeviceID] in
            DispatchQueue.main.async {
                completion(LicenseSnapshot(
                    status: .active,
                    product: "CHZ PRIV",
                    expiration: nil,
                    deviceID: currentDeviceID
                ))
            }
        } failure: { [currentDeviceID] message in
            let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let status: LicenseSnapshot.Status = normalized.contains("expir") ? .expired : .invalid
            DispatchQueue.main.async {
                completion(LicenseSnapshot(
                    status: status,
                    product: "CHZ PRIV",
                    expiration: nil,
                    deviceID: currentDeviceID
                ))
            }
        }
    }
}

@MainActor
final class LicenseViewModel: ObservableObject {
    @Published private(set) var snapshot = LicenseSnapshot()
    @Published private(set) var isValidating = false
    @Published var requiresLogin = false

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
        guard let expiration = snapshot.expiration else {
            return snapshot.status == .active ? "VALIDADA PELO CHZLOGIN" : "INDISPONÍVEL"
        }
        return expiration.formatted(date: .abbreviated, time: .shortened)
    }

    func refresh() {
        guard !isValidating else { return }
        isValidating = true
        requiresLogin = false
        snapshot.status = .loading
        provider.validateSavedLicense { [weak self] next in
            guard let self else { return }
            self.snapshot = next
            self.isValidating = false
            self.requiresLogin = next.status != .active
        }
    }
}
