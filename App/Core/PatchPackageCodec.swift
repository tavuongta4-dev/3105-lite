import CommonCrypto
import CryptoKit
import Foundation

/// Decoder for the portable `.3105` package format (schema v1 = legacy, v2 = current).
///
/// Layout:
///   magic "3105PATCH\0" (10 bytes) + binary plist Envelope
///   Envelope.encryptedPayload = AES-256-GCM(binary plist Payload)
///   Payload = { project: PatchProject, replacementDigests: [ruleID: SHA256(data)] }
enum PatchPackageCodec {
    private static let magic = Data("3105PATCH\0".utf8)
    private static let minimumVersion = 1
    private static let maximumVersion = 2

    private struct Envelope: Codable {
        let schemaVersion: Int
        let keyAADVersion: Int?
        let packageID: UUID
        let isPasswordProtected: Bool
        let kdfSalt: Data?
        let kdfIterations: Int?
        let wrappedContentKey: Data?
        let publicContentKey: Data?
        let keyFingerprint: Data
        let encryptedPayload: Data
    }

    private struct Payload: Codable {
        let project: PatchProject
        let replacementDigests: [String: Data]
    }

    // MARK: Inspect

    static func inspect(_ data: Data) throws -> PatchPackageSummary {
        let envelope = try parseEnvelope(data)
        return PatchPackageSummary(
            packageID: envelope.packageID,
            schemaVersion: envelope.schemaVersion,
            isPasswordProtected: envelope.isPasswordProtected
        )
    }

    // MARK: Decode

    static func decode(_ data: Data, password: String?) throws -> DecodedPatch {
        let envelope = try parseEnvelope(data)
        let contentKey: Data

        if envelope.isPasswordProtected {
            guard let password, !password.isEmpty,
                  let salt = envelope.kdfSalt,
                  let iterations = envelope.kdfIterations,
                  let wrappedKey = envelope.wrappedContentKey
            else {
                throw PatchError.invalidPasswordOrCorrupted
            }
            let wrappingKey = try deriveKey(password: password, salt: salt, iterations: iterations)
            let version = envelope.keyAADVersion ?? envelope.schemaVersion
            contentKey = try open(
                wrappedKey,
                key: wrappingKey,
                aad: keyAAD(for: envelope.packageID, version: version)
            )
        } else {
            guard let storedKey = envelope.publicContentKey else {
                throw PatchError.invalidPasswordOrCorrupted
            }
            contentKey = storedKey
        }

        return try decodePayload(envelope: envelope, contentKey: contentKey)
    }

    static func decode(_ data: Data, contentKey: Data) throws -> DecodedPatch {
        let envelope = try parseEnvelope(data)
        return try decodePayload(envelope: envelope, contentKey: contentKey)
    }

    private static func decodePayload(envelope: Envelope, contentKey: Data) throws -> DecodedPatch {
        guard contentKey.count == 32,
              fingerprint(contentKey) == envelope.keyFingerprint
        else {
            throw PatchError.invalidPasswordOrCorrupted
        }

        let payloadData = try open(
            envelope.encryptedPayload,
            key: contentKey,
            aad: payloadAAD(for: envelope.packageID, version: envelope.schemaVersion)
        )
        let payload: Payload
        do {
            payload = try PropertyListDecoder().decode(Payload.self, from: payloadData)
        } catch {
            throw PatchError.invalidPasswordOrCorrupted
        }

        guard payload.project.id == envelope.packageID,
              payload.replacementDigests.count == payload.project.rules.count
        else {
            throw PatchError.invalidPasswordOrCorrupted
        }
        for rule in payload.project.rules {
            let digest = Data(SHA256.hash(data: rule.replacementData))
            guard payload.replacementDigests[rule.id.uuidString] == digest else {
                throw PatchError.invalidPasswordOrCorrupted
            }
        }

        return DecodedPatch(project: payload.project, contentKey: contentKey)
    }

    // MARK: Envelope parsing

    private static func parseEnvelope(_ data: Data) throws -> Envelope {
        guard data.count > magic.count, data.prefix(magic.count) == magic else {
            throw PatchError.unsupportedFormat
        }
        let body = data.dropFirst(magic.count)

        let envelope: Envelope
        do {
            envelope = try PropertyListDecoder().decode(Envelope.self, from: Data(body))
        } catch {
            throw PatchError.invalidPasswordOrCorrupted
        }

        guard (minimumVersion...maximumVersion).contains(envelope.schemaVersion) else {
            throw PatchError.unsupportedVersion
        }
        guard envelope.keyFingerprint.count == 32,
              envelope.encryptedPayload.count >= 28
        else {
            throw PatchError.invalidPasswordOrCorrupted
        }

        if envelope.isPasswordProtected {
            guard envelope.publicContentKey == nil,
                  envelope.kdfSalt?.count == 16,
                  let iterations = envelope.kdfIterations,
                  (100_000...1_000_000).contains(iterations),
                  envelope.wrappedContentKey != nil
            else {
                throw PatchError.invalidPasswordOrCorrupted
            }
        } else {
            guard envelope.kdfSalt == nil,
                  envelope.kdfIterations == nil,
                  envelope.wrappedContentKey == nil,
                  envelope.publicContentKey?.count == 32
            else {
                throw PatchError.invalidPasswordOrCorrupted
            }
        }
        return envelope
    }

    // MARK: Crypto

    private static func open(_ ciphertext: Data, key: Data, aad: Data) throws -> Data {
        let box: AES.GCM.SealedBox
        do {
            box = try AES.GCM.SealedBox(combined: ciphertext)
            return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
        } catch {
            throw PatchError.invalidPasswordOrCorrupted
        }
    }

    private static func deriveKey(password: String, salt: Data, iterations: Int) throws -> Data {
        let passwordData = Data(password.utf8)
        var output = Data(count: 32)
        let status = output.withUnsafeMutableBytes { outputBuffer in
            passwordData.withUnsafeBytes { passwordBuffer in
                salt.withUnsafeBytes { saltBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBuffer.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        outputBuffer.bindMemory(to: UInt8.self).baseAddress,
                        32
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw PatchError.keyDerivationFailed }
        return output
    }

    private static func fingerprint(_ key: Data) -> Data {
        Data(SHA256.hash(data: key))
    }

    private static func keyAAD(for packageID: UUID, version: Int) -> Data {
        Data("3105PATCH/v\(version)/key/\(packageID.uuidString)".utf8)
    }

    private static func payloadAAD(for packageID: UUID, version: Int) -> Data {
        Data("3105PATCH/v\(version)/payload/\(packageID.uuidString)".utf8)
    }
}
