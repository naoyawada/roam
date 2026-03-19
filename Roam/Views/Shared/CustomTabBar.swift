import SwiftUI

struct CustomTabBar: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            tabButton(title: "Dashboard", icon: "chart.bar.fill", index: 0)
            tabButton(title: "Timeline", icon: "calendar", index: 1)
            tabButton(title: "Insights", icon: "lightbulb.fill", index: 2)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .glassEffect(.regular)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.3)) {
                selection = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selection == index ? RoamTheme.accent : .secondary)
        }
    }
}
