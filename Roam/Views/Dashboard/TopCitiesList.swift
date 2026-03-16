import SwiftUI

struct TopCitiesList: View {
    let cities: [(name: String, nights: Int, percentage: Double, color: Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Top Cities")
                .fontWeight(.semibold)
                .padding(.bottom, 12)

            ForEach(Array(cities.enumerated()), id: \.offset) { _, city in
                HStack {
                    Circle()
                        .fill(city.color)
                        .frame(width: 10, height: 10)
                    Text(city.name)
                    Spacer()
                    Text("\(city.nights) nights")
                        .fontWeight(.semibold)
                    Text("\(Int(city.percentage * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.vertical, 8)
                if city.name != cities.last?.name {
                    Divider()
                }
            }
        }
    }
}
