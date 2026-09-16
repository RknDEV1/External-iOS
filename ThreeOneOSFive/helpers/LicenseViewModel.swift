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
    var product = "RKN"
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
        let manager = CHZAuthManager.shared()
        let hasSession = manager.hasValidSavedSession()
        let status: LicenseSnapshot.Status = hasSession ? .active : .invalid
        let snapshot = LicenseSnapshot(
            status: status,
            product: "RKN",
            expiration: nil,
            deviceID: currentDeviceID
        )
        DispatchQueue.main.async {
            completion(snapshot)
        }
    }
}

@MainActor
final class LicenseViewModel: ObservableObject {
    @Published private(set) var snapshot = LicenseSnapshot()
    @Published private(set) var isValidating = false
    @Published var requiresLogin = false

    private let provider: LicenseSessionProviding
    private var sessionConfirmedInCurrentProcess = false

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

    func markAuthenticatedInCurrentProcess() {
        sessionConfirmedInCurrentProcess = true
        snapshot.status = .active
        snapshot.product = "RKN"
        isValidating = false
        requiresLogin = false
    }

    func refresh() {
        guard !sessionConfirmedInCurrentProcess else { return }
        guard !isValidating else { return }
        isValidating = true
        requiresLogin = false
        snapshot.status = .loading
        provider.validateSavedLicense { [weak self] next in
            guard let self else { return }
            self.snapshot = next
            self.isValidating = false
            if next.status == .active {
                self.sessionConfirmedInCurrentProcess = true
            }
            self.requiresLogin = next.status != .active
        }
    }
}
