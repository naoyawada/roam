import SwiftUI

struct UnresolvedBanner: View {
    let unresolvedCount: Int
    let onTap: () -> Void

    var body: some View {
        if unresolvedCount > 0 {
            Button(action: onTap) {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(RoamTheme.accent)
                    Text("\(unresolvedCount) night\(unresolvedCount == 1 ? "" : "s") need\(unresolvedCount == 1 ? "s" : "") your input")
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(RoamTheme.textTertiary)
                }
                .padding()
                .background(RoamTheme.accentLight)
                .clipShape(RoundedRectangle(cornerRadius: RoamTheme.cornerRadiusSmall))
            }
            .buttonStyle(.plain)
        }
    }
}
