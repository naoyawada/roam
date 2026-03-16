import Foundation

enum LogStatus: String, Codable, Equatable {
    case confirmed
    case unresolved
    case manual

    static let confirmedRaw = "confirmed"
    static let unresolvedRaw = "unresolved"
    static let manualRaw = "manual"
}
