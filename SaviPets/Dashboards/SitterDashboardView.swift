import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

private struct VisitItem: Identifiable {
	let id: String
	let start: Date
	let end: Date
	let clientName: String
	let address: String
	let note: String
	let serviceSummary: String
	let petName: String
}

struct SitterDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
	@State private var selectedDay: Date = Date()
	@State private var visits: [VisitItem] = []

	private var sitterUid: String? { Auth.auth().currentUser?.uid }
	private var isToday: Bool { Calendar.current.isDate(selectedDay, inSameDayAs: Date()) }

	var body: some View {
        TabView {
			Home
				.tabItem { Label("Home", systemImage: "house.fill") }
			Text("Calendar")
				.tabItem { Label("Calendar", systemImage: "calendar") }
			Text("Active")
				.tabItem { Label("Active", systemImage: "figure.walk") }
			SitterMessagesTab()
				.tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
            SitterProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
		}
        .tint(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
	}

	private var Home: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: SPDesignSystem.Spacing.l) {
					header
					weekStrip
					todaysSchedule
					recentPhotos
				}
				.padding()
			}
			.navigationTitle("Today")
			.onAppear { loadVisits() }
			.onChange(of: selectedDay) { _ in loadVisits() }
		}
	}

	private var header: some View {
		HStack {
			VStack(alignment: .leading) {
				Text(Date.now, style: .date).font(.subheadline).foregroundColor(.secondary)
				Text("Your schedule")
					.font(SPDesignSystem.Typography.heading1())
			}
			Spacer()
			Image(systemName: "bell").font(.title2)
		}
	}

	private var todaysSchedule: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(isToday ? "Today's Schedule" : selectedDay.formatted(date: .complete, time: .omitted))
				.font(SPDesignSystem.Typography.heading3())
			ForEach(visits) { visit in
				VisitCard(visit: visit)
			}
		}
	}

	// Removed earnings and start visit quick action per requirements

	private var recentPhotos: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Recent Photos").font(SPDesignSystem.Typography.heading3())
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: SPDesignSystem.Spacing.m) {
					ForEach(0..<6) { _ in RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2)).frame(width: 120, height: 120) }
				}
			}
		}
	}

	// MARK: - Data loading
	private func loadVisits() {
		guard let sitterUid else { visits = []; return }
		let db = Firestore.firestore()
		let cal = Calendar.current
		let dayStart = cal.startOfDay(for: selectedDay)
		let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? selectedDay

		// Replace with your actual schema fields
		db.collection("visits")
			.whereField("sitterId", isEqualTo: sitterUid)
			.whereField("scheduledStart", isGreaterThanOrEqualTo: Timestamp(date: dayStart))
			.whereField("scheduledStart", isLessThan: Timestamp(date: dayEnd))
			.order(by: "scheduledStart")
			.getDocuments { snap, err in
				guard err == nil, let snap else { self.visits = []; return }
				var items: [VisitItem] = []
				for d in snap.documents {
					let data = d.data()
					let start = (data["scheduledStart"] as? Timestamp)?.dateValue() ?? dayStart
					let end = (data["scheduledEnd"] as? Timestamp)?.dateValue() ?? start
					let clientName = data["clientName"] as? String ?? ""
					let address = data["address"] as? String ?? ""
					let note = data["note"] as? String ?? ""
					let service = data["serviceSummary"] as? String ?? ""
					let pets = (data["pets"] as? [String])?.joined(separator: ", ") ?? (data["petName"] as? String ?? "")
					items.append(VisitItem(id: d.documentID, start: start, end: end, clientName: clientName, address: address, note: note, serviceSummary: service, petName: pets))
				}
				self.visits = items.sorted { $0.start < $1.start }
			}
	}
}

