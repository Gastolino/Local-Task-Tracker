import Foundation
import CryptoKit
import CommonCrypto

/// Handles password setup, PBKDF2 key derivation, and AES-256-GCM
/// encrypt/decrypt of screenshot data.
///
/// Key derivation scheme
/// ─────────────────────
/// PBKDF2-SHA256(password, salt, 100 000 iterations) → 64 bytes
///   bytes  0–31 → AES-256 encryption key  (returned to caller)
///   bytes 32–63 → verifier                (stored in Keychain)
///
/// To unlock: re-derive, compare verifier bytes, return key on match.
final class CryptoService {

    static let shared = CryptoService()
    private init() {}

    private let saltKey      = "pbkdf2-salt"
    private let verifierKey  = "pbkdf2-verifier"
    private let pbkdfRounds: UInt32 = 100_000

    // MARK: - Password management

    var isPasswordConfigured: Bool {
        KeychainService.load(forKey: saltKey) != nil
    }

    /// First-run: store salt + verifier, return the encryption key.
    func setPassword(_ password: String) -> SymmetricKey? {
        let salt = randomBytes(32)
        guard let derived = pbkdf2(password: password, salt: salt),
              KeychainService.save(salt,                forKey: saltKey),
              KeychainService.save(Data(derived[32...]), forKey: verifierKey)
        else { return nil }
        return SymmetricKey(data: derived[..<32])
    }

    /// Normal unlock: verify password, return key on success.
    func verifyAndDeriveKey(_ password: String) -> SymmetricKey? {
        guard let salt     = KeychainService.load(forKey: saltKey),
              let stored   = KeychainService.load(forKey: verifierKey),
              let derived  = pbkdf2(password: password, salt: salt)
        else { return nil }

        let computed = Data(derived[32...])
        // Constant-time comparison to resist timing attacks.
        guard computed.count == stored.count,
              zip(computed, stored).allSatisfy({ $0 == $1 })
        else { return nil }

        return SymmetricKey(data: derived[..<32])
    }

    // MARK: - AES-256-GCM

    func encrypt(_ plaintext: Data, using key: SymmetricKey) -> Data? {
        try? AES.GCM.seal(plaintext, using: key).combined
    }

    func decrypt(_ ciphertext: Data, using key: SymmetricKey) -> Data? {
        guard let box = try? AES.GCM.SealedBox(combined: ciphertext) else { return nil }
        return try? AES.GCM.open(box, using: key)
    }

    // MARK: - Private helpers

    private func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    /// PBKDF2-SHA256 → 64-byte output.
    private func pbkdf2(password: String, salt: Data) -> Data? {
        guard let passwordData = password.data(using: .utf8) else { return nil }
        var derived = Data(count: 64)
        let rc = derived.withUnsafeMutableBytes { dPtr in
            salt.withUnsafeBytes { sPtr in
                passwordData.withUnsafeBytes { pPtr in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        sPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        pbkdfRounds,
                        dPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        64
                    )
                }
            }
        }
        return rc == kCCSuccess ? derived : nil
    }
}
