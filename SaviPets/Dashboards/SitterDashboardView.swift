import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine
import CoreLocation

private struct VisitItem: Identifiable {
    let id: String
    let start: Date
    let end: Date
    let clientName: String
    let address: String
    let note: String
    let serviceSummary: String
    let petName: String
    let petPhotoURL: String?
    let status: String
    let checkIn: Date?
    let checkOut: Date?
}

private struct DailyActiveHours: Identifiable {
    let id = UUID()
    let date: Date
    let sitterName: String
    let sitterId: String
    let firstVisitStart: Date?
    let lastVisitEnd: Date?
    let totalActiveHours: Double
    let visitCount: Int
}

private struct RecentPetPhoto: Identifiable {
    let id = UUID()
    let url: String
    let petName: String
    let visitDate: Date
}

private enum DateRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
}

struct SitterDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
	@State private var selectedDay: Date = Date()
	@State private var visits: [VisitItem] = []
    @StateObject private var serviceBookings = ServiceBookingDataService()
	@State private var expandedCards: Set<String> = [] // Track which cards are expanded
	
	// Active hours tracking
	@State private var dailyActiveHours: [DailyActiveHours] = []
	@State private var selectedDateRange: DateRange = .week
	@State private var isLoadingActiveHours: Bool = false
	
	// Recent pets tracking
	@State private var recentPetPhotos: [RecentPetPhoto] = []

	private var sitterUid: String? { Auth.auth().currentUser?.uid }
	private var isToday: Bool { Calendar.current.isDate(selectedDay, inSameDayAs: Date()) }

    @State private var selectedTab: Int = 0
    @State private var navigateToMessages: Bool = false
    @State private var selectedClientForMessage: String? = nil
    @State private var showNotificationsView: Bool = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Home
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(0)
            ActiveHoursView
                .tabItem { Label("Active", systemImage: "figure.walk") }
                .tag(1)
            SitterMessagesTab(selectedClientName: selectedClientForMessage)
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(2)
            SitterProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .tint(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
        .onChange(of: navigateToMessages) { shouldNavigate in
            if shouldNavigate {
                selectedTab = 2 // Switch to Messages tab
                navigateToMessages = false
                // Reset the selected client after a delay to allow the Messages tab to process it
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    selectedClientForMessage = nil
                }
            }
        }
        .sheet(isPresented: $showNotificationsView) {
            NotificationsView()
        }
    }

	private var Home: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: SPDesignSystem.Spacing.l) {
					header
					weekStrip
					jumpToTodayButton
					todaysSchedule
					recentPets
				}
				.padding()
			}
            .navigationTitle("Schedule")
            .onAppear { 
                loadVisitsRealtime()
                serviceBookings.listenToPendingBookings()
                loadRecentPetPhotos()
            }
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
			Button(action: {
				showNotificationsView = true
			}) {
				Image(systemName: "bell")
					.font(.title2)
					.foregroundColor(.primary)
			}
			.buttonStyle(PlainButtonStyle())
		}
	}
	
	private var jumpToTodayButton: some View {
		Button(action: {
			withAnimation(.easeInOut(duration: 0.3)) {
				selectedDay = Calendar.current.startOfDay(for: Date())
			}
		}) {
			Text("Jump to today")
				.font(.subheadline)
				.foregroundColor(.blue)
				.padding(.vertical, 8)
				.padding(.horizontal, 16)
				.background(
					RoundedRectangle(cornerRadius: 8)
						.fill(Color.blue.opacity(0.1))
				)
		}
		.buttonStyle(PlainButtonStyle())
	}

	private var todaysSchedule: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(isToday ? "Today's Schedule" : selectedDay.formatted(date: .complete, time: .omitted))
				.font(SPDesignSystem.Typography.heading3())
			ForEach(visits) { visit in
				VisitCard(
					visit: visit,
					isExpanded: Binding(
						get: { expandedCards.contains(visit.id) },
						set: { isExpanded in
							if isExpanded {
								expandedCards.insert(visit.id)
							} else {
								expandedCards.remove(visit.id)
							}
						}
					),
					navigateToMessages: $navigateToMessages,
					selectedClientForMessage: $selectedClientForMessage
				)
			}
		}
	}

	// Removed earnings and start visit quick action per requirements

	private var recentPets: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Recent Pets").font(SPDesignSystem.Typography.heading3())
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: SPDesignSystem.Spacing.m) {
					ForEach(recentPetPhotos, id: \.url) { petPhoto in
						AsyncImage(url: URL(string: petPhoto.url)) { phase in
							switch phase {
							case .success(let image):
								image
									.resizable()
									.aspectRatio(contentMode: .fill)
									.frame(width: 120, height: 120)
									.clipped()
							case .empty:
								RoundedRectangle(cornerRadius: 12)
									.fill(Color.gray.opacity(0.2))
									.frame(width: 120, height: 120)
									.overlay(
										ProgressView()
									)
							case .failure(_):
								RoundedRectangle(cornerRadius: 12)
									.fill(Color.gray.opacity(0.2))
									.frame(width: 120, height: 120)
									.overlay(
										Image(systemName: "pawprint.fill")
											.foregroundColor(.gray)
									)
							@unknown default:
								RoundedRectangle(cornerRadius: 12)
									.fill(Color.gray.opacity(0.2))
									.frame(width: 120, height: 120)
							}
						}
						.clipShape(RoundedRectangle(cornerRadius: 12))
						.overlay(
							VStack {
								Spacer()
								Text(petPhoto.petName)
									.font(.caption)
									.fontWeight(.medium)
									.foregroundColor(.white)
									.padding(.horizontal, 8)
									.padding(.vertical, 4)
									.background(
										RoundedRectangle(cornerRadius: 6)
											.fill(Color.black.opacity(0.7))
									)
									.padding(.bottom, 8)
							}
						)
					}
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
                    let firstPhoto = (data["petPhotoURLs"] as? [String])?.first
                    let status = data["status"] as? String ?? "scheduled"
                    let checkIn = ((data["timeline"] as? [String: Any])?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp
                    let checkOut = ((data["timeline"] as? [String: Any])?["checkOut"] as? [String: Any])?["timestamp"] as? Timestamp
                    items.append(VisitItem(id: d.documentID, start: start, end: end, clientName: clientName, address: address, note: note, serviceSummary: service, petName: pets, petPhotoURL: firstPhoto, status: status, checkIn: checkIn?.dateValue(), checkOut: checkOut?.dateValue()))
				}
				self.visits = items.sorted { $0.start < $1.start }
			}
	}

    private func loadVisitsRealtime() {
        guard let sitterUid else { visits = []; return }
        let db = Firestore.firestore()
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: selectedDay)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? selectedDay
        db.collection("visits")
            .whereField("sitterId", isEqualTo: sitterUid)
            .whereField("scheduledStart", isGreaterThanOrEqualTo: Timestamp(date: dayStart))
            .whereField("scheduledStart", isLessThan: Timestamp(date: dayEnd))
            .order(by: "scheduledStart")
            .addSnapshotListener { snap, err in
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
                    let firstPhoto = (data["petPhotoURLs"] as? [String])?.first
                    let status = data["status"] as? String ?? "scheduled"
                    let checkIn = ((data["timeline"] as? [String: Any])?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp
                    let checkOut = ((data["timeline"] as? [String: Any])?["checkOut"] as? [String: Any])?["timestamp"] as? Timestamp
                    items.append(VisitItem(id: d.documentID, start: start, end: end, clientName: clientName, address: address, note: note, serviceSummary: service, petName: pets, petPhotoURL: firstPhoto, status: status, checkIn: checkIn?.dateValue(), checkOut: checkOut?.dateValue()))
                }
                self.visits = items.sorted { $0.start < $1.start }
		}
	}
    
    // MARK: - Recent Pet Photos Loading
    private func loadRecentPetPhotos() {
        guard let sitterUid else { 
            recentPetPhotos = []
            return 
        }
        
        let db = Firestore.firestore()
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        // Get recent completed visits from the last week
        db.collection("visits")
            .whereField("sitterId", isEqualTo: sitterUid)
            .whereField("status", isEqualTo: "completed")
            .whereField("scheduledStart", isGreaterThanOrEqualTo: Timestamp(date: weekAgo))
            .order(by: "scheduledStart", descending: true)
            .limit(to: 20) // Get more visits to ensure we have enough unique pets
            .getDocuments { [self] snapshot, error in
                guard error == nil, let snapshot = snapshot else {
                    self.recentPetPhotos = []
                    return
                }
                
                var uniquePets: [String: RecentPetPhoto] = [:]
                
                for document in snapshot.documents {
                    let data = document.data()
                    let visitDate = (data["scheduledStart"] as? Timestamp)?.dateValue() ?? Date()
                    let petName = (data["pets"] as? [String])?.first ?? (data["petName"] as? String ?? "")
                    let petPhotoURL = (data["petPhotoURLs"] as? [String])?.first
                    
                    // Only include visits with pet photos and unique pet names
                    if let photoURL = petPhotoURL, !photoURL.isEmpty, !petName.isEmpty {
                        // Use pet name as key to avoid duplicates
                        if uniquePets[petName] == nil {
                            uniquePets[petName] = RecentPetPhoto(
                                url: photoURL,
                                petName: petName,
                                visitDate: visitDate
                            )
                        }
                    }
                }
                
                // Convert to array and sort by most recent visit date
                self.recentPetPhotos = Array(uniquePets.values)
                    .sorted { $0.visitDate > $1.visitDate }
                    .prefix(6) // Limit to 6 most recent unique pets
                    .map { $0 }
            }
    }
    
    // MARK: - Active Hours Loading
    private func loadActiveHours() {
        guard let sitterUid else { 
            dailyActiveHours = []
            return 
        }
        
        isLoadingActiveHours = true
        let db = Firestore.firestore()
        let cal = Calendar.current
        
        // Calculate date range
        let endDate = Date()
        let startDate: Date
        switch selectedDateRange {
        case .week:
            startDate = cal.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = cal.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .quarter:
            startDate = cal.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        }
        
        // Query visits within date range
        db.collection("visits")
            .whereField("sitterId", isEqualTo: sitterUid)
            .whereField("scheduledStart", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("scheduledStart", isLessThanOrEqualTo: Timestamp(date: endDate))
            .order(by: "scheduledStart")
            .getDocuments { [self] snapshot, error in
                DispatchQueue.main.async {
                    isLoadingActiveHours = false
                    
                    guard error == nil, let snapshot = snapshot else {
                        dailyActiveHours = []
                        return
                    }
                    
                    // Group visits by date
                    var visitsByDate: [Date: [VisitItem]] = [:]
                    
                    for document in snapshot.documents {
                        let data = document.data()
                        let start = (data["scheduledStart"] as? Timestamp)?.dateValue() ?? Date()
                        let end = (data["scheduledEnd"] as? Timestamp)?.dateValue() ?? start
                        let clientName = data["clientName"] as? String ?? ""
                        let address = data["address"] as? String ?? ""
                        let note = data["note"] as? String ?? ""
                        let service = data["serviceSummary"] as? String ?? ""
                        let pets = (data["pets"] as? [String])?.joined(separator: ", ") ?? (data["petName"] as? String ?? "")
                        let firstPhoto = (data["petPhotoURLs"] as? [String])?.first
                        let status = data["status"] as? String ?? "scheduled"
                        let checkIn = ((data["timeline"] as? [String: Any])?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp
                        let checkOut = ((data["timeline"] as? [String: Any])?["checkOut"] as? [String: Any])?["timestamp"] as? Timestamp
                        
                        let visit = VisitItem(
                            id: document.documentID,
                            start: start,
                            end: end,
                            clientName: clientName,
                            address: address,
                            note: note,
                            serviceSummary: service,
                            petName: pets,
                            petPhotoURL: firstPhoto,
                            status: status,
                            checkIn: checkIn?.dateValue(),
                            checkOut: checkOut?.dateValue()
                        )
                        
                        let dayStart = cal.startOfDay(for: start)
                        visitsByDate[dayStart, default: []].append(visit)
                    }
                    
                    // Calculate daily active hours
                    var dailyHours: [DailyActiveHours] = []
                    
                    for (date, dayVisits) in visitsByDate {
                        let sortedVisits = dayVisits.sorted { $0.start < $1.start }
                        
                        guard let firstVisit = sortedVisits.first,
                              let lastVisit = sortedVisits.last else { continue }
                        
                        let firstStart = firstVisit.start
                        let lastEnd = lastVisit.end
                        let totalHours = lastEnd.timeIntervalSince(firstStart) / 3600 // Convert to hours
                        
                        // Get sitter name (you might want to fetch this from user data)
                        let sitterName = "You" // For now, using "You" since this is the sitter's own dashboard
                        
                        let dailyHour = DailyActiveHours(
                            date: date,
                            sitterName: sitterName,
                            sitterId: sitterUid,
                            firstVisitStart: firstStart,
                            lastVisitEnd: lastEnd,
                            totalActiveHours: totalHours,
                            visitCount: sortedVisits.count
                        )
                        
                        dailyHours.append(dailyHour)
                    }
                    
                    // Sort by date (most recent first)
                    self.dailyActiveHours = dailyHours.sorted { $0.date > $1.date }
                }
            }
    }
	
	private var ActiveHoursView: some View {
		NavigationStack {
			VStack(spacing: 16) {
				// Date range picker
				HStack {
					Text("Date Range")
						.font(.headline)
					Spacer()
					Picker("Date Range", selection: $selectedDateRange) {
						ForEach(DateRange.allCases, id: \.self) { range in
							Text(range.rawValue).tag(range)
						}
					}
					.pickerStyle(SegmentedPickerStyle())
					.frame(width: 200)
				}
				.padding(.horizontal)
				
				if isLoadingActiveHours {
					ProgressView("Loading active hours...")
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else if dailyActiveHours.isEmpty {
					VStack(spacing: 12) {
						Image(systemName: "clock")
							.font(.system(size: 48))
							.foregroundColor(.secondary)
						Text("No active hours data")
							.font(.headline)
							.foregroundColor(.secondary)
						Text("Complete some visits to see your active hours")
							.font(.subheadline)
							.foregroundColor(.secondary)
							.multilineTextAlignment(.center)
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else {
					ScrollView {
						LazyVStack(spacing: 12) {
							ForEach(dailyActiveHours) { dailyHours in
								ActiveHoursCard(dailyHours: dailyHours)
							}
						}
						.padding(.horizontal)
					}
				}
			}
			.navigationTitle("Active Hours")
			.onAppear {
				loadActiveHours()
			}
			.onChange(of: selectedDateRange) { _ in
				loadActiveHours()
			}
		}
	}
}

private struct SitterMessagesTab: View {
    @EnvironmentObject var chat: ChatService
    @State private var selectedConversationId: String? = nil
    @State private var input: String = ""
    @State private var showNewMessageSheet: Bool = false
    let selectedClientName: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                    
                    Section("Quick Actions") {
                        Button(action: { showNewMessageSheet = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Start New Conversation")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Messages")
            .onAppear { 
                chat.listenToMyConversations()
                // Check if we should open a specific conversation
                if let clientName = selectedClientName {
                    // Try to find existing conversation with this client
                    if let existingConvo = chat.conversations.first(where: { 
                        $0.participants.contains(clientName) 
                    }) {
                        selectedConversationId = existingConvo.id
                    } else {
                        // Show new message sheet for this client
                        showNewMessageSheet = true
                    }
                }
            }
            .sheet(item: Binding(get: {
                selectedConversationId.map { ChatSheetId(id: $0) }
            }, set: { v in selectedConversationId = v?.id })) { item in
                ConversationChatView(conversationId: item.id)
                    .environmentObject(chat)
            }
            .sheet(isPresented: $showNewMessageSheet) {
                NewMessageView(selectedClientName: selectedClientName)
                    .environmentObject(chat)
            }
        }
    }
}

// MARK: - Calendar Tab
private struct SitterCalendarView: View {
    @Binding var selectedDay: Date
    var visits: [VisitItem]
    @Binding var expandedCards: Set<String>
    @Binding var navigateToMessages: Bool
    @Binding var selectedClientForMessage: String?
    var onChangeDay: (Date) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    weekStrip
                    Button(action: jumpToToday) {
                        Label("Jump To Today", systemImage: "calendar.badge.clock")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GhostButtonStyle())
                    .padding(.horizontal)

                    if visits.isEmpty {
                        if #available(iOS 17.0, *) {
                            ContentUnavailableView("No visits", systemImage: "calendar", description: Text("No scheduled visits for this day."))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar").font(.largeTitle).foregroundColor(.secondary)
                                Text("No scheduled visits for this day.").foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(visits) { v in 
                                VisitCard(
                                    visit: v,
                                    isExpanded: Binding(
                                        get: { expandedCards.contains(v.id) },
                                        set: { isExpanded in
                                            if isExpanded {
                                                expandedCards.insert(v.id)
                                            } else {
                                                expandedCards.remove(v.id)
                                            }
                                        }
                                    ),
                                    navigateToMessages: $navigateToMessages,
                                    selectedClientForMessage: $selectedClientForMessage
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Schedule")
        }
    }

    private func jumpToToday() {
        selectedDay = Calendar.current.startOfDay(for: Date())
        onChangeDay(selectedDay)
    }

    private var weekStrip: some View {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -3, to: selectedDay) ?? selectedDay
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Button(action: { selectedDay = cal.date(byAdding: .day, value: -1, to: selectedDay)!; onChangeDay(selectedDay) }) { Image(systemName: "chevron.left") }
                ForEach(days, id: \.self) { day in
                    let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
                    VStack {
                        Text(day, format: .dateTime.weekday(.abbreviated))
                        ZStack {
                            Circle().strokeBorder(isSelected ? Color.primary : Color.secondary.opacity(0.2))
                                .background(Circle().fill(isSelected ? Color.primary.opacity(0.15) : Color.clear))
                                .frame(width: 56, height: 56)
                            Text(day, format: .dateTime.day())
                        }
                    }
                    .onTapGesture { selectedDay = day; onChangeDay(day) }
                }
                Button(action: { selectedDay = cal.date(byAdding: .day, value: 1, to: selectedDay)!; onChangeDay(selectedDay) }) { Image(systemName: "chevron.right") }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
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
	@Binding var isExpanded: Bool
	@State private var started: Bool = false
	@State private var startTime: Date? = nil
	@State private var tick: Date = Date()
	@State private var showDraft: Bool = false
	@State private var draftText: String = ""
	@State private var showCompleteConfirm: Bool = false
	@State private var isCompleted: Bool = false
	@State private var showPetImageZoom: Bool = false
	@State private var endTime: Date? = nil
	@State private var showClientDetails: Bool = false
	@Binding var navigateToMessages: Bool
	@Binding var selectedClientForMessage: String?
	@State private var fiveMinuteWarningSent: Bool = false
	
	// Initialize timer state based on visit status
	private var isVisitStarted: Bool {
		// Prioritize local state over Firestore status for immediate UI updates
		if started && startTime != nil {
			return true
		}
		// Fallback to Firestore status for visits that were started elsewhere
		return visit.status == "in_adventure" || visit.status == "completed"
	}
	
	private var isVisitCompleted: Bool {
		// Prioritize local state over Firestore status for immediate UI updates
		if isCompleted && endTime != nil {
			return true
		}
		// Fallback to Firestore status for visits that were completed elsewhere
		return visit.status == "completed"
	}
	
	private var actualStartTime: Date {
		// Use the actual checkIn time from Firestore if available
		if let checkInTime = visit.checkIn {
			return checkInTime
		}
		// Fallback to the visit's scheduled start time
		return visit.start
	}
	
	private var visitEndTime: Date {
		// Use the actual checkout time from Firestore if available
		if let checkOutTime = visit.checkOut {
			return checkOutTime
		}
		// Fallback to the visit's scheduled end time
		return visit.end
	}

    private var timeRange: String {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "h:mm a"
        return "\(df.string(from: visit.start)) - \(df.string(from: visit.end))"
    }

	private var timeLeftString: String {
		let now = tick // Use tick instead of Date() for reactive updates
		let elapsed = now.timeIntervalSince(actualStartTime)
		let totalDuration = visit.end.timeIntervalSince(visit.start)
		let remaining = max(totalDuration - elapsed, 0)
		
		let mins = Int(remaining) / 60
		let secs = Int(remaining) % 60
		
		// Return overtime indicator if past scheduled end time
		if elapsed > totalDuration {
			let overtime = Int(elapsed - totalDuration)
			let overtimeMins = overtime / 60
			let overtimeSecs = overtime % 60
			return String(format: "+%dm %02ds", overtimeMins, overtimeSecs)
		}
		
		return String(format: "%dm %02ds", mins, secs)
	}
	
	private var isOvertime: Bool {
		let now = tick // Use tick for reactive updates
		let elapsed = now.timeIntervalSince(actualStartTime)
		let totalDuration = visit.end.timeIntervalSince(visit.start)
		return elapsed > totalDuration
	}
	
	private var isFiveMinuteWarning: Bool {
		let now = tick // Use tick for reactive updates
		let elapsed = now.timeIntervalSince(actualStartTime)
		let totalDuration = visit.end.timeIntervalSince(visit.start)
		let remaining = max(totalDuration - elapsed, 0)
		return remaining <= 300 && remaining > 0 // 5 minutes = 300 seconds
	}
    
    private func formatTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "h:mm a"
        return df.string(from: date)
    }

	var body: some View {
		VStack(spacing: 0) {
			// Top slim bar with time range and direction arrow - Clickable for expand/collapse
            Button(action: { 
				withAnimation(.easeInOut(duration: 0.3)) {
					isExpanded.toggle()
				}
			}) {
				HStack {
					Label(timeRange, systemImage: visit.status == "completed" ? "checkmark.circle.fill" : "clock")
						.font(.subheadline)
						.labelStyle(.titleAndIcon)
					Spacer()
					HStack(spacing: 8) {
						Button(action: openInMaps) { 
							Image(systemName: "paperplane")
								.font(.title3)
						}
						Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
				.padding(.horizontal)
				.padding(.vertical, 10)
			}
			.buttonStyle(PlainButtonStyle())
			.background(
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.fill(visit.status == "completed" ? Color.green : Color.blue.opacity(0.08))
			)

			SPCard {
				if isExpanded {
					VStack(alignment: .leading, spacing: 12) {
						// Client & address
						HStack(alignment: .top) {
							VStack(alignment: .leading, spacing: 6) {
								HStack(spacing: 8) {
									Text(visit.clientName).font(.headline).bold()
									
									// Timer status indicator next to client name
									if isVisitStarted {
										HStack(spacing: 4) {
											Image(systemName: "figure.run")
												.font(.caption)
												.foregroundColor(Color(red: 184/255, green: 166/255, blue: 7/255))
											Text(isVisitCompleted ? "Visit Ended" : "Running")
												.font(.caption)
												.fontWeight(.bold)
												.foregroundColor(Color(red: 184/255, green: 166/255, blue: 7/255))
										}
									}
								}
								Text(visit.address)
									.foregroundColor(.secondary)
							}
							Spacer()
						}

						// Event Note (only if owner left notes) - Always visible
						if !visit.note.isEmpty {
							VStack(alignment: .leading, spacing: 4) {
								Text("Event Note").font(.subheadline).bold()
								Text(visit.note)
							}
						}

						// Services & pet with image
						HStack(alignment: .top, spacing: 12) {
							VStack(alignment: .leading, spacing: 4) {
							Text("Services: \(visit.serviceSummary)")
								.font(.subheadline)
								.bold()
								.foregroundColor(.secondary)
							Text("Pets: \(visit.petName)")
								.font(.subheadline)
								.foregroundColor(.blue)
							}
							
							// Pet image (circular, like in reference)
							if let urlString = visit.petPhotoURL, let url = URL(string: urlString) {
								AsyncImage(url: url) { phase in
									switch phase {
									case .success(let image):
										image
											.resizable()
											.aspectRatio(contentMode: .fill)
											.frame(width: 60, height: 60)
											.clipped()
									case .empty: 
										ProgressView()
											.frame(width: 60, height: 60)
									case .failure(_): 
										Image(systemName: "pawprint.fill")
											.foregroundColor(.gray)
											.frame(width: 60, height: 60)
											.background(Color.gray.opacity(0.2))
									@unknown default: 
										EmptyView()
											.frame(width: 60, height: 60)
									}
								}
								.clipShape(Circle())
								.onTapGesture { 
									showPetImageZoom = true
								}
							} else {
								// Placeholder when no image
								Image(systemName: "pawprint.fill")
									.foregroundColor(.gray)
									.frame(width: 60, height: 60)
									.background(Color.gray.opacity(0.2))
									.clipShape(Circle())
							}
						}

						// Bottom action bar (timer + details)
						if isVisitStarted {
							HStack {
								VStack(alignment: .leading) {
									Text(isVisitCompleted ? "Started" : "START")
										.foregroundColor(isVisitCompleted ? .blue : .red)
										.bold()
									Text(formatTime(actualStartTime))
								}
								Spacer()
								VStack(alignment: .trailing) {
									if isVisitCompleted {
										Text("Visit Ended").foregroundColor(.blue).bold()
										Text(formatTime(visitEndTime))
									} else {
										Text("TIME LEFT").foregroundColor(.red).bold()
										Text(timeLeftString)
											.foregroundColor(isOvertime ? .red : (isFiveMinuteWarning ? .orange : .primary))
											.fontWeight(isOvertime || isFiveMinuteWarning ? .bold : .regular)
									}
								}
							}
							.padding(.vertical, 8)
							.padding(.horizontal, 12)
							.background(
								RoundedRectangle(cornerRadius: 8)
									.fill(isOvertime ? Color.red.opacity(0.1) : (isFiveMinuteWarning ? Color.orange.opacity(0.1) : Color.clear))
							)
						}

						HStack {
							Text("Client Details")
								.font(.system(size: 14))
								.foregroundColor(Color(red: 184/255, green: 166/255, blue: 7/255))
								.onTapGesture { showClientDetails = true }
							Spacer()
							
							// Only show timer button if visit is not completed
							if !isVisitCompleted {
								if isVisitStarted {
									Image(systemName: "figure.run")
										.font(.title3)
										.foregroundColor(Color(red: 184/255, green: 166/255, blue: 7/255))
								} else {
									Text("Start Visit")
										.font(.subheadline)
										.foregroundColor(Color(red: 184/255, green: 166/255, blue: 7/255))
										.onTapGesture { 
											startVisit() 
										}
								}
							}
							
							if isVisitStarted && !isVisitCompleted {
								Button(action: { showCompleteConfirm = true }) { 
									Text("End Visit")
										.font(.subheadline)
								}
								.buttonStyle(GhostButtonStyle())
								.controlSize(.small)
							}
						}
					}
				} else {
					// Collapsed view - just show basic info
					HStack {
						VStack(alignment: .leading, spacing: 4) {
							Text(visit.clientName).font(.headline)
							Text(visit.serviceSummary).font(.subheadline).foregroundColor(.secondary)
						}
						Spacer()
						if isVisitStarted {
							HStack(spacing: 4) {
								Image(systemName: "figure.run")
									.font(.caption)
									.foregroundColor(Color(red: 184/255, green: 166/255, blue: 7/255))
								Text(isVisitCompleted ? "Completed" : "Running")
									.font(.caption)
									.fontWeight(.bold)
									.foregroundColor(Color(red: 184/255, green: 166/255, blue: 7/255))
							}
						}
					}
				}
			}
			.onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
				if isVisitStarted { 
					tick = now
					
					// Send 5-minute warning notification
					if isFiveMinuteWarning && !fiveMinuteWarningSent {
						fiveMinuteWarningSent = true
						NotificationService.shared.sendLocalNotification(
							title: "Visit Ending Soon",
							body: "Your visit with \(visit.clientName) ends in 5 minutes",
							userInfo: ["visitId": visit.id, "type": "visit_warning"]
						)
					}
				}
			}
			.onAppear {
				// Timer state is now managed entirely through Firestore timestamps
				// No need to initialize local state variables
			}
			.alert("Complete Visit?", isPresented: $showCompleteConfirm) {
                Button("Yes, Complete") { completeVisit() }
				Button("Back", role: .cancel) {}
			} message: {
				Text("you're about to mark this event as complete. Are you sure?")
			}
		}
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(Color(.systemBackground))
				.shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
		)
		.overlay(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.stroke(isCompleted ? SPDesignSystem.Colors.success : Color.clear, lineWidth: 2)
		)
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
		.sheet(isPresented: $showPetImageZoom) {
			NavigationStack {
				VStack {
					if let urlString = visit.petPhotoURL, let url = URL(string: urlString) {
						AsyncImage(url: url) { phase in
							switch phase {
							case .success(let image):
								image
									.resizable()
									.aspectRatio(contentMode: .fit)
									.frame(maxWidth: .infinity, maxHeight: .infinity)
							case .empty: 
								ProgressView()
									.frame(maxWidth: .infinity, maxHeight: .infinity)
							case .failure(_): 
								VStack {
									Image(systemName: "pawprint.fill")
										.font(.system(size: 60))
										.foregroundColor(.gray)
									Text("Failed to load image")
										.foregroundColor(.secondary)
								}
								.frame(maxWidth: .infinity, maxHeight: .infinity)
							@unknown default: 
								EmptyView()
							}
						}
					} else {
						VStack {
							Image(systemName: "pawprint.fill")
								.font(.system(size: 60))
								.foregroundColor(.gray)
							Text("No image available")
								.foregroundColor(.secondary)
						}
						.frame(maxWidth: .infinity, maxHeight: .infinity)
					}
				}
				.padding()
				.navigationTitle("Pet Photo")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") { showPetImageZoom = false }
					}
				}
			}
		}
		.sheet(isPresented: $showClientDetails) {
			NavigationStack {
				VStack(spacing: 20) {
					// Client's Name at the top center
					VStack(spacing: 8) {
						Text("Client")
							.font(.caption)
							.foregroundColor(.secondary)
						Text(visit.clientName)
							.font(.title2)
							.fontWeight(.bold)
					}
					.padding(.top)
					
					// Pets Section
					VStack(alignment: .leading, spacing: 12) {
						Text("Pets")
							.font(.headline)
							.padding(.horizontal)
						
						ScrollView(.horizontal, showsIndicators: false) {
							HStack(spacing: 16) {
								// For now, show the single pet from visit data
								// In a real implementation, you'd fetch all pets for this client
								VStack(spacing: 8) {
									if let urlString = visit.petPhotoURL, let url = URL(string: urlString) {
										AsyncImage(url: url) { phase in
											switch phase {
											case .success(let image):
												image
													.resizable()
													.aspectRatio(contentMode: .fill)
													.frame(width: 80, height: 80)
													.clipped()
											case .empty: 
												ProgressView()
													.frame(width: 80, height: 80)
											case .failure(_): 
												Image(systemName: "pawprint.fill")
													.foregroundColor(.gray)
													.frame(width: 80, height: 80)
													.background(Color.gray.opacity(0.2))
											@unknown default: 
												EmptyView()
													.frame(width: 80, height: 80)
											}
										}
										.clipShape(Circle())
									} else {
										Image(systemName: "pawprint.fill")
											.foregroundColor(.gray)
											.frame(width: 80, height: 80)
											.background(Color.gray.opacity(0.2))
											.clipShape(Circle())
									}
									
									Text(visit.petName)
										.font(.caption)
										.fontWeight(.medium)
								}
								.padding(.horizontal, 8)
							}
							.padding(.horizontal)
						}
					}
					
					// Private Notes Section
					VStack(alignment: .leading, spacing: 12) {
						Text("Private Notes")
							.font(.headline)
							.padding(.horizontal)
						
						VStack(alignment: .leading, spacing: 8) {
							if !visit.note.isEmpty {
								Text(visit.note)
									.font(.body)
									.padding()
									.background(Color.gray.opacity(0.1))
									.cornerRadius(8)
									.padding(.horizontal)
							} else {
								Text("No private notes provided")
									.font(.body)
									.foregroundColor(.secondary)
									.padding()
									.background(Color.gray.opacity(0.1))
									.cornerRadius(8)
									.padding(.horizontal)
							}
						}
					}
					
					Spacer()
					
					// Send Message Button
					Button(action: {
						selectedClientForMessage = visit.clientName
						showClientDetails = false
						navigateToMessages = true
					}) {
						HStack {
							Image(systemName: "message.fill")
								.font(.title3)
							Text("Send a message")
								.font(.headline)
								.fontWeight(.semibold)
						}
						.foregroundColor(.white)
						.frame(maxWidth: .infinity)
						.padding()
						.background(
							RoundedRectangle(cornerRadius: 12)
								.fill(Color.blue)
						)
					}
					.padding(.horizontal)
					.padding(.bottom, 20)
				}
				.navigationTitle("Client Details")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") { showClientDetails = false }
					}
				}
			}
		}
	}

	private func openInMaps() {
		// Open client address in Apple Maps app (not web)
		let encoded = visit.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
		if let url = URL(string: "maps://?daddr=\(encoded)") {
			if UIApplication.shared.canOpenURL(url) {
				UIApplication.shared.open(url)
			} else {
				// Fallback to Apple Maps web if native app not available
				if let fallbackUrl = URL(string: "http://maps.apple.com/?daddr=\(encoded)") {
					UIApplication.shared.open(fallbackUrl)
				}
			}
		}
	}

	private func startVisit() {
		// Update Firestore - the UI will update automatically via realtime listener
		let db = Firestore.firestore()
		db.collection("visits").document(visit.id).setData([
			"status": "in_adventure",
			"timeline.checkIn.timestamp": FieldValue.serverTimestamp(),
			"startedAt": FieldValue.serverTimestamp()
		], merge: true) { error in
			if let error = error {
				print("Error starting visit: \(error)")
			} else {
				print("Visit started successfully")
			}
		}
        LocationService.shared.startVisitTracking()
	}

	private func completeVisit() {
		showCompleteConfirm = false
		
		// Update Firestore - the UI will update automatically via realtime listener
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
		db.collection("visits").document(visit.id).setData(update, merge: true) { error in
			if let error = error {
				print("Error completing visit: \(error)")
			} else {
				print("Visit completed successfully")
			}
		}
        LocationService.shared.stopVisitTracking()
        // Also mark related booking as completed if it exists and matches by some external link (out of scope: mapping id). Placeholder for demonstration.
        // try? await serviceBookings.completeBooking(bookingId: <bookingId>)
	}
}

