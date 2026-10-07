import Foundation
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
    var product = "3105"
    var expiration: Date?
    var deviceID = "Indisponível"
}

protocol LicenseSessionProviding {
    func validateSavedLicense(completion: @escaping (LicenseSnapshot) -> Void)
}

/// Adapter between the license screen and the actual CHZLogin framework
/// session. The screen never invents an expiration date: the framework only
/// exposes whether the saved session is currently valid.
struct CHZLicenseSessionProvider: LicenseSessionProviding {
    private var currentDeviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Indisponível"
    }

    func validateSavedLicense(completion: @escaping (LicenseSnapshot) -> Void) {
        let manager = CHZAuthManager.shared()
        let deviceID = currentDeviceID

        guard manager.hasValidSavedSession() else {
            finish(
                LicenseSnapshot(
                    status: .unavailable,
                    product: "3105",
                    expiration: nil,
                    deviceID: deviceID
                ),
                completion: completion
            )
            return
        }

        manager.validateSavedSession(success: {
            finish(
                LicenseSnapshot(
                    status: .active,
                    product: "3105",
                    expiration: nil,
                    deviceID: deviceID
                ),
                completion: completion
            )
        }, failure: { _ in
            finish(
                LicenseSnapshot(
                    status: .invalid,
                    product: "3105",
                    expiration: nil,
                    deviceID: deviceID
                ),
                completion: completion
            )
        })
    }

    private func finish(
        _ snapshot: LicenseSnapshot,
        completion: @escaping (LicenseSnapshot) -> Void
    ) {
        DispatchQueue.main.async {
            completion(snapshot)
        }
    }
}

/// Fallback used by previews or targets that do not link the login framework.
struct UnauthenticatedLicenseProvider: LicenseSessionProviding {
    private var currentDeviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Indisponível"
    }

    func validateSavedLicense(completion: @escaping (LicenseSnapshot) -> Void) {
        let snapshot = LicenseSnapshot(
            status: .unavailable,
            product: "3105",
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
    private let provider: LicenseSessionProviding
    private var sessionConfirmedInCurrentProcess = false

    init(provider: LicenseSessionProviding = CHZLicenseSessionProvider()) {
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
        case .expired, .invalid: return AppTheme.accentBright
        }
    }

    var expirationText: String {
        guard let expiration = snapshot.expiration else {
            switch snapshot.status {
            case .active: return "SESSÃO VÁLIDA"
            case .loading: return "AGUARDANDO VALIDAÇÃO"
            case .expired: return "PRAZO ENCERRADO"
            case .invalid: return "REVALIDAÇÃO NECESSÁRIA"
            case .unavailable: return "NÃO CONFIGURADA"
            }
        }
        return expiration.formatted(date: .abbreviated, time: .shortened)
    }

    func refresh() {
        guard !sessionConfirmedInCurrentProcess else { return }
        guard !isValidating else { return }
        isValidating = true
        snapshot.status = .loading
        provider.validateSavedLicense { [weak self] next in
            guard let self else { return }
            self.snapshot = next
            self.isValidating = false
            if next.status == .active {
                self.sessionConfirmedInCurrentProcess = true
            }
        }
    }
}
