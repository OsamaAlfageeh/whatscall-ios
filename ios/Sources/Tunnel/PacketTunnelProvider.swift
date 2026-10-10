import NetworkExtension
import WireGuardKit
import os

/// ملحق النفق: يستلم إعداد WireGuard من التطبيق ويشغّله عبر WireGuardKit الرسمية.
/// لا نكتب إعداد النفق ولا مفاتيحه في أي سجل.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { level, message in
            // رسائل المكتبة فقط (حالة الاتصال)، وليست الإعداد
            if level == .error {
                os_log("%{public}@", log: .default, type: .error, message)
            }
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard
            let proto = protocolConfiguration as? NETunnelProviderProtocol,
            let conf = proto.providerConfiguration?["wgQuickConfig"] as? String
        else {
            completionHandler(TunnelError.missingConfiguration)
            return
        }

        let tunnelConfiguration: TunnelConfiguration
        do {
            tunnelConfiguration = try TunnelConfiguration(fromWgQuickConfig: conf, called: "WhatsCall")
        } catch {
            completionHandler(TunnelError.invalidConfiguration)
            return
        }

        adapter.start(tunnelConfiguration: tunnelConfiguration) { adapterError in
            if adapterError != nil {
                completionHandler(TunnelError.startFailed)
            } else {
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        adapter.stop { _ in
            completionHandler()
        }
    }
}

enum TunnelError: Error {
    case missingConfiguration
    case invalidConfiguration
    case startFailed
}