private extension SitterDashboardView {
	var weekStrip: some View {
		let cal = Calendar.current
		let startOfWeek = cal.dateInterval(of: .weekOfYear, for: selectedDay)?.start ?? selectedDay
		let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
		
		return VStack(spacing: 12) {
			// Week navigation header
			HStack {
				Button(action: { 
					withAnimation(.easeInOut(duration: 0.3)) {
						selectedDay = cal.date(byAdding: .weekOfYear, value: -1, to: selectedDay)!
					}
				}) { 
					Image(systemName: "chevron.left")
						.font(.title2)
						.foregroundColor(.primary)
						.frame(width: 44, height: 44)
						.background(
							Circle()
								.fill(Color(.systemGray6))
						)
				}
				
				Spacer()
				
				Text(selectedDay, format: .dateTime.month(.wide).year())
					.font(.headline)
					.fontWeight(.semibold)
				
				Spacer()
				
				Button(action: { 
					withAnimation(.easeInOut(duration: 0.3)) {
						selectedDay = cal.date(byAdding: .weekOfYear, value: 1, to: selectedDay)!
					}
				}) { 
					Image(systemName: "chevron.right")
						.font(.title2)
						.foregroundColor(.primary)
						.frame(width: 44, height: 44)
						.background(
							Circle()
								.fill(Color(.systemGray6))
						)
				}
			}
			.padding(.horizontal)
			
			// Week days strip - Full width, no scrolling
			HStack(spacing: 0) {
				ForEach(days, id: \.self) { day in
					let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
					let isToday = cal.isDate(day, inSameDayAs: Date())
					
					VStack(spacing: 6) {
						Text(day, format: .dateTime.weekday(.abbreviated))
							.font(.caption)
							.foregroundColor(.secondary)
						
						ZStack {
							Circle()
								.fill(isSelected ? Color(red: 184/255, green: 166/255, blue: 7/255) : Color.clear)
								.frame(width: 40, height: 40)
							
							Circle()
								.strokeBorder(isToday ? Color(red: 184/255, green: 166/255, blue: 7/255) : Color.gray.opacity(0.2), lineWidth: isToday ? 2 : 1)
								.frame(width: 40, height: 40)
							
							Text(day, format: .dateTime.day())
								.font(.subheadline)
								.fontWeight(isSelected ? .bold : .medium)
								.foregroundColor(isSelected ? .white : (isToday ? Color(red: 184/255, green: 166/255, blue: 7/255) : .primary))
						}
					}
					.frame(maxWidth: .infinity)
					.onTapGesture { 
						withAnimation(.easeInOut(duration: 0.2)) {
							selectedDay = day
						}
					}
				}
			}
			.padding(.horizontal)
		}
	}
}

