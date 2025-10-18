import SwiftUI
import OSLog
import FirebaseAuth
import FirebaseFirestore
import Combine
import CoreLocation

// MARK: - Shared Date Formatters

private struct DateFormatters {
    static let shared = DateFormatters()
    
    let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "h:mm a"
        return df
    }()
    
    let fullDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .full
        return df
    }()
    
    let shortTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }()
    
    private init() {}
}

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
    let petNames: [String]  // Array of pet names
    let petPhotoURLs: [String]  // Array of pet photo URLs
    let status: VisitStatus
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

private enum SitterDateRange: String, CaseIterable {
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
	@State private var selectedDateRange: SitterDateRange = .week
	@State private var isLoadingActiveHours: Bool = false
	
	// Recent pets tracking
	@State private var recentPetPhotos: [RecentPetPhoto] = []
	
	// Listener management
	@State private var visitsListener: ListenerRegistration?
	
	// Track pending Firestore writes for visual feedback
	@State private var pendingWrites: Set<String> = []
	
	// Track actual start/end times per visit for real-time updates
	@State private var actualStartTimes: [String: Date] = [:]  // visitId: actualStartTime
	@State private var actualEndTimes: [String: Date] = [:]    // visitId: actualEndTime

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
            ModernConversationListView()
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
            .onDisappear {
                visitsListener?.remove()
                visitsListener = nil
            }
			.onChange(of: selectedDay) { _ in 
				loadVisitsRealtime() // Reload with new realtime listener for new day
			}
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
					selectedClientForMessage: $selectedClientForMessage,
					pendingWrites: $pendingWrites,
					actualStartTimes: $actualStartTimes,
					actualEndTimes: $actualEndTimes
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
    private func loadVisitsRealtime() {
		guard let sitterUid else { 
			DispatchQueue.main.async {
				self.visits = []
			}
			return 
		}
		
		let cal = Calendar.current
		let dayStart = cal.startOfDay(for: selectedDay)
		let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? selectedDay
		
		// Remove existing listener before creating new one
		visitsListener?.remove()
		
		// Set up realtime listener for the selected day
		visitsListener = Firestore.firestore().collection("visits")
			.whereField("sitterId", isEqualTo: sitterUid)
			.whereField("scheduledStart", isGreaterThanOrEqualTo: Timestamp(date: dayStart))
			.whereField("scheduledStart", isLessThan: Timestamp(date: dayEnd))
			.order(by: "scheduledStart")
			.addSnapshotListener { snapshot, error in
				if let error = error {
					AppLogger.ui.error("Error loading visits: \(error.localizedDescription)")
					return
				}
				
				guard let snapshot = snapshot else {
					DispatchQueue.main.async {
						self.visits = []
					}
					return
				}
				
			// Skip processing ONLY snapshots with pending writes to prevent UI showing stale data
			if snapshot.metadata.hasPendingWrites {
				AppLogger.ui.debug("Skipping snapshot with pending writes (isFromCache: \(snapshot.metadata.isFromCache))")
				return
			}
			
			// CRITICAL FIX: Skip cached snapshots if we have ANY pending Firestore writes
			// This prevents cached data from overwriting our optimistic UI updates (like undo)
			if snapshot.metadata.isFromCache && !self.pendingWrites.isEmpty {
				AppLogger.ui.debug("Skipping CACHED snapshot because we have pending writes: \(self.pendingWrites)")
				return
			}
			
			// Process all other snapshots (fresh server data or cache when no pending writes)
			// Debug logging to track snapshot source
			#if DEBUG
			AppLogger.ui.info("Processing snapshot: isFromCache=\(snapshot.metadata.isFromCache), hasPendingWrites=\(snapshot.metadata.hasPendingWrites), pendingWrites=\(self.pendingWrites)")
			#endif
				
				let documents = snapshot.documents
				if documents.isEmpty {
					DispatchQueue.main.async {
						self.visits = []
					}
					return
				}
				
				var items: [VisitItem] = []
				var newActualStartTimes: [String: Date] = [:]
				var newActualEndTimes: [String: Date] = [:]
				
				for document in documents {
					let data = document.data()
					let visitId = document.documentID
					let start = (data["scheduledStart"] as? Timestamp)?.dateValue() ?? dayStart
					let end = (data["scheduledEnd"] as? Timestamp)?.dateValue() ?? start
					let clientName = data["clientName"] as? String ?? ""
					let address = data["address"] as? String ?? ""
					let note = data["note"] as? String ?? ""
					let service = data["serviceSummary"] as? String ?? ""
					
					// Get pet names as array
					let petNamesArray = (data["pets"] as? [String]) ?? []
					let pets = petNamesArray.isEmpty ? (data["petName"] as? String ?? "") : petNamesArray.joined(separator: ", ")
					
					// Get pet photo URLs as array
					let petPhotoURLsArray = (data["petPhotoURLs"] as? [String]) ?? []
					let firstPhoto = petPhotoURLsArray.first
					
					// DEBUG: Log address data for each visit
					AppLogger.ui.debug("Visit \(visitId): address from Firestore = '\(address)' (isEmpty: \(address.isEmpty))")
					
					// Parse status using VisitStatus enum
					let statusString = data["status"] as? String ?? "scheduled"
					let status = VisitStatus(rawValue: statusString) ?? .scheduled
					
					let checkIn = ((data["timeline"] as? [String: Any])?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp
					let checkOut = ((data["timeline"] as? [String: Any])?["checkOut"] as? [String: Any])?["timestamp"] as? Timestamp
					
					// Track actual start/end times in dedicated dictionaries for real-time access
					if let checkInDate = checkIn?.dateValue() {
						newActualStartTimes[visitId] = checkInDate
						
						// Log timeline changes
						if let previousStart = self.actualStartTimes[visitId] {
							if previousStart != checkInDate {
								AppLogger.ui.info("Visit \(visitId): checkIn CHANGED from \(previousStart) to \(checkInDate)")
							}
						} else {
							AppLogger.ui.info("Visit \(visitId): checkIn SET to \(checkInDate)")
						}
					} else {
						// Log when checkIn is removed (undo)
						if self.actualStartTimes[visitId] != nil {
							AppLogger.data.info("Visit \(visitId): checkIn REMOVED (undo)")
						}
					}
					
					if let checkOutDate = checkOut?.dateValue() {
						newActualEndTimes[visitId] = checkOutDate
						
						// Log timeline changes
						if let previousEnd = self.actualEndTimes[visitId] {
							if previousEnd != checkOutDate {
								AppLogger.ui.info("Visit \(visitId): checkOut CHANGED from \(previousEnd) to \(checkOutDate)")
							}
						} else {
							AppLogger.ui.info("Visit \(visitId): checkOut SET to \(checkOutDate)")
						}
					}
					
					// Debug logging for checkIn timestamp
					#if DEBUG
					if status == .inAdventure || status == .completed {
						if checkIn?.dateValue() != nil {
							AppLogger.ui.info("Visit \(visitId): checkIn loaded = \(String(describing: checkIn?.dateValue()))")
						} else {
							AppLogger.ui.warning("Visit \(visitId): checkIn is NIL despite status = \(statusString)")
						}
					}
					#endif
					
					items.append(VisitItem(
						id: document.documentID,
						start: start,
						end: end,
						clientName: clientName,
						address: address,
						note: note,
						serviceSummary: service,
						petName: pets,
						petPhotoURL: firstPhoto,
						petNames: petNamesArray,
						petPhotoURLs: petPhotoURLsArray,
						status: status,
						checkIn: checkIn?.dateValue(),
						checkOut: checkOut?.dateValue()
					))
				}
				
				// Update actual start/end times dictionaries on main thread
				DispatchQueue.main.async {
					self.actualStartTimes = newActualStartTimes
					self.actualEndTimes = newActualEndTimes
				}
				
				// Update visits array on main thread
				DispatchQueue.main.async {
					self.visits = items.sorted { $0.start < $1.start }
				}
				
				AppLogger.ui.info("Loaded \(items.count) visits, \(newActualStartTimes.count) with actual start times, \(newActualEndTimes.count) with actual end times")
			}
	}
    
    // MARK: - Recent Pet Photos Loading
    private func loadRecentPetPhotos() {
        guard let sitterUid else { 
            DispatchQueue.main.async {
                self.recentPetPhotos = []
            }
            return 
        }
        
        let db = Firestore.firestore()
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        // Get recent completed visits from the last week
        db.collection("visits")
            .whereField("sitterId", isEqualTo: sitterUid)
            .whereField("status", isEqualTo: VisitStatus.completed.rawValue)
            .whereField("scheduledStart", isGreaterThanOrEqualTo: Timestamp(date: weekAgo))
            .order(by: "scheduledStart", descending: true)
            .limit(to: 20) // Get more visits to ensure we have enough unique pets
            .getDocuments { [self] snapshot, error in
                if let error = error {
                    AppLogger.ui.error("Error loading recent pet photos: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.recentPetPhotos = []
                    }
                    return
                }
                
                guard let snapshot = snapshot else {
                    DispatchQueue.main.async {
                        self.recentPetPhotos = []
                    }
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
                DispatchQueue.main.async {
                    self.recentPetPhotos = Array(uniquePets.values)
                        .sorted { $0.visitDate > $1.visitDate }
                        .prefix(6) // Limit to 6 most recent unique pets
                        .map { $0 }
                }
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
                        
                        // Get pet names as array
                        let petNamesArray = (data["pets"] as? [String]) ?? []
                        let pets = petNamesArray.isEmpty ? (data["petName"] as? String ?? "") : petNamesArray.joined(separator: ", ")
                        
                        // Get pet photo URLs as array
                        let petPhotoURLsArray = (data["petPhotoURLs"] as? [String]) ?? []
                        let firstPhoto = petPhotoURLsArray.first
                        
                        // Parse status using VisitStatus enum
                        let statusString = data["status"] as? String ?? "scheduled"
                        let status = VisitStatus(rawValue: statusString) ?? .scheduled
                        
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
                            petNames: petNamesArray,
                            petPhotoURLs: petPhotoURLsArray,
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
						ForEach(SitterDateRange.allCases, id: \.self) { range in
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

// Modern messaging components are now in ModernChatView.swift

// MARK: - Calendar Tab
private struct SitterCalendarView: View {
    @Binding var selectedDay: Date
    var visits: [VisitItem]
    @Binding var expandedCards: Set<String>
    @Binding var navigateToMessages: Bool
    @Binding var selectedClientForMessage: String?
    @Binding var pendingWrites: Set<String>
    @Binding var actualStartTimes: [String: Date]
    @Binding var actualEndTimes: [String: Date]
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
                                    selectedClientForMessage: $selectedClientForMessage,
                                    pendingWrites: $pendingWrites,
                                    actualStartTimes: $actualStartTimes,
                                    actualEndTimes: $actualEndTimes
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
	@State private var tick: Date = Date()
	@State private var isTimerActive: Bool = false // Explicit flag to control timer
	@State private var showDraft: Bool = false
	@State private var draftText: String = ""
	@State private var showCompleteConfirm: Bool = false
	@State private var showUndoConfirm: Bool = false
	@State private var showPetImageZoom: Bool = false
	@State private var showClientDetails: Bool = false
	@Binding var navigateToMessages: Bool
	@Binding var selectedClientForMessage: String?
	@Binding var pendingWrites: Set<String>
	@Binding var actualStartTimes: [String: Date]
	@Binding var actualEndTimes: [String: Date]
	@State private var fiveMinuteWarningSent: Bool = false
	@State private var errorMessage: String?
	@State private var showError: Bool = false
	
	// Track if this specific visit has a pending write
	private var isPendingWrite: Bool {
		return pendingWrites.contains(visit.id)
	}
	
	// MARK: - Scheduled Times (Never Change)
	
	private var scheduledStartTime: Date {
		return visit.start
	}
	
	private var scheduledEndTime: Date {
		return visit.end
	}
	
	// MARK: - Actual Times (Set when sitter taps Start/End)
	
	private var actualStartTime: Date? {
		// actualStartTimes dictionary is the ONLY source of truth
		// Do NOT fall back to visit.checkIn as it may have stale cached data
		return actualStartTimes[visit.id]
	}
	
	private var actualEndTime: Date? {
		// actualEndTimes dictionary is the ONLY source of truth
		// Do NOT fall back to visit.checkOut as it may have stale cached data
		return actualEndTimes[visit.id]
	}
	
	// MARK: - State Computed from Firestore Data ONLY
	
	private var isVisitStarted: Bool {
		// actualStartTime is the ONLY source of truth for UI state
		// This ensures instant UI updates when we optimistically update actualStartTimes
		return actualStartTime != nil
	}
	
	private var isVisitCompleted: Bool {
		// actualEndTime is the ONLY source of truth for UI state
		// This ensures instant UI updates when we optimistically update actualEndTimes
		return actualEndTime != nil
	}

    private var timeRange: String {
        let df = DateFormatters.shared.timeFormatter
        return "\(df.string(from: visit.start)) - \(df.string(from: visit.end))"
    }

	// MARK: - Timer Calculations (Based on Actual Times)
	
	private var timeLeftString: String {
		// SERVICE DURATION is always: scheduledEnd - scheduledStart (e.g., 15 minutes, 30 minutes)
		let serviceDuration = scheduledEndTime.timeIntervalSince(scheduledStartTime)
		
		guard let startTime = actualStartTime else {
			// Not started yet - show full service duration
			let mins = Int(serviceDuration) / 60
			let secs = Int(serviceDuration) % 60
			return String(format: "%02d:%02d", mins, secs)
		}
		
		// Started - calculate remaining time based on service duration
		let now = tick // Use tick for reactive updates
		let elapsed = now.timeIntervalSince(startTime)
		let remaining = serviceDuration - elapsed
		
		// Return overtime indicator if past service duration
		if remaining < 0 {
			let overtime = Int(abs(remaining))
			let overtimeMins = overtime / 60
			let overtimeSecs = overtime % 60
			return "+" + String(format: "%02d:%02d", overtimeMins, overtimeSecs)
		}
		
		// Normal countdown in MM:SS format
		let mins = Int(remaining) / 60
		let secs = Int(remaining) % 60
		return String(format: "%02d:%02d", mins, secs)
	}
	
	private var elapsedTimeString: String {
		guard let startTime = actualStartTime else {
			return "00:00"
		}
		
		let endTime = actualEndTime ?? tick // Use actual end if completed, otherwise now
		let elapsed = max(0, endTime.timeIntervalSince(startTime)) // Prevent negative elapsed time
		
		let hours = Int(elapsed) / 3600
		let minutes = (Int(elapsed) % 3600) / 60
		let seconds = Int(elapsed) % 60
		
		if hours > 0 {
			return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
		} else {
			return String(format: "%02d:%02d", minutes, seconds)
		}
	}
	
	private var isOvertime: Bool {
		guard let startTime = actualStartTime else {
			return false
		}
		
		let now = tick
		let elapsed = now.timeIntervalSince(startTime)
		let serviceDuration = scheduledEndTime.timeIntervalSince(scheduledStartTime)
		return elapsed > serviceDuration
	}
	
	private var isFiveMinuteWarning: Bool {
		guard let startTime = actualStartTime else {
			return false
		}
		
		let now = tick
		let elapsed = now.timeIntervalSince(startTime)
		let serviceDuration = scheduledEndTime.timeIntervalSince(scheduledStartTime)
		let remaining = serviceDuration - elapsed
		return remaining > 0 && remaining <= 300 // 5 minutes = 300 seconds
	}
    
    private func formatTime(_ date: Date) -> String {
        return DateFormatters.shared.timeFormatter.string(from: date)
    }
	
	// MARK: - Helper to show if sitter started early/late
	
	private var startTimeDifferenceText: String? {
		guard let actualStart = actualStartTime else {
			return nil
		}
		
		let difference = actualStart.timeIntervalSince(scheduledStartTime)
		let absMinutes = Int(abs(difference)) / 60
		
		guard absMinutes > 0 else {
			return nil // Started on time
		}
		
		if difference < 0 {
			return "\(absMinutes)m early"
		} else {
			return "\(absMinutes)m late"
		}
	}
	
	// Check if sitter started 15+ minutes late (for red card indicator)
	private var isSignificantlyLate: Bool {
		guard let actualStart = actualStartTime else {
			return false
		}
		
		let difference = actualStart.timeIntervalSince(scheduledStartTime)
		let minutesLate = difference / 60
		return minutesLate >= 15 // 15 minutes or more late
	}

	// Extract main content to reduce type-checking complexity
	private var mainContent: some View {
		VStack(spacing: 0) {
			// Top slim bar with time range and direction arrow - Clickable for expand/collapse
            Button(action: { 
				withAnimation(.easeInOut(duration: 0.3)) {
					isExpanded.toggle()
				}
			}) {
				HStack {
					Label(timeRange, systemImage: visit.status.isCompleted ? "checkmark.circle.fill" : "clock")
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
					.fill(visit.status.isCompleted ? (isSignificantlyLate ? Color.red : Color.green) : Color.blue.opacity(0.08))
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
											Image(systemName: "timer")
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

						// Event Note (only if owner left notes)
						if !visit.note.isEmpty {
							VStack(alignment: .leading, spacing: 4) {
								Text("Event Note").font(.subheadline).bold()
								Text(visit.note)
							}
						}

						// Services & Pets
						VStack(alignment: .leading, spacing: 12) {
							// Service info
							Text("Services: \(visit.serviceSummary)")
								.font(.subheadline)
								.bold()
								.foregroundColor(.secondary)
							
							// Pets section with all pet images
							VStack(alignment: .leading, spacing: 8) {
								Text("Pets: \(visit.petName)")
									.font(.subheadline)
									.foregroundColor(.blue)
								
								// Show all pet images if available
								if !visit.petPhotoURLs.isEmpty {
									ScrollView(.horizontal, showsIndicators: false) {
										HStack(spacing: 8) {
											ForEach(Array(zip(visit.petPhotoURLs.indices, visit.petPhotoURLs)), id: \.0) { index, urlString in
												if let url = URL(string: urlString) {
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
													.overlay(
														Circle()
															.stroke(Color.white, lineWidth: 2)
													)
												}
											}
										}
									}
								} else if let urlString = visit.petPhotoURL, let url = URL(string: urlString) {
									// Fallback to single pet photo if array is empty
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
								} else {
									// No images available
									Image(systemName: "pawprint.fill")
										.foregroundColor(.gray)
										.frame(width: 60, height: 60)
										.background(Color.gray.opacity(0.2))
										.clipShape(Circle())
								}
							}
						}

						// Bottom action bar (timer + details)
						if isVisitStarted {
							HStack {
								VStack(alignment: .leading, spacing: 4) {
									Text(isVisitCompleted ? "STARTED" : "START")
										.font(.caption)
										.foregroundColor(isVisitCompleted ? .blue : .green)
										.bold()
									HStack(spacing: 4) {
										// Display actual start time with safe unwrapping
										if let startTime = actualStartTime {
											VStack(alignment: .leading, spacing: 2) {
												Text(formatTime(startTime))
													.font(.subheadline)
													.fontWeight(.semibold)
												// Show if started early/late
												if let differenceText = startTimeDifferenceText {
													Text(differenceText)
														.font(.caption2)
														.foregroundColor(.secondary)
												}
											}
										} else {
											Text("--:--")
												.font(.subheadline)
												.foregroundColor(.secondary)
										}
										// Show syncing indicator if write is pending
										if isPendingWrite {
											ProgressView()
												.scaleEffect(0.7)
												.foregroundColor(.orange)
										}
									}
								}
								
								Spacer()
								
								// Middle: Elapsed time
								VStack(spacing: 4) {
									Text("ELAPSED")
										.font(.caption)
										.foregroundColor(.secondary)
										.bold()
									Text(elapsedTimeString)
										.font(.subheadline)
										.fontWeight(.semibold)
										.foregroundColor(.primary)
								}
								
								Spacer()
								
								VStack(alignment: .trailing, spacing: 4) {
									if isVisitCompleted {
										Text("ENDED")
											.font(.caption)
											.foregroundColor(.blue)
											.bold()
										HStack(spacing: 4) {
											// Display actual end time with safe unwrapping
											if let endTime = actualEndTime {
												Text(formatTime(endTime))
													.font(.subheadline)
													.fontWeight(.semibold)
											} else {
												Text("--:--")
													.font(.subheadline)
													.foregroundColor(.secondary)
											}
											if isPendingWrite {
												ProgressView()
													.scaleEffect(0.7)
													.foregroundColor(.orange)
											}
										}
									} else {
										Text("TIME LEFT")
											.font(.caption)
											.foregroundColor(isOvertime ? .red : (isFiveMinuteWarning ? .orange : .secondary))
											.bold()
										HStack(spacing: 4) {
											Text(timeLeftString)
												.font(.subheadline)
												.foregroundColor(isOvertime ? .red : (isFiveMinuteWarning ? .orange : .primary))
												.fontWeight(isOvertime || isFiveMinuteWarning ? .bold : .semibold)
											if isPendingWrite {
												ProgressView()
													.scaleEffect(0.7)
													.foregroundColor(.orange)
											}
										}
									}
								}
							}
							.padding(.vertical, 12)
							.padding(.horizontal, 16)
							.background(
								RoundedRectangle(cornerRadius: 12)
									.fill(isPendingWrite ? Color.orange.opacity(0.1) : (isOvertime ? Color.red.opacity(0.1) : (isFiveMinuteWarning ? Color.orange.opacity(0.1) : Color.gray.opacity(0.05))))
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
									// Show Undo button when visit is started but not completed
									Button(action: { 
										if !isPendingWrite {
											showUndoConfirm = true
										}
									}) { 
										HStack(spacing: 4) {
											Image(systemName: "arrow.uturn.backward.circle")
												.font(.caption)
											Text("Undo")
												.font(.caption)
												.fontWeight(.medium)
										}
										.foregroundColor(.orange)
									}
									.buttonStyle(PlainButtonStyle())
									.disabled(isPendingWrite)
									.opacity(isPendingWrite ? 0.5 : 1.0)
								} else {
									HStack(spacing: 4) {
										if isPendingWrite {
											ProgressView()
												.scaleEffect(0.8)
										}
										Text(isPendingWrite ? "Starting..." : "Start Visit")
											.font(.subheadline)
											.foregroundColor(Color(red: 184/255, green: 166/255, blue: 7/255))
									}
									.onTapGesture { 
										if !isPendingWrite {
											startVisit()
										}
									}
									.opacity(isPendingWrite ? 0.6 : 1.0)
								}
							}
							
							if isVisitStarted && !isVisitCompleted {
								Button(action: { 
									if !isPendingWrite {
										showCompleteConfirm = true
									}
								}) { 
									HStack(spacing: 4) {
										if isPendingWrite {
											ProgressView()
												.scaleEffect(0.7)
										}
										Text(isPendingWrite ? "Saving..." : "End Visit")
											.font(.subheadline)
									}
								}
								.buttonStyle(GhostButtonStyle())
								.controlSize(.small)
								.disabled(isPendingWrite)
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
						if isVisitStarted && !isVisitCompleted {
							HStack(spacing: 8) {
								HStack(spacing: 4) {
									Image(systemName: "timer")
										.font(.caption)
										.foregroundColor(Color(red: 184/255, green: 166/255, blue: 7/255))
									// Show elapsed time in collapsed view
									Text(elapsedTimeString)
										.font(.caption)
										.fontWeight(.bold)
										.foregroundColor(Color(red: 184/255, green: 166/255, blue: 7/255))
								}
								// Undo button in collapsed view
								Button(action: { 
									if !isPendingWrite {
										showUndoConfirm = true
									}
								}) {
									Image(systemName: "arrow.uturn.backward.circle.fill")
										.font(.caption)
										.foregroundColor(.orange)
								}
								.buttonStyle(PlainButtonStyle())
								.disabled(isPendingWrite)
							}
						} else if isVisitCompleted {
							VStack(alignment: .trailing, spacing: 2) {
								HStack(spacing: 4) {
									Image(systemName: "checkmark.circle.fill")
										.font(.caption)
										.foregroundColor(.blue)
									Text("Completed")
										.font(.caption)
										.fontWeight(.bold)
										.foregroundColor(.blue)
								}
								// Show actual duration in collapsed view for completed visits
								Text("Duration: \(elapsedTimeString)")
									.font(.caption2)
									.foregroundColor(.secondary)
							}
						}
					}
				}
			}
			.alert("Complete Visit?", isPresented: $showCompleteConfirm) {
                Button("Yes, Complete") { completeVisit() }
				Button("Back", role: .cancel) {}
			} message: {
				Text("you're about to mark this event as complete. Are you sure?")
			}
			.alert("Undo Timer?", isPresented: $showUndoConfirm) {
				Button("Yes, Reset Timer", role: .destructive) { undoStartVisit() }
				Button("Cancel", role: .cancel) {}
			} message: {
				Text("This will reset the visit timer back to 'Start Visit'. The visit will return to scheduled status and your check-in time will be removed.")
			}
			.alert("Error", isPresented: $showError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(errorMessage ?? "An error occurred. Please try again.")
			}
		}
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(Color(.systemBackground))
				.shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
		)
		.overlay(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.stroke(isVisitCompleted ? SPDesignSystem.Colors.success : Color.clear, lineWidth: 2)
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
	
	// Body just applies lifecycle modifiers to main content
	var body: some View {
		mainContent
			.onAppear {
				// Initialize timer state based on visit status
				// Activate timer if visit is started but not completed
				if actualStartTime != nil && actualEndTime == nil {
					isTimerActive = true
					AppLogger.timer.info("Timer initialized as active for visit \(visit.id)")
				} else {
					isTimerActive = false
					AppLogger.timer.info("Timer initialized as inactive for visit \(visit.id)")
				}
			}
			.onChange(of: actualStartTimes) { newDict in
				// Monitor the DICTIONARY directly (not the computed property)
				let newStartTime = newDict[visit.id]
				let newEndTime = actualEndTimes[visit.id]
				
				if newStartTime != nil && newEndTime == nil && !isPendingWrite {
					isTimerActive = true
					AppLogger.timer.info("Timer activated by dictionary update for visit \(visit.id)")
				} else if newStartTime == nil {
					isTimerActive = false
					AppLogger.timer.info("Timer deactivated because actualStartTime was cleared from dictionary for visit \(visit.id)")
				}
			}
			.onChange(of: actualEndTimes) { newDict in
				// Monitor the DICTIONARY directly (not the computed property)
				let newEndTime = newDict[visit.id]
				
				if newEndTime != nil {
					isTimerActive = false
					AppLogger.timer.info("Timer deactivated by dictionary update - visit completed \(visit.id)")
				}
			}
			.onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
				// ONLY tick if timer is explicitly active
				// This ensures instant stop when isTimerActive is set to false
				if isTimerActive { 
					tick = now
					
					// Send 5-minute warning notification (only once per visit)
					if isFiveMinuteWarning && !fiveMinuteWarningSent {
						fiveMinuteWarningSent = true
						AppLogger.ui.warning("Sending 5-minute warning for visit \(visit.id)")
						NotificationService.shared.sendLocalNotification(
							title: "Visit Ending Soon",
							body: "Your visit with \(visit.clientName) scheduled end is in 5 minutes",
							userInfo: ["visitId": visit.id, "type": "visit_warning"]
						)
					}
				}
			}
	}

	private func openInMaps() {
		// Use Apple Maps with navigation to the pet owner's address
		// Format: maps://?daddr=[address]&dirflg=d
		// dirflg=d enables driving directions
		
		AppLogger.ui.debug("DEBUG openInMaps - visit.address RAW value: '\(visit.address)'")
		
		let addressToUse = visit.address.trimmingCharacters(in: .whitespacesAndNewlines)
		
		AppLogger.ui.debug("DEBUG openInMaps - addressToUse after trim: '\(addressToUse)' (isEmpty: \(addressToUse.isEmpty))")
		
		guard !addressToUse.isEmpty else {
			AppLogger.ui.warning("No address available for navigation for visit \(visit.id)")
			AppLogger.ui.info("No address - Client: \(visit.clientName), Service: \(visit.serviceSummary)")
			return
		}
		
		// Properly encode the address for URL
		let encoded = addressToUse.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? addressToUse
		
		// Try to open in Apple Maps app with navigation mode
		if let url = URL(string: "maps://?daddr=\(encoded)&dirflg=d") {
			AppLogger.ui.info("Opening Maps to: \(addressToUse)")
			UIApplication.shared.open(url, options: [:]) { success in
				if !success {
					AppLogger.ui.error("Failed to open Apple Maps")
					// Fallback to Apple Maps web
					if let webUrl = URL(string: "http://maps.apple.com/?daddr=\(encoded)&dirflg=d") {
						UIApplication.shared.open(webUrl)
					}
				}
			}
		}
	}

	private func startVisit() {
		// OPTIMISTICALLY SET ACTUAL START TIME IMMEDIATELY
		// This ensures TIME LEFT countdown starts from full duration (e.g., 15:00)
		let now = Date()
		actualStartTimes[visit.id] = now
		
		// SYNC TICK IMMEDIATELY to prevent calculation mismatch
		tick = now
		
		// ACTIVATE TIMER IMMEDIATELY for instant UI countdown
		isTimerActive = true
		
		// Mark as pending write for visual feedback
		pendingWrites.insert(visit.id)
		
		AppLogger.ui.info("Starting visit: \(visit.id) at \(Date())")
		AppLogger.timer.info("Timer activated - isTimerActive = true")
		AppLogger.ui.info("Optimistically set actualStartTime for immediate countdown")
		
		// Update Firestore - the UI will update automatically via realtime listener
		let db = Firestore.firestore()
		
		// Use updateData with dot notation for proper nested field updates
		db.collection("visits").document(visit.id).updateData([
			"status": VisitStatus.inAdventure.rawValue,
			"timeline.checkIn.timestamp": FieldValue.serverTimestamp(),
			"startedAt": FieldValue.serverTimestamp()
		]) { error in
			// Remove from pending writes
			pendingWrites.remove(visit.id)
			
			if let error = error {
				AppLogger.ui.error("Error starting visit: \(error.localizedDescription)")
				AppLogger.data.error("Error code: \((error as NSError).code), domain: \((error as NSError).domain)")
				// DEACTIVATE TIMER on error
				isTimerActive = false
				// REMOVE OPTIMISTIC START TIME on error
				actualStartTimes.removeValue(forKey: visit.id)
				AppLogger.timer.info("Timer deactivated and actualStartTime removed due to error")
				errorMessage = ErrorMapper.userFriendlyMessage(for: error)
				showError = true
			} else {
				AppLogger.ui.info("Visit started successfully: \(visit.id)")
				AppLogger.data.info("Wrote timeline.checkIn.timestamp to Firestore using updateData")
				LocationService.shared.startVisitTracking()
			}
		}
	}

	private func undoStartVisit() {
		showUndoConfirm = false
		
		// Store the current actual start time in case we need to restore it on error
		let previousStartTime = actualStartTimes[visit.id]
		let wasTimerActive = isTimerActive
		
		// DEACTIVATE TIMER IMMEDIATELY - THIS STOPS THE COUNTDOWN
		isTimerActive = false
		
		// Optimistically remove actual start time IMMEDIATELY for instant UI update
		// Force SwiftUI to detect the change by reassigning the entire dictionary
		var updatedTimes = actualStartTimes
		updatedTimes.removeValue(forKey: visit.id)
		actualStartTimes = updatedTimes
		
		// Reset tick to current time
		tick = Date()
		
		// Reset warning flag immediately
		fiveMinuteWarningSent = false
		
		// Mark as pending write for visual feedback
		pendingWrites.insert(visit.id)
		
		AppLogger.ui.info("Undoing visit start: \(visit.id) at \(Date())")
		AppLogger.timer.info("Timer deactivated - isTimerActive = false")
		AppLogger.ui.info("Removed actualStartTime, isVisitStarted should now be false")
		
		// Update Firestore - reset to scheduled status and remove timeline
		let db = Firestore.firestore()
		db.collection("visits").document(visit.id).updateData([
			"status": VisitStatus.scheduled.rawValue,
			"timeline.checkIn": FieldValue.delete(),
			"startedAt": FieldValue.delete()
		]) { error in
			// Remove from pending writes
			pendingWrites.remove(visit.id)
			
			if let error = error {
				AppLogger.ui.error("Error undoing visit start: \(error.localizedDescription)")
				// Restore the actual start time and timer state since the undo failed
				if let previousTime = previousStartTime {
					var restoredTimes = actualStartTimes
					restoredTimes[visit.id] = previousTime
					actualStartTimes = restoredTimes
				}
				isTimerActive = wasTimerActive
				AppLogger.ui.info("Restored timer state due to error")
				errorMessage = ErrorMapper.userFriendlyMessage(for: error)
				showError = true
			} else {
				AppLogger.ui.info("Visit timer reset successfully: \(visit.id)")
				// Stop location tracking since visit is no longer in progress
				LocationService.shared.stopVisitTracking()
			}
		}
	}
	
	private func completeVisit() {
		showCompleteConfirm = false
		
		// DEACTIVATE TIMER since visit is being completed
		isTimerActive = false
		
		// Mark as pending write for visual feedback
		pendingWrites.insert(visit.id)
		
		AppLogger.timer.info("Completing visit: \(visit.id) at \(Date())")
		AppLogger.timer.info("Timer deactivated - visit completed")
		
		// Update Firestore - the UI will update automatically via realtime listener
		let db = Firestore.firestore()
		
		// Build update dictionary
		var update: [String: Any] = [
			"status": VisitStatus.completed.rawValue,
			"timeline.checkOut.timestamp": FieldValue.serverTimestamp()
		]
		
		if !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			update["pendingMessage"] = [
				"text": draftText,
				"status": "pending_admin",
				"createdAt": FieldValue.serverTimestamp()
			]
		}
		
		// Use updateData with dot notation for proper nested field updates
		db.collection("visits").document(visit.id).updateData(update) { error in
			// Remove from pending writes
			pendingWrites.remove(visit.id)
			
			if let error = error {
				AppLogger.ui.error("Error completing visit: \(error.localizedDescription)")
				AppLogger.data.error("Error code: \((error as NSError).code), domain: \((error as NSError).domain)")
				errorMessage = ErrorMapper.userFriendlyMessage(for: error)
				showError = true
			} else {
				AppLogger.ui.info("Visit completed successfully: \(visit.id)")
				AppLogger.data.info("Wrote timeline.checkOut.timestamp to Firestore using updateData")
				LocationService.shared.stopVisitTracking()
			}
		}
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
        return DateFormatters.shared.fullDateFormatter.string(from: dailyHours.date)
    }
    
    private var formattedStartTime: String {
        guard let startTime = dailyHours.firstVisitStart else { return "N/A" }
        return DateFormatters.shared.shortTimeFormatter.string(from: startTime)
    }
    
    private var formattedEndTime: String {
        guard let endTime = dailyHours.lastVisitEnd else { return "N/A" }
        return DateFormatters.shared.shortTimeFormatter.string(from: endTime)
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

// Modern NewMessageView is now in ModernChatView.swift

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

