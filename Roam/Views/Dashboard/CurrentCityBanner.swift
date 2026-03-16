import SwiftUI

struct CurrentCityBanner: View {
    let cityName: String
    let streakDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Currently in")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(cityName)
                .font(.title)
                .fontWeight(.bold)
            Text("Day \(streakDays) of current streak")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
