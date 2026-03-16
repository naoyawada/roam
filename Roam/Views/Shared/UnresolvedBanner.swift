import SwiftUI
import SwiftData

struct UnresolvedBanner: View {
    let unresolvedCount: Int
    let onTap: () -> Void

    var body: some View {
        if unresolvedCount > 0 {
            Button(action: onTap) {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.yellow)
                    Text("\(unresolvedCount) night\(unresolvedCount == 1 ? "" : "s") need\(unresolvedCount == 1 ? "s" : "") your input")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}
