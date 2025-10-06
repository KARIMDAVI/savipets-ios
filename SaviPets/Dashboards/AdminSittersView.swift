import SwiftUI
import FirebaseFirestore

struct AdminSittersView: View {
    @State private var sitters: [SitterItem] = []
    @StateObject private var sitterData = SitterDataService()
    @State private var isLoading: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Sitters") {
                    ForEach(sitters) { s in
                        NavigationLink {
                            SitterDetailView(sitterId: s.id, name: s.name, email: s.email)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(s.name).font(.headline)
                                Text(s.email).font(.footnote).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                if !sitterData.availableSitters.isEmpty {
                    Section("Active Sitters") {
                        ForEach(sitterData.availableSitters) { s in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(s.name).font(.headline)
                                    Text(s.email).font(.footnote).foregroundColor(.secondary)
                                }
                                Spacer()
                                if s.isActive { Circle().fill(Color.green).frame(width: 10, height: 10) }
                            }
                        }
                    }
                }
            }
            .overlay {
                if isLoading { ProgressView().controlSize(.large) }
                if !isLoading && sitters.isEmpty && sitterData.availableSitters.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView("No sitters", systemImage: "person.2", description: Text("No sitters found."))
                    } else {
                        // Fallback on earlier versions
                    }
                }
            }
            .navigationTitle("Sitters")
            .onAppear {
                subscribe()
                sitterData.listenToActiveSitters()
            }
        }
    }

    private func subscribe() {
        isLoading = true
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("role", isEqualTo: SPDesignSystem.Roles.petSitter)
            .addSnapshotListener { snap, err in
                isLoading = false
                guard err == nil, let snap else { self.sitters = []; return }
                var items: [SitterItem] = snap.documents.map { d in
                    let data = d.data()
                    let email = (data["email"] as? String) ?? ""
                    let fallback = email.split(separator: "@").first.map(String.init) ?? "Sitter"
                    let rawName = (data["displayName"] as? String) ?? (data["name"] as? String) ?? ""
                    let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : rawName
                    return SitterItem(id: d.documentID, name: name, email: email)
                }
                items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.sitters = items
            }
    }
}

private struct SitterItem: Identifiable { let id: String; let name: String; let email: String }

private struct SitterDetailView: View {
    let sitterId: String
    let name: String
    let email: String
    @State private var specialties: [String] = []
    @State private var rating: Double? = nil
    @State private var totalVisits: Int? = nil

    var body: some View {
        List {
            Section("Sitter") {
                HStack { Text("Name"); Spacer(); Text(name).foregroundColor(.secondary) }
                HStack { Text("Email"); Spacer(); Text(email).foregroundColor(.secondary) }
                if let rating { HStack { Text("Rating"); Spacer(); Text(String(format: "%.1f", rating)).foregroundColor(.secondary) } }
                if let totalVisits { HStack { Text("Total Visits"); Spacer(); Text("\(totalVisits)").foregroundColor(.secondary) } }
            }
            if !specialties.isEmpty {
                Section("Specialties") {
                    ForEach(specialties, id: \.self) { Text($0) }
                }
            }
        }
        .navigationTitle("Sitter Info")
        .onAppear(perform: load)
    }

    private func load() {
        Firestore.firestore().collection("sitters").document(sitterId).getDocument { doc, _ in
            guard let data = doc?.data() else { return }
            if let specs = data["specialties"] as? [String] { self.specialties = specs }
            if let r = data["rating"] as? Double { self.rating = r }
            if let tv = data["totalVisits"] as? Int { self.totalVisits = tv }
        }
    }
}


