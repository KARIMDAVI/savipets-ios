import SwiftUI

struct LiveUpdatesView: View {
    @State private var isLive: Bool = true
    var body: some View {
        ScrollView {
            VStack(spacing: SPDesignSystem.Spacing.l) {
                status
                map
                photos
                tasks
                messaging
                summary
            }
            .padding()
        }
        .navigationTitle("Live Updates")
    }

    private var status: some View {
        SPCard {
            HStack {
                Circle().fill(isLive ? SPDesignSystem.Colors.success : .gray).frame(width: 12, height: 12)
                Text(isLive ? "In Progress" : "Completed")
                Spacer()
                Text("Started 3m ago").foregroundColor(.secondary)
            }
        }
    }

    private var map: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Map").font(.headline)
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2)).frame(height: 200)
            }
        }
    }

    private var photos: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photo Feed").font(SPDesignSystem.Typography.heading3())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SPDesignSystem.Spacing.m) {
                    ForEach(0..<6) { _ in RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2)).frame(width: 140, height: 100) }
                }
            }
        }
    }

    private var tasks: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tasks").font(.headline)
                ForEach(["Fresh water", "Meal", "Walk", "Play"], id: \.self) { task in HStack { Image(systemName: "checkmark.circle.fill"); Text(task) } }
            }
        }
    }

    private var messaging: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Messaging").font(.headline)
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)).frame(height: 100)
                SPButton(title: "Send Message", kind: .secondary, systemImage: "paperplane.fill") {}
            }
        }
    }

    private var summary: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Visit Summary").font(.headline)
                Text("30 minute walk completed. Buddy had 1 potty break and drank water.")
            }
        }
    }
}




