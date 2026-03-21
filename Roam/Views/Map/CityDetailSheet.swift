import SwiftUI

struct CityDetailSheet: View {
    let item: CityMapItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.color)
                    .frame(width: 10, height: 10)
                Text(item.displayName)
                    .font(.headline)
                    .foregroundStyle(RoamTheme.textPrimary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nights")
                        .font(.caption)
                        .foregroundStyle(RoamTheme.textSecondary)
                    Text("\(item.totalNights)")
                        .font(.title2)
                        .fontWeight(.regular)
                        .foregroundStyle(RoamTheme.textPrimary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("First visit")
                        .font(.caption)
                        .foregroundStyle(RoamTheme.textSecondary)
                    Text(item.firstVisit.formatted(.dateTime.month(.wide).day().year()))
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textPrimary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last visit")
                        .font(.caption)
                        .foregroundStyle(RoamTheme.textSecondary)
                    Text(item.lastVisit.formatted(.dateTime.month(.wide).day().year()))
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textPrimary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoamTheme.background)
    }
}
