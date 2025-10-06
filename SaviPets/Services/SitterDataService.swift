import Foundation
import Combine
import FirebaseFirestore

struct SitterProfile: Identifiable {
    let id: String
    let name: String
    let email: String
    let phone: String?
    let specialties: [String]
    let rating: Double
    let totalVisits: Int
    let isActive: Bool
    let profileImage: String?
}

final class SitterDataService: ObservableObject {
    @Published var availableSitters: [SitterProfile] = []
    private let db = FirebaseFirestore.Firestore.firestore()

    func listenToActiveSitters() {
        // Source of truth: users collection with role == "petSitter"
        db.collection("users")
            .whereField("role", isEqualTo: SPDesignSystem.Roles.petSitter)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                self?.availableSitters = documents.map { doc in
                    let data = doc.data()
                    let name = (data["displayName"] as? String)
                        ?? (data["name"] as? String)
                        ?? (data["email"] as? String)?.components(separatedBy: "@").first?.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ").capitalized
                        ?? "Sitter"
                    return SitterProfile(
                        id: doc.documentID,
                        name: name,
                        email: data["email"] as? String ?? "",
                        phone: data["phone"] as? String,
                        specialties: [],
                        rating: 0.0,
                        totalVisits: 0,
                        isActive: true,
                        profileImage: data["photoURL"] as? String
                    )
                }
            }
    }
}





