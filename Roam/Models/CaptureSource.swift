import Foundation

enum CaptureSource: String, Codable, Equatable {
    case automatic
    case manual

    static let automaticRaw = "automatic"
    static let manualRaw = "manual"
}
