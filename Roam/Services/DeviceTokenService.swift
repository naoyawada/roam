import Foundation
import UIKit
import Security
import os

enum DeviceTokenService {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "DeviceToken")

    private static let tokenKey = "apns_device_token"
    private static let keychainService = "com.naoyawada.roam"
    private static let keychainDeviceIDKey = "device_id"
    // Legacy UserDefaults key — used for migration
    private static let legacyDeviceIDKey = "roam_device_id"

    /// The current APNs token hex string, or nil if not yet registered.
    static var currentToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    /// Stable device identifier stored in Keychain (persists across reinstalls).
    static var deviceID: String {
        // Try Keychain first
        if let stored = readKeychain(key: keychainDeviceIDKey) {
            return stored
        }
        // Migrate from UserDefaults if present
        if let legacy = UserDefaults.standard.string(forKey: legacyDeviceIDKey) {
            writeKeychain(key: keychainDeviceIDKey, value: legacy)
            UserDefaults.standard.removeObject(forKey: legacyDeviceIDKey)
            return legacy
        }
        // Generate new
        let id = UUID().uuidString
        writeKeychain(key: keychainDeviceIDKey, value: id)
        return id
    }

    /// Seed the device ID with identifierForVendor if not already set.
    /// Must be called from MainActor (UIDevice.current is MainActor-isolated).
    @MainActor
    static func ensureDeviceID() {
        guard readKeychain(key: keychainDeviceIDKey) == nil else { return }
        // Migrate from UserDefaults if present
        if let legacy = UserDefaults.standard.string(forKey: legacyDeviceIDKey) {
            writeKeychain(key: keychainDeviceIDKey, value: legacy)
            UserDefaults.standard.removeObject(forKey: legacyDeviceIDKey)
            return
        }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        writeKeychain(key: keychainDeviceIDKey, value: id)
    }

    /// Called from AppDelegate when APNs registration succeeds.
    /// Converts the token to hex and upserts to Supabase.
    /// Schedule columns are omitted so that re-registration doesn't overwrite
    /// a user-configured schedule — `syncSchedule` is the sole owner of those fields.
    static func didRegister(tokenData: Data) {
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: tokenKey)
        logger.info("APNs token stored: \(hex.prefix(8))...")

        Task.detached(priority: .utility) {
            try? await SupabaseClient.insert(
                table: "device_tokens",
                body: [
                    "device_id": deviceID,
                    "token": hex,
                    "timezone": TimeZone.current.identifier,
                ],
                onConflict: "device_id"
            )
            logger.info("Device token upserted to Supabase")
        }
    }

    /// Sync updated capture schedule to Supabase.
    static func syncSchedule(primaryHour: Int, primaryMinute: Int, retryHour: Int, retryMinute: Int) {
        guard let token = currentToken else {
            logger.warning("syncSchedule: no APNs token yet, skipping")
            return
        }
        logger.info("syncSchedule: \(primaryHour):\(primaryMinute) / \(retryHour):\(retryMinute)")
        Task.detached(priority: .utility) {
            do {
                try await SupabaseClient.insert(
                    table: "device_tokens",
                    body: [
                        "device_id": deviceID,
                        "token": token,
                        "timezone": TimeZone.current.identifier,
                        "primary_hour": primaryHour,
                        "primary_minute": primaryMinute,
                        "retry_hour": retryHour,
                        "retry_minute": retryMinute,
                    ],
                    onConflict: "device_id"
                )
                logger.info("Schedule synced to Supabase")
            } catch {
                logger.error("syncSchedule failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Keychain helpers

    private static func readKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeKeychain(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        // Delete existing, then add
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
