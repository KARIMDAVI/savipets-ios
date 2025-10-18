import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AdminClientsView: View {
    @State private var owners: [ClientItem] = []
    @State private var leads: [ClientItem] = []
    @State private var rawLeads: [ClientItem] = []
    @State private var showAdd: Bool = false
    @State private var isLoading: Bool = false
    @State private var showingEnhancedCRM = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced CRM Header
                enhancedCRMHeader
                
                // Original content
                List {
                    Section("Pet Parents") {
                        ForEach(owners) { c in
                            NavigationLink {
                                OwnerDetailView(ownerId: c.id, name: c.name, email: c.email)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(c.name).font(.headline)
                                    if let petNames = c.petNames, !petNames.isEmpty {
                                        Text(petNames)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(c.email)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    if !leads.isEmpty {
                        Section("Leads") {
                            ForEach(leads) { l in
                                NavigationLink { LeadDetailView(name: l.name, email: l.email) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(l.name).font(.headline)
                                        Text(l.email).font(.footnote).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .overlay {
                    if isLoading { ProgressView().controlSize(.large) }
                    if !isLoading && owners.isEmpty && leads.isEmpty {
                        if #available(iOS 17.0, *) {
                            ContentUnavailableView("No clients", systemImage: "person.3", description: Text("Tap + to add your first client."))
                        } else {
                            // Fallback on earlier versions
                        }
                    }
                }
            }
            .navigationTitle("Clients")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showAdd = true }) {
                            Label("Add Client", systemImage: "person.badge.plus")
                        }
                        
                        Button(action: { showingEnhancedCRM = true }) {
                            Label("Enhanced CRM", systemImage: "chart.bar.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear(perform: subscribe)
            .sheet(isPresented: $showAdd) { AddClientSheet(onAdded: {}) }
            .sheet(isPresented: $showingEnhancedCRM) {
                EnhancedAdminClientsView()
            }
        }
    }
    
    // MARK: - Enhanced CRM Header
    
    private var enhancedCRMHeader: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Client Management")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.bold)
                    
                    Text("\(owners.count) clients, \(leads.count) leads")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Quick stats
                HStack(spacing: SPDesignSystem.Spacing.m) {
                    CRMQuickStatCard(
                        title: "Active",
                        value: "\(owners.count)",
                        color: .green,
                        icon: "checkmark.circle.fill"
                    )
                    
                    CRMQuickStatCard(
                        title: "Leads",
                        value: "\(leads.count)",
                        color: .orange,
                        icon: "person.circle.fill"
                    )
                    
                    CRMQuickStatCard(
                        title: "Total",
                        value: "\(owners.count + leads.count)",
                        color: .blue,
                        icon: "person.2.fill"
                    )
                }
            }
            
            // Enhanced CRM Button
            Button(action: { showingEnhancedCRM = true }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.title3)
                    
                    Text("Open Enhanced CRM")
                        .font(SPDesignSystem.Typography.footnote())
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(SPDesignSystem.Spacing.m)
                .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                .cornerRadius(12)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
    }

    private func subscribe() {
        isLoading = true
        let db = Firestore.firestore()
        
        // Optimized query: Limit to 100 owners
        // NOTE: Cannot order by displayName as it may not exist on all documents
        // Instead, we'll sort client-side after loading
        db.collection("users")
            .whereField("role", isEqualTo: SPDesignSystem.Roles.petOwner)
            .limit(to: 100)
            .addSnapshotListener { snap, err in
                isLoading = false
                guard err == nil, let snap else { self.owners = []; return }
                
                // CRITICAL FIX: Process documentChanges to handle deletions properly
                // This ensures deleted documents are removed from the UI
                var currentOwners = self.owners
                
                for change in snap.documentChanges {
                    let d = change.document
                    let docId = d.documentID
                    
                    switch change.type {
                    case .added, .modified:
                        // Add or update the document
                        let data = d.data()
                        let email = (data["email"] as? String) ?? ""
                        let emailFallback = email.split(separator: "@").first.map(String.init) ?? "Unnamed"
                        let rawName = (data["displayName"] as? String) ?? (data["name"] as? String) ?? ""
                        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emailFallback : rawName
                        
                        // Get denormalized pet names directly from user document (no extra query!)
                        let petNamesArray = data["petNames"] as? [String] ?? []
                        let petNamesJoined = petNamesArray.isEmpty ? nil : petNamesArray.joined(separator: ", ")
                        
                        let newItem = ClientItem(id: docId, name: name, email: email, petNames: petNamesJoined)
                        
                        // Remove old version if exists, then add new
                        currentOwners.removeAll { $0.id == docId }
                        currentOwners.append(newItem)
                        
                    case .removed:
                        // DELETION FIX: Remove deleted documents from the array
                        currentOwners.removeAll { $0.id == docId }
                    }
                }
                
                // Sort by name client-side for stable UI
                currentOwners.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.owners = currentOwners
                
                // Recompute leads dedup after owners change
                applyLeadsDedup()
            }

        // Legacy clients (leads) - also limit and handle deletions
        db.collection("clients")
            .limit(to: 50)
            .addSnapshotListener { snap, err in
                guard err == nil, let snap else { self.rawLeads = []; self.leads = []; return }
                
                // CRITICAL FIX: Process documentChanges for leads too
                var currentLeads = self.rawLeads
                
                for change in snap.documentChanges {
                    let d = change.document
                    let docId = d.documentID
                    
                    switch change.type {
                    case .added, .modified:
                        let data = d.data()
                        let name = (data["name"] as? String) ?? "Unnamed"
                        let email = (data["email"] as? String) ?? ""
                        let newItem = ClientItem(id: docId, name: name, email: email, petNames: nil)
                        
                        currentLeads.removeAll { $0.id == docId }
                        currentLeads.append(newItem)
                        
                    case .removed:
                        // DELETION FIX: Remove deleted leads
                        currentLeads.removeAll { $0.id == docId }
                    }
                }
                
                currentLeads.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.rawLeads = currentLeads
                applyLeadsDedup()
            }
    }

    // REMOVED: loadPetNames() - now using denormalized petNames from user document
    // This eliminates 100+ individual Firestore queries!

    private func applyLeadsDedup() {
        let ownerEmails = Set(owners.map { $0.email.lowercased() })
        self.leads = rawLeads.filter { !$0.email.isEmpty && !ownerEmails.contains($0.email.lowercased()) }
    }
}

private struct ClientItem: Identifiable { let id: String; let name: String; let email: String; var petNames: String? }

private struct AddClientSheet: View {
    var onAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var note: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Client Info") {
                    TextField("Full Name", text: $name)
                    TextField("Email", text: $email)
                    TextField("Note (optional)", text: $note)
                }
                if let errorMessage { Text(errorMessage).foregroundColor(.red) }
            }
            .navigationTitle("Add Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await Firestore.firestore().collection("clients").addDocument(data: [
                "name": name,
                "email": email,
                "note": note,
                "createdAt": FieldValue.serverTimestamp()
            ])
            onAdded()
            dismiss()
        } catch let err {
            errorMessage = err.localizedDescription
        }
    }
}