private struct SitterMessagesTab: View {
    @EnvironmentObject var chat: ChatService
    @State private var selectedConversationId: String? = nil
    @State private var input: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Conversations") {
                    ForEach(chat.conversations) { convo in
                        Button(action: { selectedConversationId = convo.id }) {
                            VStack(alignment: .leading) {
                                Text(convo.participants.joined(separator: ", "))
                                    .font(.headline)
                                Text(convo.lastMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .onAppear { chat.listenToMyConversations() }
            .sheet(item: Binding(get: {
                selectedConversationId.map { ChatSheetId(id: $0) }
            }, set: { v in selectedConversationId = v?.id })) { item in
                ConversationChatView(conversationId: item.id)
                    .environmentObject(chat)
            }
        }
    }
}

#if DEBUG
    struct SitterDashboardView_Previews: PreviewProvider {
        static var previews: some View {
            SitterDashboardView()
                .previewDisplayName("Sitter Dashboard")
        }
    }
#endif

private struct VisitCard: View {
	let visit: VisitItem
	@State private var started: Bool = false
	@State private var startTime: Date? = nil
	@State private var tick: Date = Date()
	@State private var showDraft: Bool = false
	@State private var draftText: String = ""
	@State private var showCompleteConfirm: Bool = false
	@State private var isCompleted: Bool = false

	private var timeRange: String {
		let df = DateFormatter(); df.dateFormat = "h:mm a"
		return "\(df.string(from: visit.start)) - \(df.string(from: visit.end))"
	}

	private var timeLeftString: String {
		guard let _ = startTime else { return "" }
		// Count down from planned end time (ticks via timer)
		let remaining = max(visit.end.timeIntervalSince(tick), 0)
		let mins = Int(remaining) / 60
		let secs = Int(remaining) % 60
		return String(format: "%dm %02ds", mins, secs)
	}

	var body: some View {
		SPCard {
			VStack(alignment: .leading, spacing: 12) {
				// Time range
				HStack {
					Text(timeRange)
						.font(.headline)
					Spacer()
					Button(action: openInMaps) {
						Image(systemName: "paperplane")
					}
					.foregroundColor(.secondary)
				}

				// Client & address
				VStack(alignment: .leading, spacing: 6) {
					Text(visit.clientName).font(.title3).bold()
					Text(visit.address)
						.foregroundColor(.secondary)
				}

				// Note
				VStack(alignment: .leading, spacing: 4) {
					Text("Event Note").bold()
					Text(visit.note)
				}

				// Services & pet
				VStack(alignment: .leading, spacing: 4) {
					Text("Services: \(visit.serviceSummary)")
						.bold()
						.foregroundColor(.secondary)
					Text("Pets: \(visit.petName)")
						.foregroundColor(.blue)
				}

				// Timer row (only after start)
				if started, let startTime {
					HStack {
						VStack(alignment: .leading) {
							Text("START").foregroundColor(.red).bold()
							Text(startTime, style: .time)
						}
						Spacer()
						VStack(alignment: .trailing) {
							Text("TIME LEFT").foregroundColor(.red).bold()
							Text(timeLeftString)
						}
					}
				}

				// Actions
				HStack {
					Button(action: { showDraft = true }) {
						Label("Draft Message", systemImage: "square.and.pencil")
					}
					.buttonStyle(GhostButtonStyle())

					Spacer()

					if started {
						Button(action: { started = false; startTime = nil }) {
							Text("Undo Start")
						}
						.buttonStyle(GhostButtonStyle())
					}
				}

				HStack {
					Button(action: {
						if !started { startVisit() }
					}) {
						Label(started ? "Timer Running" : "Start Timer", systemImage: started ? "clock" : "play.circle")
					}
					.buttonStyle(PrimaryButtonStyle())

					Spacer()

					Button(action: { showCompleteConfirm = true }) {
						Text("End Visit")
					}
					.buttonStyle(GhostButtonStyle())
				}
				.onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
					if started { tick = now }
				}
				.alert("Complete Visit?", isPresented: $showCompleteConfirm) {
					Button("Yes, Complete") { completeVisit() }
					Button("Back", role: .cancel) {}
				} message: {
					Text("you're about to mark this event as complete. Are you sure?")
				}
			}
			.overlay(
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.stroke(isCompleted ? SPDesignSystem.Colors.success : Color.clear, lineWidth: 2)
			)
		}
		.sheet(isPresented: $showDraft) {
			NavigationStack {
				VStack(alignment: .leading, spacing: 12) {
					Text("Draft message to client").font(.headline)
					TextEditor(text: $draftText)
						.frame(minHeight: 160)
						.overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
					Spacer()
				}
				.padding()
				.navigationTitle("Draft Message")
				.toolbar {
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") { showDraft = false }
					}
					ToolbarItem(placement: .cancellationAction) {
						Button("Cancel") { showDraft = false }
					}
				}
			}
		}
	}

	private func openInMaps() {
		// Try opening client address in Apple Maps
		let encoded = visit.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
		if let url = URL(string: "http://maps.apple.com/?daddr=\(encoded)") {
			UIApplication.shared.open(url)
		}
	}

	private func startVisit() {
		startTime = Date(); started = true
		let db = Firestore.firestore()
		db.collection("visits").document(visit.id).setData([
			"status": "in_progress",
			"timeline.checkIn.timestamp": FieldValue.serverTimestamp()
		], merge: true)
	}

	private func completeVisit() {
		let db = Firestore.firestore()
		var update: [String: Any] = [
			"status": "completed",
			"timeline.checkOut.timestamp": FieldValue.serverTimestamp()
		]
		if !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			update["pendingMessage"] = [
				"text": draftText,
				"status": "pending_admin",
				"createdAt": FieldValue.serverTimestamp()
			]
		}
		db.collection("visits").document(visit.id).setData(update, merge: true)
		isCompleted = true
		started = false
		startTime = nil
		showCompleteConfirm = false
	}
}

private extension SitterDashboardView {
	var weekStrip: some View {
		// Simple 7‑day strip around selectedDay
		let cal = Calendar.current
		let start = cal.date(byAdding: .day, value: -3, to: selectedDay)!
		let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
		return ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 16) {
				Button(action: { selectedDay = cal.date(byAdding: .day, value: -1, to: selectedDay)! }) { Image(systemName: "chevron.left") }
				ForEach(days, id: \.self) { day in
					let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
					VStack {
						Text(day, format: .dateTime.weekday(.abbreviated))
						ZStack {
                                Circle().fill(isSelected ? SPDesignSystem.Colors.primaryAdjusted(colorScheme) : Color.gray.opacity(0.15))
								.frame(width: 56, height: 56)
							Text(day, format: .dateTime.day())
								.foregroundColor(isSelected ? .black : .primary)
						}
					}
					.onTapGesture { selectedDay = day }
				}
				Button(action: { selectedDay = cal.date(byAdding: .day, value: 1, to: selectedDay)! }) { Image(systemName: "chevron.right") }
			}
			.padding(.vertical, 4)
		}
	}
}
