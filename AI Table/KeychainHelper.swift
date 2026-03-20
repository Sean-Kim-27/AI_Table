import Foundation
import Security

// 키체인 접근을 돕는 유틸리티
class KeychainHelper {
    static let standard = KeychainHelper()
    private init() {}

    // API 키 저장
    func save(_ data: Data, service: String, account: String) {
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary

        // 동일 항목이 있으면 삭제 후 저장
        SecItemDelete(query)
        let status = SecItemAdd(query, nil)

        if status != errSecSuccess {
            print("KeyChain Error : \(status)")
        }
    }

    // API 키 조회
    func read(service: String, account: String) -> Data? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query, &dataTypeRef)

        if status == errSecSuccess {
            return dataTypeRef as? Data
        } else {
            return nil
        }
    }
}

// 키 4개를 하나로 묶는 JSON 번들
struct APIKeyBundle: Codable {
    var openai: String = ""
    var gemini: String = ""
    var groq: String = ""
    var claude: String = ""
}

// 키체인 저장/불러오기 매니저
class KeyManager {
    static let accountName = "bundled_api_keys"

    static func saveAll(openai: String, gemini: String, groq: String, claude: String) {
        let bundle = APIKeyBundle(openai: openai, gemini: gemini, groq: groq, claude: claude)
        if let data = try? JSONEncoder().encode(bundle) {
            KeychainHelper.standard.save(data, service: "MyAIDock", account: accountName)
        }
    }

    static func loadAll() -> APIKeyBundle {
        if let data = KeychainHelper.standard.read(service: "MyAIDock", account: accountName),
           let bundle = try? JSONDecoder().decode(APIKeyBundle.self, from: data) {
            return bundle
        }
        return APIKeyBundle()
    }
}
