import SwiftUI
import FirebaseFirestore

struct AdminClientsView: View {
    @State private var clients: [ClientItem] = []
    @State private var showAdd: Bool = false
    @State private var isLoading: Bool = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(clients) { c in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.name).font(.headline)
                        Text(c.email).font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
            .overlay {
                if isLoading { ProgressView().controlSize(.large) }
                if !isLoading && clients.isEmpty { if #available(iOS 17.0, *) {
                    ContentUnavailableView("No clients", systemImage: "person.3", description: Text("Tap + to add your first client."))
                } else {
                    // Fallback on earlier versions
                } }
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
        Firestore.firestore().collection("clients")
            .order(by: "name")
            .addSnapshotListener { snap, err in
                isLoading = false
                guard err == nil, let snap else { self.clients = []; return }
                self.clients = snap.documents.map { d in
                    let data = d.data()
                    return ClientItem(id: d.documentID, name: data["name"] as? String ?? "Unnamed", email: data["email"] as? String ?? "")
                }
            }
    }
}

private struct ClientItem: Identifiable { let id: String; let name: String; let email: String }

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
