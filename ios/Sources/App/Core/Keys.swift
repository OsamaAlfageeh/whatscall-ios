import CryptoKit
import Foundation
import Security

/// مفتاح WireGuard للجهاز (Curve25519) ومعرّف الجهاز الثابت. المفتاح الخاص لا يغادر الجوال.
enum DeviceKeys {
    private static let service = "live.whatscall"

    /// يُنشأ أول مرة ويُحفظ في Keychain؛ ويبقى بعد حذف التطبيق وإعادة تثبيته على iOS في الغالب.
    static func keyPair() -> (privateKey: String, publicKey: String) {
        if let stored = Keychain.read("wg-private"), let raw = Data(base64Encoded: stored),
           let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw) {
            return (stored, key.publicKey.rawRepresentation.base64EncodedString())
        }
        let key = Curve25519.KeyAgreement.PrivateKey()
        let priv = key.rawRepresentation.base64EncodedString()
        Keychain.write("wg-private", priv)
        return (priv, key.publicKey.rawRepresentation.base64EncodedString())
    }

    /// معرّف ثابت للجهاز يمنع تكرار التجربة المجانية ويعيد الباقة بعد إعادة التثبيت. يُرسل للخادم ليحفظه مجزّأً فقط.
    /// الخادم يقبل 16 خانة سداسية، فنكوّنه من UUID محفوظ.
    static func hardwareId() -> String {
        if let id = Keychain.read("hw-id"), id.count == 16 { return id }
        let id = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(16))
        Keychain.write("hw-id", id)
        return id
    }
}

enum Keychain {
    private static let service = "live.whatscall"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ account: String, _ value: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        // بعد أول فتح للجهاز (حتى يعمل في الخلفية)، ولا يُنقل لجهاز آخر
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
