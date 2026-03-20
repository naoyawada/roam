import Foundation
import os

enum SupabaseClient {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "SupabaseClient")

    /// Insert a row into a Supabase table. Uses upsert when `onConflict` is provided.
    static func insert(table: String, body: [String: Any], onConflict: String? = nil) async throws {
        guard let url = URL(string: "\(SupabaseConfig.baseURL)/rest/v1/\(table)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(DeviceTokenService.deviceID, forHTTPHeaderField: "x-device-id")

        if let onConflict {
            request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            urlComponents.queryItems = [URLQueryItem(name: "on_conflict", value: onConflict)]
            request.url = urlComponents.url
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            logger.error("Supabase \(table) insert failed: HTTP \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
    }

    /// Insert with pre-serialized JSON body. Used by HeartbeatService to avoid
    /// crossing Sendable boundaries with [String: Any].
    static func insertRaw(table: String, body: Data) async throws {
        guard let url = URL(string: "\(SupabaseConfig.baseURL)/rest/v1/\(table)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(DeviceTokenService.deviceID, forHTTPHeaderField: "x-device-id")
        request.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            logger.error("Supabase \(table) insertRaw failed: HTTP \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
    }
}
