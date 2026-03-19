import SwiftUI

struct CustomTabBar: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            tabButton(title: "Dashboard", icon: "chart.bar.fill", index: 0)
            tabButton(title: "Timeline", icon: "calendar", index: 1)
            tabButton(title: "Insights", icon: "lightbulb.fill", index: 2)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 48)
        .padding(.bottom, 4)
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.3)) {
                selection = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .fontWeight(selection == index ? .semibold : .regular)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selection == index ? RoamTheme.accent : .secondary)
        }
    }
}
