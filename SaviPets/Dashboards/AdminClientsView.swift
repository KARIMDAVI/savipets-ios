import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AdminClientsView: View {
    @State private var owners: [ClientItem] = []
    @State private var leads: [ClientItem] = []
    @State private var rawLeads: [ClientItem] = []
    @State private var showAdd: Bool = false
    @State private var isLoading: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Pet Owners") {
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
            .navigationTitle("Clients")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAdd = true }) { Image(systemName: "plus") }
                }
            }
            .onAppear(perform: subscribe)
            .sheet(isPresented: $showAdd) { AddClientSheet(onAdded: {}) }
        }
    }

    private func subscribe() {
        isLoading = true
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("role", isEqualTo: SPDesignSystem.Roles.petOwner)
            .addSnapshotListener { snap, err in
                isLoading = false
                guard err == nil, let snap else { self.owners = []; return }
                var items: [ClientItem] = snap.documents.map { d in
                    let data = d.data()
                    let email = (data["email"] as? String) ?? ""
                    let emailFallback = email.split(separator: "@").first.map(String.init) ?? "Unnamed"
                    let rawName = (data["displayName"] as? String) ?? (data["name"] as? String) ?? ""
                    let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emailFallback : rawName
                    return ClientItem(id: d.documentID, name: name, email: email, petNames: nil)
                }
                // Sort by name client-side for stable UI
                items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.owners = items
                // Load pet names for each owner (best-effort)
                for owner in items { loadPetNames(forOwnerId: owner.id) }
                // Recompute leads dedup after owners change
                applyLeadsDedup()
            }

        // Legacy clients (leads)
        db.collection("clients")
            .addSnapshotListener { snap, err in
                guard err == nil, let snap else { self.rawLeads = []; self.leads = []; return }
                var items: [ClientItem] = snap.documents.map { d in
                    let data = d.data()
                    let name = (data["name"] as? String) ?? "Unnamed"
                    let email = (data["email"] as? String) ?? ""
                    return ClientItem(id: d.documentID, name: name, email: email, petNames: nil)
                }
                items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.rawLeads = items
                applyLeadsDedup()
            }
    }

    private let appIdConst: String = AppConstants.Firebase.appId // matches PetDataService default

    private func loadPetNames(forOwnerId ownerId: String) {
        let path = "artifacts/\(appIdConst)/users/\(ownerId)/pets"
        Firestore.firestore().collection(path).getDocuments { snap, _ in
            let names: [String] = snap?.documents.compactMap { $0.data()["name"] as? String } ?? []
            let joined = names.joined(separator: ", ")
            DispatchQueue.main.async {
                if let idx = self.owners.firstIndex(where: { $0.id == ownerId }) {
                    self.owners[idx].petNames = joined
                }
            }
        }
    }

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
