// Roam/Models/EntrySource.swift
import Foundation

enum EntrySource: String, Codable, CaseIterable {
    case visit
    case manual
    case propagated
    case fallback
    case migrated
    case debug

    static let visitRaw = "visit"
    static let manualRaw = "manual"
    static let propagatedRaw = "propagated"
    static let fallbackRaw = "fallback"
    static let migratedRaw = "migrated"
    static let debugRaw = "debug"
}
