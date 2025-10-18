import SwiftUI
import FirebaseFirestore

struct AdminCollaborationDashboard: View {
    @StateObject private var collaborationService = AdminCollaborationService()
    @State private var selectedTab: CollaborationTab = .team
    @State private var showingNewMessage = false
    @State private var showingNotifications = false
    @State private var showingPresenceMenu = false
    @State private var newMessageText = ""
    @State private var selectedPriority: MessagePriority = .normal
    @State private var showingScreenShare = false
    @State private var showingWorkspaceManager = false
    
    enum CollaborationTab: String, CaseIterable {
        case team = "Team"
        case activities = "Activities"
        case workspaces = "Workspaces"
        case notifications = "Notifications"
        
        var icon: String {
            switch self {
            case .team: return "person.2.fill"
            case .activities: return "chart.bar.fill"
            case .workspaces: return "folder.fill"
            case .notifications: return "bell.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with presence indicator
                collaborationHeader
                
                // Tab selector
                tabSelector
                
                // Main content
                TabView(selection: $selectedTab) {
                    teamTab
                        .tag(CollaborationTab.team)
                    
                    activitiesTab
                        .tag(CollaborationTab.activities)
                    
                    workspacesTab
                        .tag(CollaborationTab.workspaces)
                    
                    notificationsTab
                        .tag(CollaborationTab.notifications)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Team Collaboration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Presence indicator
                        Button(action: { showingPresenceMenu.toggle() }) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(collaborationService.currentUserPresence.color)
                                    .frame(width: 8, height: 8)
                                Text(collaborationService.currentUserPresence.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Notifications badge
                        Button(action: { showingNotifications.toggle() }) {
                            ZStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.primary)
                                
                                if !collaborationService.notifications.filter({ !$0.isRead }).isEmpty {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                        
                        // New message button
                        Button(action: { showingNewMessage.toggle() }) {
                            Image(systemName: "plus.message.fill")
                                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewMessage) {
                newMessageSheet
            }
            .sheet(isPresented: $showingNotifications) {
                notificationsSheet
            }
            .confirmationDialog("Update Presence", isPresented: $showingPresenceMenu) {
                Button("Available") { collaborationService.setAvailable() }
                Button("Away") { collaborationService.setAway() }
                Button("Busy") { collaborationService.setBusy() }
                Button("Offline") { collaborationService.goOffline() }
                Button("Cancel", role: .cancel) { }
            }
            .onAppear {
                collaborationService.updatePresence(.available)
            }
            .onDisappear {
                collaborationService.goOffline()
            }
        }
    }
    
    // MARK: - Header
    
    private var collaborationHeader: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Team Collaboration")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.bold)
                    
                    Text("\(collaborationService.activeUsers.count) team members online")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Quick actions
                HStack(spacing: SPDesignSystem.Spacing.s) {
                    Button(action: { showingScreenShare.toggle() }) {
                        Image(systemName: "rectangle.and.pencil.and.ellipsis")
                            .font(.title3)
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                    }
                    
                    Button(action: { showingWorkspaceManager.toggle() }) {
                        Image(systemName: "folder.badge.plus")
                            .font(.title3)
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                    }
                }
            }
            
            // Online users preview
            if !collaborationService.activeUsers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SPDesignSystem.Spacing.s) {
                        ForEach(collaborationService.activeUsers.prefix(8)) { user in
                            UserPresenceIndicator(user: user)
                        }
                        
                        if collaborationService.activeUsers.count > 8 {
                            Text("+\(collaborationService.activeUsers.count - 8) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, SPDesignSystem.Spacing.m)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(CollaborationTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == tab ? SPDesignSystem.Colors.primaryAdjusted(.light) : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SPDesignSystem.Spacing.s)
                }
            }
        }
        .background(SPDesignSystem.Colors.surface(.light))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - Team Tab
    
    private var teamTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                // Recent messages
                if !collaborationService.teamMessages.isEmpty {
                    VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                        Text("Recent Messages")
                            .font(SPDesignSystem.Typography.heading3())
                            .fontWeight(.semibold)
                            .padding(.horizontal, SPDesignSystem.Spacing.m)
                        
                        ForEach(collaborationService.teamMessages.prefix(10)) { message in
                            TeamMessageCard(message: message, collaborationService: collaborationService)
                        }
                    }
                } else {
                    CollaborationEmptyStateView(
                        icon: "message.fill",
                        title: "No Messages Yet",
                        message: "Start a conversation with your team",
                        actionTitle: "Send Message",
                        action: { showingNewMessage = true }
                    )
                }
            }
            .padding(.vertical, SPDesignSystem.Spacing.m)
        }
    }
    
    // MARK: - Activities Tab
    
    private var activitiesTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                // Live activities
                if !collaborationService.liveActivities.isEmpty {
                    VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                        Text("Live Activities")
                            .font(SPDesignSystem.Typography.heading3())
                            .fontWeight(.semibold)
                            .padding(.horizontal, SPDesignSystem.Spacing.m)
                        
                        ForEach(collaborationService.liveActivities) { activity in
                            LiveActivityCard(activity: activity)
                        }
                    }
                }
                
                // Activity types
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("Start Activity")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .padding(.horizontal, SPDesignSystem.Spacing.m)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: SPDesignSystem.Spacing.s) {
                        ForEach(LiveActivityType.allCases, id: \.self) { activityType in
                            ActivityTypeCard(activityType: activityType, collaborationService: collaborationService)
                        }
                    }
                    .padding(.horizontal, SPDesignSystem.Spacing.m)
                }
            }
            .padding(.vertical, SPDesignSystem.Spacing.m)
        }
    }
    
    // MARK: - Workspaces Tab
    
    private var workspacesTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                if !collaborationService.sharedWorkspaces.isEmpty {
                    VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                        Text("Shared Workspaces")
                            .font(SPDesignSystem.Typography.heading3())
                            .fontWeight(.semibold)
                            .padding(.horizontal, SPDesignSystem.Spacing.m)
                        
                        ForEach(collaborationService.sharedWorkspaces) { workspace in
                            WorkspaceCard(workspace: workspace)
                        }
                    }
                } else {
                    CollaborationEmptyStateView(
                        icon: "folder.fill",
                        title: "No Workspaces",
                        message: "Create a shared workspace to collaborate with your team",
                        actionTitle: "Create Workspace",
                        action: { showingWorkspaceManager = true }
                    )
                }
            }
            .padding(.vertical, SPDesignSystem.Spacing.m)
        }
    }
    
    // MARK: - Notifications Tab
    
    private var notificationsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.s) {
                if !collaborationService.notifications.isEmpty {
                    ForEach(collaborationService.notifications) { notification in
                        NotificationCard(notification: notification, collaborationService: collaborationService)
                    }
                } else {
                    CollaborationEmptyStateView(
                        icon: "bell.fill",
                        title: "No Notifications",
                        message: "You're all caught up!",
                        actionTitle: nil,
                        action: nil
                    )
                }
            }
            .padding(SPDesignSystem.Spacing.m)
        }
    }
    
    // MARK: - Sheets
    
    private var newMessageSheet: some View {
        NavigationStack {
            VStack(spacing: SPDesignSystem.Spacing.l) {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("Send Team Message")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                    
                    Text("Share updates, ask questions, or coordinate with your team.")
                        .font(SPDesignSystem.Typography.body())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: SPDesignSystem.Spacing.m) {
                    TextField("Type your message...", text: $newMessageText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    
                    HStack {
                        Text("Priority:")
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                        
                        Picker("Priority", selection: $selectedPriority) {
                            ForEach(MessagePriority.allCases, id: \.self) { priority in
                                Text(priority.rawValue.capitalized).tag(priority)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                
                Spacer()
                
                Button(action: sendMessage) {
                    Text("Send Message")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingNewMessage = false
                        newMessageText = ""
                    }
                }
            }
        }
    }
    
    private var notificationsSheet: some View {
        NavigationStack {
            List {
                ForEach(collaborationService.notifications) { notification in
                    NotificationCard(notification: notification, collaborationService: collaborationService)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showingNotifications = false }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        collaborationService.sendTeamMessage(newMessageText, priority: selectedPriority)
        newMessageText = ""
        showingNewMessage = false
    }
}

// MARK: - Supporting Views

struct UserPresenceIndicator: View {
    let user: ActiveUser
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(SPDesignSystem.Colors.surface(.light))
                    .frame(width: 40, height: 40)
                
                Text(user.userName.prefix(1).uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Circle()
                    .fill(user.presence.color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: 14, y: -14)
            }
            
            Text(user.userName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 60)
    }
}

struct TeamMessageCard: View {
    let message: TeamMessage
    let collaborationService: AdminCollaborationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.senderName)
                        .font(SPDesignSystem.Typography.footnote())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Priority indicator
                Circle()
                    .fill(message.priority.color)
                    .frame(width: 8, height: 8)
            }
            
            Text(message.content)
                .font(SPDesignSystem.Typography.body())
                .foregroundColor(.primary)
            
            // Reactions
            if !message.reactions.isEmpty {
                HStack(spacing: 4) {
                    ForEach(message.reactions, id: \.userId) { reaction in
                        Text(reaction.reaction.rawValue)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
        .padding(.horizontal, SPDesignSystem.Spacing.m)
        .onTapGesture {
            collaborationService.markMessageAsRead(message.id)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct LiveActivityCard: View {
    let activity: LiveActivity
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
            Image(systemName: activity.activityType.icon)
                .font(.title3)
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.userName)
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(activity.activityType.description)
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatDuration(activity.startTime))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
        .padding(.horizontal, SPDesignSystem.Spacing.m)
    }
    
    private func formatDuration(_ startTime: Date) -> String {
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration / 60)
        return "\(minutes)m"
    }
}

struct ActivityTypeCard: View {
    let activityType: LiveActivityType
    let collaborationService: AdminCollaborationService
    
    var body: some View {
        Button(action: { startActivity() }) {
            VStack(spacing: SPDesignSystem.Spacing.s) {
                Image(systemName: activityType.icon)
                    .font(.title2)
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                
                Text(activityType.description)
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(SPDesignSystem.Spacing.m)
            .background(SPDesignSystem.Colors.surface(.light))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func startActivity() {
        collaborationService.startLiveActivity(activityType)
    }
}

struct WorkspaceCard: View {
    let workspace: SharedWorkspace
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Text(workspace.name)
                    .font(SPDesignSystem.Typography.heading3())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(workspace.members.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(workspace.description)
                .font(SPDesignSystem.Typography.body())
                .foregroundColor(.secondary)
            
            HStack {
                Text("Created by \(workspace.createdByName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatDate(workspace.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
        .padding(.horizontal, SPDesignSystem.Spacing.m)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct NotificationCard: View {
    let notification: CollaborationNotification
    let collaborationService: AdminCollaborationService
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
            Image(systemName: notificationIcon)
                .font(.title3)
                .foregroundColor(notification.priority.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(notification.message)
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(notification.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(notification.isRead ? Color.clear : Color.blue.opacity(0.1))
        .cornerRadius(12)
        .onTapGesture {
            collaborationService.markNotificationAsRead(notification.id)
        }
    }
    
    private var notificationIcon: String {
        switch notification.type {
        case .message: return "message.fill"
        case .mention: return "at"
        case .system: return "gear"
        case .collaboration: return "person.2.fill"
        case .screenShare: return "rectangle.and.pencil.and.ellipsis"
        case .workspace: return "folder.fill"
        case .alert: return "exclamationmark.triangle.fill"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CollaborationEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: SPDesignSystem.Spacing.s) {
                Text(title)
                    .font(SPDesignSystem.Typography.heading3())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                        .padding(.horizontal, SPDesignSystem.Spacing.l)
                        .padding(.vertical, SPDesignSystem.Spacing.s)
                }
                .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(SPDesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}
