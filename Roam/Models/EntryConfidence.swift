// Roam/Models/EntryConfidence.swift
import Foundation

enum EntryConfidence: String, Codable, CaseIterable {
    case high
    case medium
    case low

    static let highRaw = "high"
    static let mediumRaw = "medium"
    static let lowRaw = "low"
}
