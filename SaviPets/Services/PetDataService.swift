import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import UIKit
import OSLog

/// Owner-side pet data service: manages pets under artifacts/{appId}/users/{userId}/pets
final class PetDataService {
    private let db = Firestore.firestore()
    // IMPORTANT: Must match your Canvas __app_id
    private let appId: String

    init(appId: String = AppConstants.Firebase.appId) {
        self.appId = appId
    }

    // MARK: - Path Helpers
    private func petsCollectionRef(for userId: String) -> CollectionReference {
        let path = "artifacts/\(appId)/users/\(userId)/pets"
        return db.collection(path)
    }

    private func currentUserId() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }
        return uid
    }

    // MARK: - Core Pet Document Structure
    struct Pet: Identifiable, Codable {
        var id: String?
        var name: String
        var species: String            // cat, dog, bird, critter
        var breed: String?
        var color: String?
        var sex: String?               // Male or Female
        var vaccinated: Bool?
        var birthdate: Date
        var photoURL: String?
        var eventNote: String?         // Event note
        var privateNote: String?       // Private note
        var vetInfo: String?           // For Emergency
        var nickname: String?          // Pet nickname
        var weight: String?            // Pet weight
        var createdAt: Date?           // Creation timestamp
        var updatedAt: Date?           // Last update timestamp
    }

    // MARK: - User Profile Models
    struct OwnerData {
        var preferences: [String: Bool]
        var emergencyContact: String?
    }

    struct UserProfile {
        var id: String
        var email: String
        var displayName: String
        var photoURL: String?
        var phone: String?
        var address: String?
        var createdAt: Date
        var role: String // 'owner' | 'sitter' | 'admin'
        var ownerData: OwnerData?
    }

    struct StaffProfile {
        var id: String
        var skills: [String]
        var certifications: [[String: Any]]
        var availability: [[String: Any]]
        var metricsSummary: [String: Double]
        var bio: String?
        var locationZone: [String: Any]?
        var isManager: Bool?
        var adminNotes: String?
    }

    // MARK: - Derivation Function
    /// Derives the total number of pets for the current user by fetching all pet documents.
    /// Efficient for small collections and accurate by definition.
    @discardableResult
    func derivePetCount() async throws -> Int {
        let uid = try currentUserId()
        return try await NetworkRetryHelper.retry {
            let snap = try await petsCollectionRef(for: uid).getDocuments()
            return snap.documents.count
        }
    }

    // MARK: - Add Pet
    func addPet(_ pet: Pet) async throws {
        let uid = try currentUserId()
        let collection = petsCollectionRef(for: uid)

        var data: [String: Any] = [
            "name": pet.name,
            "species": pet.species,
            "birthdate": Timestamp(date: pet.birthdate)
        ]
        if let v = pet.breed { data["breed"] = v }
        if let v = pet.color { data["color"] = v }
        if let v = pet.sex { data["sex"] = v }
        if let v = pet.vaccinated { data["vaccinated"] = v }
        if let v = pet.photoURL { data["photoURL"] = v }
        if let v = pet.eventNote { data["eventNote"] = v }
        if let v = pet.privateNote { data["privateNote"] = v }
        if let v = pet.vetInfo { data["vetInfo"] = v }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _ = collection.addDocument(data: data) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        // Denormalize: Update pet names in user document
        await syncPetNamesToUserDocument(userId: uid)
    }

    // MARK: - List Pets (helper)
    func listPets() async throws -> [Pet] {
        let uid = try currentUserId()
        return try await NetworkRetryHelper.retry {
            let snap = try await petsCollectionRef(for: uid).getDocuments()
            return snap.documents.compactMap { doc in
                let data = doc.data()
                guard
                    let name = data["name"] as? String,
                    let species = data["species"] as? String
                else {
                    return nil
                }

                let birthdate: Date
                if let ts = data["birthdate"] as? Timestamp {
                    birthdate = ts.dateValue()
                } else if let date = data["birthdate"] as? Date {
                    birthdate = date
                } else {
                    return nil
                }

                return Pet(
                    id: doc.documentID,
                    name: name,
                    species: species,
                    breed: data["breed"] as? String,
                    color: data["color"] as? String,
                    sex: data["sex"] as? String,
                    vaccinated: data["vaccinated"] as? Bool,
                    birthdate: birthdate,
                    photoURL: data["photoURL"] as? String,
                    eventNote: data["eventNote"] as? String,
                    privateNote: data["privateNote"] as? String,
                    vetInfo: data["vetInfo"] as? String,
                    nickname: data["nickname"] as? String,
                    weight: data["weight"] as? String,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
                )
            }
        }
    }

    // MARK: - Get Single Pet
    func getPet(petId: String) async throws -> Pet? {
        let uid = try currentUserId()
        return try await NetworkRetryHelper.retry {
            let doc = try await petsCollectionRef(for: uid).document(petId).getDocument()
            guard let data = doc.data(),
                  let name = data["name"] as? String,
                  let species = data["species"] as? String else {
                return nil
            }

            let birthdate: Date
            if let ts = data["birthdate"] as? Timestamp {
                birthdate = ts.dateValue()
            } else if let date = data["birthdate"] as? Date {
                birthdate = date
            } else {
                return nil
            }

            return Pet(
                id: doc.documentID,
                name: name,
                species: species,
                breed: data["breed"] as? String,
                color: data["color"] as? String,
                sex: data["sex"] as? String,
                vaccinated: data["vaccinated"] as? Bool,
                birthdate: birthdate,
                photoURL: data["photoURL"] as? String,
                eventNote: data["eventNote"] as? String,
                privateNote: data["privateNote"] as? String,
                vetInfo: data["vetInfo"] as? String,
                nickname: data["nickname"] as? String,
                weight: data["weight"] as? String,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
            )
        }
    }

    // MARK: - Profiles Writes
    func updateProfile(profile: UserProfile) async throws {
        var data: [String: Any] = [
            "email": profile.email,
            "displayName": profile.displayName,
            "role": profile.role,
            "createdAt": Timestamp(date: profile.createdAt)
        ]
        if let p = profile.photoURL { data["photoURL"] = p }
        if let p = profile.phone { data["phone"] = p }
        if let a = profile.address { data["address"] = a }
        if let owner = profile.ownerData {
            var ownerMap: [String: Any] = ["preferences": owner.preferences]
            if let ec = owner.emergencyContact { ownerMap["emergencyContact"] = ec }
            data["ownerData"] = ownerMap
        }
        try await db.collection("users").document(profile.id).setData(data, merge: true)
    }

    func updateStaffProfile(profile: StaffProfile) async throws {
        var data: [String: Any] = [
            "skills": profile.skills,
            "certifications": profile.certifications,
            "availability": profile.availability,
            "metricsSummary": profile.metricsSummary
        ]
        if let bio = profile.bio { data["bio"] = bio }
        if let zone = profile.locationZone { data["locationZone"] = zone }
        if let manager = profile.isManager { data["isManager"] = manager }
        if let note = profile.adminNotes { data["adminNotes"] = note }

        let path = "artifacts/\(appId)/users/\(profile.id)/staff/\(profile.id)"
        try await db.document(path).setData(data, merge: true)
    }

    // MARK: - Profile existence check
    func userProfileExists(uid: String) async throws -> Bool {
        return try await NetworkRetryHelper.retry {
            let doc = try await db.collection("users").document(uid).getDocument()
            return doc.exists
        }
    }

    // MARK: - Upload Photo
    func uploadPetPhoto(image: UIImage) async throws -> String {
        guard let data = resizedJPEGData(from: image) else {
            throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"]) }
        let uid = try currentUserId()
        let fileName = UUID().uuidString + ".jpg"
        let path = "artifacts/\(appId)/users/\(uid)/pets_photos/\(fileName)"
        let ref = Storage.storage().reference(withPath: path)
        _ = try await ref.putDataAsync(data, metadata: nil)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    /// Spark-plan friendly deterministic path: overwrite the same object per pet to avoid orphaned files
    func uploadPetPhoto(petId: String, image: UIImage) async throws -> String {
        guard let data = resizedJPEGData(from: image) else {
            throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"]) }
        let uid = try currentUserId()
        let path = "artifacts/\(appId)/users/\(uid)/pets/\(petId)/photo.jpg"
        let ref = Storage.storage().reference(withPath: path)
        _ = try await ref.putDataAsync(data, metadata: nil)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // Downscale large images before upload to fit free-tier quotas
    private func resizedJPEGData(from image: UIImage, maxDimension: CGFloat = 1280, quality: CGFloat = 0.78) -> Data? {
        let originalSize = image.size
        let maxSide = max(originalSize.width, originalSize.height)
        let scale = maxSide > maxDimension ? (maxDimension / maxSide) : 1
        let targetSize = CGSize(width: floor(originalSize.width * scale), height: floor(originalSize.height * scale))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return scaled.jpegData(compressionQuality: quality)
    }

    // MARK: - Update Pet
    func updatePet(petId: String, fields: [String: Any]) async throws {
        let uid = try currentUserId()
        try await NetworkRetryHelper.retry {
            let doc = petsCollectionRef(for: uid).document(petId)
            try await doc.setData(fields, merge: true)
        }
        
        // Denormalize: Update pet names in user document if name changed
        if fields["name"] != nil {
            await syncPetNamesToUserDocument(userId: uid)
        }
    }

    // MARK: - Delete Pet
    func deletePet(petId: String) async throws {
        let uid = try currentUserId()
        try await NetworkRetryHelper.retry {
            try await petsCollectionRef(for: uid).document(petId).delete()
        }
        
        // Denormalize: Update pet names in user document after deletion
        await syncPetNamesToUserDocument(userId: uid)
        
        // Broadcast change so all views refresh (OwnerPetsView & OwnerDashboardView listen to petsDidChange)
        await MainActor.run {
            NotificationCenter.default.post(name: .petsDidChange, object: nil)
        }
    }

    // MARK: - Denormalization Helper
    
    /// Syncs pet names to the user document for efficient admin display
    /// This eliminates the need for N queries when loading the admin clients view
    private func syncPetNamesToUserDocument(userId: String) async {
        do {
            // Fetch all pet names for this user
            let snap = try await petsCollectionRef(for: userId).getDocuments()
            let petNames = snap.documents.compactMap { $0.data()["name"] as? String }
            
            // Update user document with denormalized pet names array
            try await db.collection("users").document(userId).setData([
                "petNames": petNames,
                "petCount": petNames.count,
                "petsUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            AppLogger.data.debug("✅ Synced \(petNames.count) pet names to user \(userId.prefix(8))")
        } catch {
            AppLogger.data.error("Failed to sync pet names for user \(userId.prefix(8)): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Admin/Service helpers (cross-user access)
    
    /// Fetches photo URLs for the given user's pets matching any of the provided names.
    /// Intended for admin/service flows where the current auth user is not the pet owner.
    func fetchPetPhotoURLs(forUserId userId: String, matchingNames names: [String]) async throws -> [String] {
        guard !names.isEmpty else { return [] }
        let snap = try await petsCollectionRef(for: userId).getDocuments()
        let wanted = Set(names.map { $0.lowercased() })
        var urls: [String] = []
        for doc in snap.documents {
            let data = doc.data()
            guard let nm = data["name"] as? String else { continue }
            if wanted.contains(nm.lowercased()), let url = data["photoURL"] as? String, !url.isEmpty {
                urls.append(url)
            }
        }
        return urls
    }
}
