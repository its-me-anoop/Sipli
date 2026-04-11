import SwiftUI

/// Evergreen info screen explaining why the refill habit matters. Reached from
/// Settings → About. Not gated by Earth Week — stays available year-round as
/// educational context for Sipli's sustainability story.
struct EarthInfoView: View {
    private struct Fact: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let icon: String
    }

    private let facts: [Fact] = [
        Fact(
            title: "Tap water works",
            body: "In most places with modern water infrastructure, tap water is safely drinkable and already regulated for quality. A reusable bottle filled from the tap hydrates you just as well as anything sold in plastic.",
            icon: "drop.fill"
        ),
        Fact(
            title: "Single-use plastic is slow to leave",
            body: "A plastic bottle is used for minutes but lingers for decades. The simplest way to reduce plastic waste is not to create it in the first place.",
            icon: "hourglass"
        ),
        Fact(
            title: "A habit beats a one-off",
            body: "Consistently using a reusable bottle for a year quietly avoids hundreds of single-use ones. The trick is making the refill feel automatic — which is exactly what a tracking habit is for.",
            icon: "repeat"
        ),
        Fact(
            title: "Hydration is personal",
            body: "Your ideal intake changes with your weight, activity, and the weather. A bottle you can refill anywhere is the most flexible way to meet that moving target.",
            icon: "figure.walk"
        ),
        Fact(
            title: "Small, honest wins",
            body: "Sipli doesn't calculate how many bottles you've saved. It just helps you notice each sip — and noticing is usually what makes a habit stick.",
            icon: "sparkles"
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero

                VStack(spacing: 14) {
                    ForEach(facts) { fact in
                        factCard(fact)
                    }
                }
                .padding(.horizontal, 16)

                Text("Sipli doesn't count bottles for you — we just help you build the refill habit.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
        }
        .background { AppWaterBackground().ignoresSafeArea() }
        .navigationTitle("Why Reusable Bottles")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.62, blue: 0.42),
                                Color(red: 0.05, green: 0.45, blue: 0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
            .padding(.top, 20)

            Text("Every sip, less plastic.")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)

            Text("A quiet love letter to reusable bottles — and the habit that makes them stick.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private func factCard(_ fact: Fact) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.22, green: 0.62, blue: 0.42).opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: fact.icon)
                    .foregroundStyle(Color(red: 0.22, green: 0.62, blue: 0.42))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(fact.title)
                    .font(.subheadline.weight(.semibold))
                Text(fact.body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.card)
        )
        .shadow(color: Theme.shadowColor.opacity(0.4), radius: 6, x: 0, y: 3)
    }
}

#if DEBUG
#Preview("Earth Info") {
    NavigationStack {
        EarthInfoView()
    }
}
#endif