// Simple owner detail view
private struct OwnerDetailView: View {
    let ownerId: String
    let name: String
    let email: String
    @State private var pets: [String] = []

    var body: some View {
        List {
            Section("Owner") {
                HStack { Text("Name"); Spacer(); Text(name).foregroundColor(.secondary) }
                HStack { Text("Email"); Spacer(); Text(email).foregroundColor(.secondary) }
            }
            Section("Pets") {
                if pets.isEmpty {
                    Text("No pets found").foregroundColor(.secondary)
                } else {
                    ForEach(pets, id: \.self) { Text($0) }
                }
            }
        }
        .navigationTitle("Client Info")
        .onAppear(perform: load)
    }

    private func load() {
        let appId = AppConstants.Firebase.appId
        let path = "artifacts/\(appId)/users/\(ownerId)/pets"
        Firestore.firestore().collection(path).getDocuments { snap, _ in
            let names = snap?.documents.compactMap { $0.data()["name"] as? String } ?? []
            self.pets = names
        }
    }
}

// Simple lead detail view
private struct LeadDetailView: View {
    let name: String
    let email: String
    var body: some View {
        List {
            Section("Lead") {
                HStack { Text("Name"); Spacer(); Text(name).foregroundColor(.secondary) }
                HStack { Text("Email"); Spacer(); Text(email).foregroundColor(.secondary) }
            }
        }
        .navigationTitle("Lead Info")
    }
}

// MARK: - Quick Stat Card Component

struct CRMQuickStatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(8)
    }
}
