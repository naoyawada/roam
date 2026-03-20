import Foundation
import os

enum HeartbeatEvent: String, Sendable {
    case pushReceived = "push_received"
    case bgTaskFired = "bg_task_fired"
    case locationCaptured = "location_captured"
    case locationFailed = "location_failed"
    case appForegrounded = "app_foregrounded"
}

enum HeartbeatService {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "Heartbeat")

    /// Fire-and-forget heartbeat log. Never blocks the caller.
    static func log(_ event: HeartbeatEvent, payload: [String: Sendable]? = nil) {
        let deviceID = DeviceTokenService.deviceID
        // Build the full body and serialize to Data on the calling thread
        // so nothing non-Sendable crosses the task boundary.
        var body: [String: Any] = [
            "device_id": deviceID,
            "event": event.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]
        if let payload {
            body["payload"] = payload
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        Task.detached(priority: .utility) {
            try? await SupabaseClient.insertRaw(table: "device_heartbeat", body: jsonData)
            logger.info("Heartbeat logged: \(event.rawValue)")
        }
    }
}