// MARK: - Active Hours Card
private struct ActiveHoursCard: View {
    let dailyHours: DailyActiveHours
    @State private var isExpanded: Bool = false
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: dailyHours.date)
    }
    
    private var formattedStartTime: String {
        guard let startTime = dailyHours.firstVisitStart else { return "N/A" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    private var formattedEndTime: String {
        guard let endTime = dailyHours.lastVisitEnd else { return "N/A" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: endTime)
    }
    
    private var formattedHours: String {
        let hours = Int(dailyHours.totalActiveHours)
        let minutes = Int((dailyHours.totalActiveHours.truncatingRemainder(dividingBy: 1)) * 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var hoursColor: Color {
        if dailyHours.totalActiveHours >= 8 {
            return .green
        } else if dailyHours.totalActiveHours >= 4 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - always visible
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedDate)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(dailyHours.visitCount) visits")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formattedHours)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(hoursColor)
                        
                        Text("Total Active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Sitter:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(dailyHours.sitterName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("First Visit Start:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formattedStartTime)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Last Visit End:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formattedEndTime)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Total Active Hours:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formattedHours)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(hoursColor)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
            }
        }
    }
}

// MARK: - New Message View
private struct NewMessageView: View {
    @EnvironmentObject var chat: ChatService
    @Environment(\.dismiss) private var dismiss
    let selectedClientName: String?
    
