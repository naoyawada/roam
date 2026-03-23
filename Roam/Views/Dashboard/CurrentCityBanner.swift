import SwiftUI

struct CurrentCityBanner: View {
    let cityName: String
    let pingsToday: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Currently in")
                .font(.caption)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.7))
            Text(cityName)
                .font(.title)
                .fontWeight(.medium)
                .tracking(RoamTheme.headingTracking)
                .foregroundStyle(.white)
            Text("\(pingsToday) ping\(pingsToday == 1 ? "" : "s") today")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoamTheme.bannerBackground)
        .clipShape(RoundedRectangle(cornerRadius: RoamTheme.cornerRadius))
    }
}
