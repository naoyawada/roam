// Roam/Services/PipelineLogger.swift
import Foundation
import SwiftData
import os

@ModelActor
actor PipelineLogger {
    private static let osLog = Logger(subsystem: "com.naoyawada.roam", category: "Pipeline")

    func log(
        category: String,
        event: String,
        detail: String = "",
        metadata: [String: String] = [:],
        appState: String = "foreground",
        rawVisitID: UUID? = nil,
        dailyEntryID: UUID? = nil
    ) {
        let entry = PipelineEvent(
            category: category,
            event: event,
            detail: detail,
            metadata: Self.encodeMetadata(metadata),
            appState: appState,
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

    private static func encodeMetadata(_ metadata: [String: String]) -> String {
        guard !metadata.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: metadata),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
