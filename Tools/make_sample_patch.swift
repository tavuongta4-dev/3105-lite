#!/usr/bin/env swift
// Tạo tệp .3105 schema v1 để thử nghiệm (chạy trên macOS có Swift).
//   swift Tools/make_sample_patch.swift /path/to/sample.3105
//   swift Tools/make_sample_patch.swift /path/to/locked.3105 "mat-khau"

import CommonCrypto
import CryptoKit
import Foundation
import Security

struct SampleRule: Codable {
    var id: UUID
    var bundleID: String
    var relativePath: String
    var replacementFilename: String
    var replacementData: Data
}

struct SampleDirectory: Codable {
    var id: UUID
    var bundleID: String
    var relativePath: String
}

struct SampleProject: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var bundleIdentifiers: [String]
    var directories: [SampleDirectory]
    var rules: [SampleRule]
}

struct SamplePayload: Codable {
    var project: SampleProject
    var replacementDigests: [String: Data]
}

struct SampleEnvelope: Codable {
    var schemaVersion: Int
    var keyAADVersion: Int?
    var packageID: UUID
    var isPasswordProtected: Bool
    var kdfSalt: Data?
    var kdfIterations: Int?
    var wrappedContentKey: Data?
    var publicContentKey: Data?
    var keyFingerprint: Data
    var encryptedPayload: Data
}

func randomData(_ count: Int) -> Data {
    var data = Data(count: count)
    _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
    return data
}

func deriveKey(password: String, salt: Data, iterations: Int) -> Data {
    let passwordData = Data(password.utf8)
    var output = Data(count: 32)
    _ = output.withUnsafeMutableBytes { outputBuffer in
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
    return output
}

func seal(_ plaintext: Data, key: Data, aad: Data) throws -> Data {
    let box = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), authenticating: aad)
    guard let combined = box.combined else { fatalError("no combined") }
    return combined
}

func keyAAD(id: UUID) -> Data { Data("3105PATCH/v1/key/\(id.uuidString)".utf8) }
func payloadAAD(id: UUID) -> Data { Data("3105PATCH/v1/payload/\(id.uuidString)".utf8) }

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: swift make_sample_patch.swift <output.3105> [password]")
    exit(1)
}
let outputPath = args[1]
let password = args.count >= 3 ? args[2] : ""
let protected = !password.isEmpty
let iterations = 250_000

let rule = SampleRule(
    id: UUID(),
    bundleID: "com.example.demoapp",
    relativePath: "Documents",
    replacementFilename: "config.json",
    replacementData: Data(#"{"theme":"dark","sample":true}"#.utf8)
)
let project = SampleProject(
    id: UUID(),
    name: "Sample v1 patch",
    createdAt: Date(),
    updatedAt: Date(),
    bundleIdentifiers: ["com.example.demoapp"],
    directories: [],
    rules: [rule]
)

let digests = [rule.id.uuidString: Data(SHA256.hash(data: rule.replacementData))]
let payload = SamplePayload(project: project, replacementDigests: digests)
let encoder = PropertyListEncoder()
encoder.outputFormat = .binary
let payloadData = try encoder.encode(payload)

let contentKey = randomData(32)
let encryptedPayload = try seal(payloadData, key: contentKey, aad: payloadAAD(id: project.id))

let salt: Data? = protected ? randomData(16) : nil
let wrappedKey: Data? = protected
    ? try seal(contentKey, key: deriveKey(password: password, salt: salt!, iterations: iterations), aad: keyAAD(id: project.id))
    : nil

let envelope = SampleEnvelope(
    schemaVersion: 1,
    keyAADVersion: nil,
    packageID: project.id,
    isPasswordProtected: protected,
    kdfSalt: salt,
    kdfIterations: protected ? iterations : nil,
    wrappedContentKey: wrappedKey,
    publicContentKey: protected ? nil : contentKey,
    keyFingerprint: Data(SHA256.hash(data: contentKey)),
    encryptedPayload: encryptedPayload
)

var output = Data("3105PATCH\0".utf8)
output.append(try encoder.encode(envelope))
try output.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
print("Created \(outputPath) (v1, \(protected ? "password protected" : "no password"))")
