import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                Text("Dashboard")
            }
            Tab("Timeline", systemImage: "calendar") {
                Text("Timeline")
            }
            Tab("Insights", systemImage: "lightbulb.fill") {
                Text("Insights")
            }
        }
    }
}
