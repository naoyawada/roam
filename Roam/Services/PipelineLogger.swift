// Roam/Services/PipelineLogger.swift
import Foundation
import SwiftData
import UIKit
import os

@ModelActor
actor PipelineLogger {
    private static let osLog = Logger(subsystem: "com.naoyawada.roam", category: "Pipeline")

    func log(
        category: String,
        event: String,
        detail: String = "",
        metadata: [String: String] = [:],
        appState: String? = nil,
        rawVisitID: UUID? = nil,
        dailyEntryID: UUID? = nil
    ) {
        let resolvedState = appState ?? Self.currentAppState()
        let entry = PipelineEvent(
            category: category,
            event: event,
            detail: detail,
            metadata: Self.encodeMetadata(metadata),
            appState: resolvedState,
            rawVisitID: rawVisitID,
            dailyEntryID: dailyEntryID
        )
        modelContext.insert(entry)
        try? modelContext.save()

        Self.osLog.info("[\(category)] \(event) — \(detail)")
    }

    func pruneOldEvents(olderThan days: Int = 7) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let descriptor = FetchDescriptor<PipelineEvent>(
            predicate: #Predicate<PipelineEvent> { $0.timestamp < cutoff }
        )
        if let old = try? modelContext.fetch(descriptor) {
            for event in old {
                modelContext.delete(event)
            }
            try? modelContext.save()
        }
    }

    private static func currentAppState() -> String {
        if Thread.isMainThread {
            switch UIApplication.shared.applicationState {
            case .active: return "foreground"
            case .background: return "background"
            case .inactive: return "foreground"
            @unknown default: return "foreground"
            }
        }
        return "background"
    }

    private static func encodeMetadata(_ metadata: [String: String]) -> String {
        guard !metadata.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: metadata),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