    @State private var messageText: String = ""
    @State private var isSending: Bool = false
    @State private var showSuccessAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Send Message")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let clientName = selectedClientName {
                        Text("To: \(clientName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Your message will be reviewed by an admin before delivery.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Message input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.headline)
                    
                    TextEditor(text: $messageText)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .overlay(
                            Group {
                                if messageText.isEmpty {
                                    Text("Type your message here...")
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Send button
                Button(action: sendMessage) {
                    HStack {
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSending ? "Sending..." : "Send Message")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Message Sent", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your message has been sent for admin review. You'll be notified once it's approved.")
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSending = true
        
        Task {
            do {
                let currentUser = Auth.auth().currentUser
                let db = Firestore.firestore()
                
                // Find admin user ID
                let adminQuery = try await db.collection("users")
                    .whereField("role", isEqualTo: "admin")
                    .limit(to: 1)
                    .getDocuments()
                
                guard let adminDoc = adminQuery.documents.first else {
                    throw NSError(domain: "ChatError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Admin user not found"])
                }
                
                let adminId = adminDoc.documentID
                let sitterId = currentUser?.uid ?? ""
                
                // Create conversation ID that includes admin and sitter
                let conversationId = "sitter_\(sitterId)_admin_\(adminId)_client_\(selectedClientName ?? "")"
                
                // Create or get conversation with admin and sitter as participants
                let conversationRef = db.collection("conversations").document(conversationId)
                let conversationDoc = try await conversationRef.getDocument()
                
                if !conversationDoc.exists {
                    try await conversationRef.setData([
                        "participants": [sitterId, adminId],
                        "participantRoles": [UserRole.petSitter.rawValue, UserRole.admin.rawValue],
                        "type": ConversationType.sitterToClient.rawValue,
                        "status": "active",
                        "createdAt": FieldValue.serverTimestamp(),
                        "lastMessage": "",
                        "lastMessageAt": FieldValue.serverTimestamp(),
                        "isPinned": false,
                        "autoResponderSent": false,
                        "adminReplied": false,
                        "autoResponseHistory": [:],
                        "autoResponseCooldown": 86400,
                        "unreadCounts": [:],
                        "lastReadTimestamps": [:]
                    ])
                }
                
                // Send message with admin moderation so it appears in admin's approval queue
                try await ResilientChatService.shared.sendMessage(
                    conversationId: conversationId,
                    text: messageText,
                    moderationType: .admin
                )
                
                await MainActor.run {
                    isSending = false
                    showSuccessAlert = true
                    messageText = ""
                }
            } catch {
                print("Error sending message: \(error.localizedDescription)")
                await MainActor.run {
                    isSending = false
                    // You might want to show an error alert here
                }
            }
        }
    }
}

// MARK: - Notifications View
private struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notifications: [NotificationItem] = []
    
    private struct NotificationItem: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let timestamp: Date
        let type: String
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Notifications")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(notifications) { notification in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(notification.title)
                                        .font(.headline)
                                    Spacer()
                                    Text(notification.timestamp, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(notification.body)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadNotifications()
            }
        }
    }
    
    private func loadNotifications() {
        // For now, show sample notifications
        // In a real implementation, you'd fetch from a notifications collection
        notifications = [
            NotificationItem(
                title: "Visit Reminder",
                body: "Your visit with Max starts in 15 minutes",
                timestamp: Date().addingTimeInterval(-300),
                type: "reminder"
            ),
            NotificationItem(
                title: "Visit Completed",
                body: "Great job! Your visit with Luna has been completed",
                timestamp: Date().addingTimeInterval(-3600),
                type: "completion"
            )
        ]
    }
}

