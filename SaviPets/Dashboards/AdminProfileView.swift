import SwiftUI
import FirebaseAuth
import LocalAuthentication

struct AdminProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var securityService = AdminSecurityService()
    @State private var showingSecuritySettings = false
    @State private var showingPasswordChange = false
    @State private var showingAuditLogs = false
    @State private var showingSecurityReport = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChangingPassword = false
    @State private var passwordError: String?
    @State private var showingMFA = false
    @State private var sessionTimeRemaining: TimeInterval = 0
    @State private var sessionTimer: Timer?
    
    private var email: String { appState.authService.currentUser?.email ?? "" }
    private var display: String {
        if let d = appState.displayName, !d.isEmpty { return d }
        let part = email.split(separator: "@").first.map(String.init) ?? ""
        return part.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: SPDesignSystem.Spacing.l) {
                    // Profile Header
                    profileHeader
                    
                    // Security Status
                    securityStatusSection
                    
                    // Account Information
                    accountInformationSection
                    
                    // Security Settings
                    securitySettingsSection
                    
                    // Session Management
                    sessionManagementSection
                    
                    // Security Actions
                    securityActionsSection
                    
                    // Audit & Monitoring
                    auditMonitoringSection
                }
                .padding()
            }
            .navigationTitle("Admin Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                startSessionTimer()
                securityService.updateActivity()
            }
            .onDisappear {
                sessionTimer?.invalidate()
            }
            .sheet(isPresented: $showingSecuritySettings) {
                SecuritySettingsView(securityService: securityService)
            }
            .sheet(isPresented: $showingPasswordChange) {
                passwordChangeSheet
            }
            .sheet(isPresented: $showingAuditLogs) {
                AuditLogsView(securityService: securityService)
            }
            .sheet(isPresented: $showingSecurityReport) {
                SecurityReportView(securityService: securityService)
            }
            .alert("MFA Required", isPresented: $showingMFA) {
                Button("Authenticate") {
                    authenticateWithMFA()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Multi-factor authentication is required for this action.")
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: SPDesignSystem.Spacing.m) {
            // Avatar
            Circle()
                .fill(SPDesignSystem.Colors.primaryAdjusted(.light))
                .frame(width: 100, height: 100)
                .overlay(
                    Text(display.prefix(1).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                )
            
            VStack(spacing: 4) {
                Text(display)
                    .font(SPDesignSystem.Typography.heading2())
                    .fontWeight(.bold)
                
                Text(email)
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.secondary)
                
                Text("Administrator")
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SPDesignSystem.Spacing.l)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(16)
    }
    
    // MARK: - Security Status Section
    
    private var securityStatusSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Security Status")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            VStack(spacing: SPDesignSystem.Spacing.s) {
                // Security Level
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(securityLevelColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Security Level")
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                        Text(securityService.securityLevel.rawValue)
                            .font(SPDesignSystem.Typography.body())
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(securityLevelColor)
                        .frame(width: 12, height: 12)
                }
                
                // MFA Status
                HStack {
                    Image(systemName: securityService.securityLevel.requiresMFA ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .foregroundColor(securityService.securityLevel.requiresMFA ? .green : .red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Multi-Factor Authentication")
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                        Text(securityService.securityLevel.requiresMFA ? "Enabled" : "Disabled")
                            .font(SPDesignSystem.Typography.body())
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                
                // Session Status
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Session Timeout")
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                        Text(formatSessionTimeout(securityService.securityLevel.sessionTimeout))
                            .font(SPDesignSystem.Typography.body())
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                
                // Risk Score
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(riskScoreColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Security Risk Score")
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                        Text("\(securityService.generateSecurityReport().riskScore)/100")
                            .font(SPDesignSystem.Typography.body())
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    // MARK: - Account Information Section
    
    private var accountInformationSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Account Information")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            VStack(spacing: SPDesignSystem.Spacing.s) {
                AdminInfoRow(label: "Name", value: display)
                AdminInfoRow(label: "Email", value: email)
                AdminInfoRow(label: "Role", value: "Administrator")
                AdminInfoRow(label: "Last Login", value: formatDate(securityService.currentUser?.lastLogin ?? Date()))
                AdminInfoRow(label: "Account Status", value: securityService.currentUser?.isActive == true ? "Active" : "Inactive")
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    // MARK: - Security Settings Section
    
    private var securitySettingsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Security Settings")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            VStack(spacing: SPDesignSystem.Spacing.s) {
                SecurityActionRow(
                    icon: "key.fill",
                    title: "Change Password",
                    description: "Update your account password",
                    action: { showingPasswordChange = true }
                )
                
                SecurityActionRow(
                    icon: "shield.checkerboard",
                    title: "Two-Factor Authentication",
                    description: securityService.securityLevel.requiresMFA ? "Manage 2FA settings" : "Enable two-factor authentication",
                    action: { showingMFA = true }
                )
                
                SecurityActionRow(
                    icon: "gearshape.fill",
                    title: "Security Settings",
                    description: "Configure security preferences",
                    action: { showingSecuritySettings = true }
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    // MARK: - Session Management Section
    
    private var sessionManagementSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Session Management")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            VStack(spacing: SPDesignSystem.Spacing.s) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Session Time Remaining")
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                        Text(formatTimeRemaining(sessionTimeRemaining))
                            .font(SPDesignSystem.Typography.body())
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    Button("Extend") {
                        securityService.extendSession()
                        updateSessionTimeRemaining()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                HStack {
                    Image(systemName: "person.fill.checkmark")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Activity")
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                        Text(formatDate(securityService.lastActivity))
                            .font(SPDesignSystem.Typography.body())
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    // MARK: - Security Actions Section
    
    private var securityActionsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Security Actions")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            VStack(spacing: SPDesignSystem.Spacing.s) {
                SecurityActionRow(
                    icon: "doc.text.fill",
                    title: "View Audit Logs",
                    description: "Review security events and activities",
                    action: { showingAuditLogs = true }
                )
                
                SecurityActionRow(
                    icon: "chart.bar.fill",
                    title: "Security Report",
                    description: "View comprehensive security analysis",
                    action: { showingSecurityReport = true }
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    // MARK: - Audit & Monitoring Section
    
    private var auditMonitoringSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Recent Security Events")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            if securityService.adminAuditLogs.isEmpty {
                Text("No recent security events")
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(SPDesignSystem.Spacing.l)
            } else {
                LazyVStack(spacing: SPDesignSystem.Spacing.s) {
                    ForEach(securityService.adminAuditLogs.prefix(5)) { log in
                        AuditLogRow(log: log)
                    }
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    // MARK: - Password Change Sheet
    
    private var passwordChangeSheet: some View {
        NavigationStack {
            VStack(spacing: SPDesignSystem.Spacing.l) {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("Change Password")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                    
                    Text("Enter your current password and choose a new secure password.")
                        .font(SPDesignSystem.Typography.body())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: SPDesignSystem.Spacing.m) {
                    SecureField("Current Password", text: $currentPassword)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("New Password", text: $newPassword)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
                
                if let error = passwordError {
                    Text(error)
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                Button(action: changePassword) {
                    HStack {
                        if isChangingPassword {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isChangingPassword ? "Changing..." : "Change Password")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(isChangingPassword || currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
            }
            .padding()
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingPasswordChange = false
                        resetPasswordFields()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var securityLevelColor: Color {
        switch securityService.securityLevel {
        case .basic: return .green
        case .standard: return .blue
        case .high: return .orange
        case .maximum: return .red
        }
    }
    
    private var riskScoreColor: Color {
        let riskScore = securityService.generateSecurityReport().riskScore
        if riskScore < 30 { return .green }
        else if riskScore < 70 { return .orange }
        else { return .red }
    }
    
    private func formatSessionTimeout(_ timeout: TimeInterval) -> String {
        let minutes = Int(timeout / 60)
        return "\(minutes) minutes"
    }
    
    private func formatTimeRemaining(_ timeRemaining: TimeInterval) -> String {
        let minutes = Int(timeRemaining / 60)
        let seconds = Int(timeRemaining.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func startSessionTimer() {
        sessionTimer?.invalidate()
        updateSessionTimeRemaining()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateSessionTimeRemaining()
        }
    }
    
    private func updateSessionTimeRemaining() {
        let timeSinceLastActivity = Date().timeIntervalSince(securityService.lastActivity)
        sessionTimeRemaining = max(0, securityService.securityLevel.sessionTimeout - timeSinceLastActivity)
    }
    
    private func authenticateWithMFA() {
        securityService.authenticateWithMFA { result in
            switch result {
            case .success:
                // MFA successful, proceed with action
                break
            case .failure(let error):
                passwordError = error.localizedDescription
            }
        }
    }
    
    private func changePassword() {
        guard newPassword == confirmPassword else {
            passwordError = "New passwords do not match"
            return
        }
        
        guard newPassword.count >= 8 else {
            passwordError = "Password must be at least 8 characters long"
            return
        }
        
        isChangingPassword = true
        passwordError = nil
        
        securityService.changePassword(currentPassword: currentPassword, newPassword: newPassword) { result in
            DispatchQueue.main.async {
                isChangingPassword = false
                
                switch result {
                case .success:
                    showingPasswordChange = false
                    resetPasswordFields()
                case .failure(let error):
                    passwordError = error.localizedDescription
                }
            }
        }
    }
    
    private func resetPasswordFields() {
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
        passwordError = nil
    }
}

// MARK: - Supporting Views

struct AdminInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(SPDesignSystem.Typography.body())
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

struct SecurityActionRow: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SPDesignSystem.Spacing.s) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SPDesignSystem.Typography.body())
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(SPDesignSystem.Spacing.s)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AuditLogRow: View {
    let log: AdminAuditLogEntry
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
            Image(systemName: severityIcon)
                .font(.caption)
                .foregroundColor(log.severity.color)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(log.event.description)
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(formatDate(log.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(log.severity.rawValue.capitalized)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(log.severity.color)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
    
    private var severityIcon: String {
        switch log.severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Security Settings View

struct SecuritySettingsView: View {
    @ObservedObject var securityService: AdminSecurityService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: SPDesignSystem.Spacing.l) {
                Text("Security Settings")
                    .font(SPDesignSystem.Typography.heading2())
                    .fontWeight(.bold)
                
                Text("Configure your security preferences and access levels.")
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Text("Security settings will be implemented in the next phase.")
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Security Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Audit Logs View

struct AuditLogsView: View {
    @ObservedObject var securityService: AdminSecurityService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(securityService.adminAuditLogs) { log in
                    AuditLogRow(log: log)
                }
            }
            .navigationTitle("Audit Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Security Report View

struct SecurityReportView: View {
    @ObservedObject var securityService: AdminSecurityService
    @Environment(\.dismiss) private var dismiss
    
    private var report: AdminSecurityReport {
        securityService.generateSecurityReport()
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SPDesignSystem.Spacing.l) {
                    Text("Security Report")
                        .font(SPDesignSystem.Typography.heading2())
                        .fontWeight(.bold)
                    
                    VStack(spacing: SPDesignSystem.Spacing.m) {
                        ReportMetricCard(title: "Total Events", value: "\(report.totalEvents)", color: .blue)
                        ReportMetricCard(title: "Failed Logins", value: "\(report.failedLogins)", color: .red)
                        ReportMetricCard(title: "Successful Logins", value: "\(report.successfulLogins)", color: .green)
                        ReportMetricCard(title: "Security Alerts", value: "\(report.securityAlerts)", color: .orange)
                        ReportMetricCard(title: "Risk Score", value: "\(report.riskScore)/100", color: riskScoreColor)
                    }
                }
                .padding()
            }
            .navigationTitle("Security Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var riskScoreColor: Color {
        if report.riskScore < 30 { return .green }
        else if report.riskScore < 70 { return .orange }
        else { return .red }
    }
}

struct ReportMetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(SPDesignSystem.Typography.body())
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}


