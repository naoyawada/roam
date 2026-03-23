import SwiftUI

struct YearPicker: View {
    @Environment(\.colorTheme) private var colorTheme
    let years: [Int]
    @Binding var selectedYear: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(years, id: \.self) { year in
                    chipButton(label: String(year), isSelected: selectedYear == year) {
                        selectedYear = year
                    }
                }
            }
        }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? colorTheme.accent : RoamTheme.textSecondary)
                .background(isSelected ? colorTheme.accentLight : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? colorTheme.accentBorder : RoamTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
