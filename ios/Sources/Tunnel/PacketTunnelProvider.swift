import NetworkExtension
import WireGuardKit
import os

/// ملحق النفق: يستلم حقول الإعداد من التطبيق ويشغّل WireGuard عبر WireGuardKit الرسمية.
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
            let conf = proto.providerConfiguration,
            let tunnelConfiguration = Self.makeConfiguration(from: conf)
        else {
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

    /// يبني إعداد WireGuard من الحقول التي أرسلها التطبيق (دون محلّل نص).
    private static func makeConfiguration(from p: [String: Any]) -> TunnelConfiguration? {
        guard
            let priv = p["privateKey"] as? String, let privateKey = PrivateKey(base64Key: priv),
            let address = p["address"] as? String, let addressRange = IPAddressRange(from: address),
            let dns = p["dns"] as? String, let dnsServer = DNSServer(from: dns),
            let serverKey = p["serverPublicKey"] as? String, let publicKey = PublicKey(base64Key: serverKey),
            let endpointText = p["endpoint"] as? String, let endpoint = Endpoint(from: endpointText),
            let allowed = p["allowedIps"] as? String
        else { return nil }

        var interface = InterfaceConfiguration(privateKey: privateKey)
        interface.addresses = [addressRange]
        interface.dns = [dnsServer]

        var peer = PeerConfiguration(publicKey: publicKey)
        peer.endpoint = endpoint
        peer.allowedIPs = allowed
            .split(separator: ",")
            .compactMap { IPAddressRange(from: String($0).trimmingCharacters(in: .whitespaces)) }
        if peer.allowedIPs.isEmpty { return nil }
        peer.persistentKeepAlive = UInt16((p["keepalive"] as? Int) ?? 25)

        return TunnelConfiguration(name: "WhatsCall", interface: interface, peers: [peer])
    }
}

enum TunnelError: Error {
    case invalidConfiguration
    case startFailed
}
