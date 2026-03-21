import SwiftUI

struct CityMapItem: Identifiable {
    let id: String  // cityKey
    let displayName: String
    let latitude: Double
    let longitude: Double
    let totalNights: Int
    let firstVisit: Date
    let lastVisit: Date
    let color: Color
}

struct CityPinAnnotation: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.4), radius: 2, y: 1)
    }
}
