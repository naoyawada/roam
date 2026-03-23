import SwiftUI

struct ConfidenceBanner: View {
    let lowConfidenceCount: Int
    let onTap: () -> Void

    var body: some View {
        if lowConfidenceCount > 0 {
            Button(action: onTap) {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(RoamTheme.accent)
                    Text("\(lowConfidenceCount) night\(lowConfidenceCount == 1 ? "" : "s") need\(lowConfidenceCount == 1 ? "s" : "") review")
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
