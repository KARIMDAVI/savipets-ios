import SwiftUI
import FirebaseAuth
import FirebaseCore

struct AdminInquiryChatView: View {
    var initialText: String? = nil
    @EnvironmentObject var chat: ChatService
    @State private var selectedTab: Int = 0 // 0 = Clients, 1 = Sitters

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("User Type", selection: $selectedTab) {
                    Text("Clients").tag(0)
                    Text("Sitters").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    ForEach(filteredInquiries) { inquiry in
                        InquiryRow(inquiry: inquiry) {
                            Task { try? await chat.acceptInquiry(inquiry) }
                        }
                    }
                }
            }
            .navigationTitle("Inquiries")
            .onAppear { chat.listenToAdminInquiries() }
        }
    }

    private var filteredInquiries: [ChatInquiry] {
        let targetRole = selectedTab == 0 ? "petOwner" : "petSitter"
        return chat.inquiries.filter { $0.fromUserRole == targetRole }
    }
}

private struct InquiryRow: View {
    let inquiry: ChatInquiry
    let onAccept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(inquiry.subject)
                    .font(.headline)
                Spacer()
                Text(inquiry.fromUserRole)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }

            Text(inquiry.initialMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)

            if let createdAt = inquiry.createdAt {
                Text(createdAt.dateValue(), style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("Accept & Start Chat") { onAccept() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.vertical, 4)
    }
}
