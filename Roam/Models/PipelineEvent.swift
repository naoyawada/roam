// Roam/Models/PipelineEvent.swift
import Foundation
import SwiftData

@Model
final class PipelineEvent {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var category: String = ""
    var event: String = ""
    var detail: String = ""
    var metadata: String = "{}"
    var appState: String = "foreground"
    var rawVisitID: UUID? = nil
    var dailyEntryID: UUID? = nil

    init() {}

    init(category: String, event: String, detail: String = "", metadata: String = "{}",
         appState: String = "foreground", rawVisitID: UUID? = nil, dailyEntryID: UUID? = nil) {
        self.category = category
        self.event = event
        self.detail = detail
        self.metadata = metadata
        self.appState = appState
        self.rawVisitID = rawVisitID
        self.dailyEntryID = dailyEntryID
    }
}
