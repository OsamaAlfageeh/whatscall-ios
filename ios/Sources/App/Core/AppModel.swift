import Foundation
import NetworkExtension
import SwiftUI

/// منطق الشاشة الرئيسية: تسجيل الجهاز، التجربة، وتشغيل النفق وإيقافه.
@MainActor
final class AppModel: ObservableObject {
    enum Failure: Equatable {
        case network
        case notConfigured   // الخادم لا يرسل نطاقات الآيفون بعد
        case vpn
    }

    @Published var access: AccessStatus?
    @Published var failure: Failure?
    @Published var busy = false
    @Published var consented: Bool = UserDefaults.standard.bool(forKey: "consented")

    let vpn = VPNManager()
    private let api = ApiClient()

    func start() async {
        await vpn.load()
        await refresh()
    }

    func acceptDisclosure() {
        consented = true
        UserDefaults.standard.set(true, forKey: "consented")
    }

    /// يسجّل الجهاز دون تشغيل النفق ليظهر وقت التجربة وكود الدعوة قبل أول اتصال.
    func refresh() async {
        guard consented else { return }
        let keys = DeviceKeys.keyPair()
        do {
            switch try await api.register(publicKey: keys.publicKey, hw: DeviceKeys.hardwareId()) {
            case .ready(let p): access = p.status
            case .expired(let s): access = s
            }
            failure = nil
        } catch {
            failure = .network
        }
    }

    func toggle() async {
        if vpn.isUp {
            vpn.disconnect()
            return
        }
        guard consented, !busy else { return }
        busy = true
        defer { busy = false }
        let keys = DeviceKeys.keyPair()
        do {
            switch try await api.register(publicKey: keys.publicKey, hw: DeviceKeys.hardwareId()) {
            case .expired(let s):
                access = s
                failure = nil
            case .ready(let p):
                access = p.status
                guard let params = ApiClient.tunnelParams(privateKey: keys.privateKey, p) else {
                    failure = .notConfigured
                    return
                }
                do {
                    try await vpn.connect(params: params)
                    failure = nil
                } catch {
                    failure = .vpn
                }
            }
        } catch {
            failure = .network
        }
    }
}
