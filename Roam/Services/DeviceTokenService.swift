import Foundation
import UIKit
import os

enum DeviceTokenService {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "DeviceToken")

    private static let tokenKey = "apns_device_token"
    private static let deviceIDKey = "roam_device_id"

    /// The current APNs token hex string, or nil if not yet registered.
    static var currentToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    /// Stable device identifier. Reads from UserDefaults; falls back to a stored UUID.
    /// Call `ensureDeviceID()` from MainActor at launch to seed with identifierForVendor.
    static var deviceID: String {
        if let stored = UserDefaults.standard.string(forKey: deviceIDKey) {
            return stored
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceIDKey)
        return id
    }

    /// Seed the device ID with identifierForVendor if not already set.
    /// Must be called from MainActor (UIDevice.current is MainActor-isolated).
    @MainActor
    static func ensureDeviceID() {
        guard UserDefaults.standard.string(forKey: deviceIDKey) == nil else { return }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceIDKey)
    }

    /// Called from AppDelegate when APNs registration succeeds.
    /// Converts the token to hex and upserts to Supabase.
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
}
