import Foundation
import NetworkExtension

/// يتحكم بنفق النظام (NETunnelProviderManager) ويعرض حالته.
@MainActor
final class VPNManager: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?

    var isUp: Bool { status == .connected || status == .connecting || status == .reasserting }

    func load() async {
        let all = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        let m = all.first ?? NETunnelProviderManager()
        manager = m
        status = m.connection.status
        observe(m)
    }

    private func observe(_ m: NETunnelProviderManager) {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: m.connection, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.status = m.connection.status }
        }
    }

    /// يحفظ الإعداد ويشغّل النفق. أول مرة يطلب النظام إذن إضافة VPN.
    func connect(wgQuick: String) async throws {
        let m = manager ?? NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "live.whatscall.tunnel"
        proto.serverAddress = "Whats Call"
        proto.providerConfiguration = ["wgQuickConfig": wgQuick]
        m.protocolConfiguration = proto
        m.localizedDescription = "واتس كول"
        m.isEnabled = true
        try await m.saveToPreferences()
        try await m.loadFromPreferences() // مطلوب قبل التشغيل بعد أول حفظ
        manager = m
        observe(m)
        try m.connection.startVPNTunnel()
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }
}
