import SwiftUI

struct PetProfileView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: SPDesignSystem.Spacing.l) {
                // Hero image
                RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.2)).frame(height: 220)

                SPCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Buddy").font(SPDesignSystem.Typography.heading1())
                        Text("French Bulldog • 3 yrs • 22 lbs").foregroundColor(.secondary)
                    }
                }

                SPCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Medical & Care Info").font(.headline)
                        Text("No known allergies. Feed 1 cup twice daily. Avoid stairs due to joint sensitivity.")
                    }
                }

                SPCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emergency Contact").font(.headline)
                        HStack { Image(systemName: "phone.fill"); Text("(555) 010-1234") }
                        .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Gallery").font(SPDesignSystem.Typography.heading3())
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: SPDesignSystem.Spacing.m) {
                            ForEach(0..<8) { _ in RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2)).frame(width: 140, height: 100) }
                        }
                    }
                }

                SPButton(title: "Edit", kind: .ghost, systemImage: "pencil") {}
            }
            .padding()
        }
        .navigationTitle("Pet Profile")
    }
}



