import Foundation

/// حالة الاستحقاق كما يرسلها الخادم (التجربة أو الباقة).
struct AccessStatus: Decodable {
    let state: String          // trial | active | bonus | admin | expired
    let until: Double?         // ميلي ثانية
    let plan: String?
    let refCode: String?
    let invited: Int?
    let inviteGoal: Int?
    let inviteGoalDays: Int?
    let inviteGoalDone: Bool?
    let inviteTrialDays: Int?
    let inviteRewardDays: Int?

    var isActive: Bool { state != "expired" }

    var daysLeft: Int {
        guard let until else { return 0 }
        let hours = (Date(timeIntervalSince1970: until / 1000).timeIntervalSinceNow) / 3600
        return hours <= 0 ? 0 : Int((hours / 24).rounded(.up))
    }
}

/// ما يحتاجه الجوال لبناء إعداد النفق.
struct Provisioned: Decodable {
    let address: String
    let dns: String
    let serverPublicKey: String
    let endpoint: String
    let keepalive: Int
    let status: AccessStatus
    /// نطاقات ميتا التي تمر بالنفق على iOS (يرسلها الخادم، فتتحدث دون تحديث التطبيق)
    let iosAllowedIps: String?
    let referral: String?
}

enum RegisterResult {
    case ready(Provisioned)
    case expired(AccessStatus)
}

struct ApiError: Error {
    let status: Int
}

/// عميل الخادم: نفس واجهة تطبيق أندرويد (`/v1/*`)، بمفتاح الـAPI الذي يُحقن عند البناء.
final class ApiClient {
    private let base: URL
    private let apiKey: String
    private let session: URLSession

    init(bundle: Bundle = .main) {
        let host = (bundle.object(forInfoDictionaryKey: "WCApiHost") as? String) ?? "whatscall.live"
        self.base = URL(string: "https://\(host)")!
        self.apiKey = (bundle.object(forInfoDictionaryKey: "WCApiKey") as? String) ?? ""
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: cfg)
    }

    private func call(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> (Data, Int) {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await session.data(for: req)
        return (data, (resp as? HTTPURLResponse)?.statusCode ?? 0)
    }

    /// يسجّل الجهاز (تجربة مجانية أول مرة) أو يجدد إعداده. 402 = انتهى الاستحقاق.
    func register(publicKey: String, hw: String, ref: String? = nil) async throws -> RegisterResult {
        var body: [String: Any] = ["publicKey": publicKey, "hw": hw]
        if let ref, !ref.isEmpty { body["ref"] = ref }
        let (data, code) = try await call("POST", "v1/peers", body: body)
        let dec = JSONDecoder()
        switch code {
        case 200:
            return .ready(try dec.decode(Provisioned.self, from: data))
        case 402:
            struct Expired: Decodable { let status: AccessStatus }
            return .expired(try dec.decode(Expired.self, from: data).status)
        default:
            throw ApiError(status: code)
        }
    }

    func status(publicKey: String) async throws -> AccessStatus {
        let (data, code) = try await call("POST", "v1/status", body: ["publicKey": publicKey])
        guard code == 200 else { throw ApiError(status: code) }
        return try JSONDecoder().decode(AccessStatus.self, from: data)
    }

    /// إعداد WireGuard بصيغة wg-quick. على iOS لا يمر بالنفق إلا نطاقات ميتا التي يحددها الخادم.
    static func wgQuick(privateKey: String, _ p: Provisioned) -> String? {
        guard let allowed = p.iosAllowedIps, !allowed.isEmpty else { return nil }
        return """
        [Interface]
        PrivateKey = \(privateKey)
        Address = \(p.address)
        DNS = \(p.dns)

        [Peer]
        PublicKey = \(p.serverPublicKey)
        Endpoint = \(p.endpoint)
        AllowedIPs = \(allowed)
        PersistentKeepalive = \(p.keepalive)
        """
    }
}
