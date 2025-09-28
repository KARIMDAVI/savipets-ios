import Foundation
import FirebaseFirestore

final class SchedulingService {
    private let db = Firestore.firestore()
    // IMPORTANT: set this from your environment. Default is placeholder.
    private let appId: String

    init(appId: String = "1:367657554735:ios:05871c65559a6a40b007da") {
        self.appId = appId
    }

    /// Assigns a shift to a staff member atomically using a Firestore transaction.
    /// - Parameters:
    ///   - shiftId: The ID of the shift to assign
    ///   - staffId: The ID of the staff member
    ///   - staffName: The name of the staff member
    func assignShiftTransactional(shiftId: String, staffId: String, staffName: String) async throws {
        let shiftPath = "artifacts/\(appId)/public/data/shifts/\(shiftId)"
        let shiftRef = db.document(shiftPath)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                // 1) Read current state
                let snap: DocumentSnapshot
                do {
                    snap = try transaction.getDocument(shiftRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                guard snap.exists, let data = snap.data() else {
                    let nsError = NSError(domain: "SchedulingError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Shift not found."])
                    errorPointer?.pointee = nsError
                    return nil
                }

                let currentAssignment = (data["assignedStaffId"] as? String) ?? ""
                guard currentAssignment.isEmpty else {
                    let nsError = NSError(domain: "SchedulingError", code: 409, userInfo: [NSLocalizedDescriptionKey: "Shift is already assigned."])
                    errorPointer?.pointee = nsError
                    return nil
                }

                // 3) Commit update
                transaction.updateData([
                    "assignedStaffId": staffId,
                    "assignedStaffName": staffName,
                    "status": "Assigned",
                    "assignedOn": FieldValue.serverTimestamp()
                ], forDocument: shiftRef)

                return nil
            }) { (_, error) in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    /// Updates the status of an assigned shift. Rules must allow either manager/scheduler
    /// or the assigned staff member to write the status field.
    /// - Parameters:
    ///   - shiftId: Shift document id
    ///   - newStatus: e.g. "Accepted" | "Declined" | "Completed"
    func updateShiftStatus(shiftId: String, newStatus: String) async throws {
        let shiftPath = "artifacts/\(appId)/public/data/shifts/\(shiftId)"
        let ref = db.document(shiftPath)
        try await ref.updateData([
            "status": newStatus,
            "audit.statusUpdatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Convenience: mark assigned shift as accepted by staff
    func acceptShift(shiftId: String) async throws {
        try await updateShiftStatus(shiftId: shiftId, newStatus: "Accepted")
    }

    /// Convenience: mark assigned shift as declined by staff
    func declineShift(shiftId: String) async throws {
        try await updateShiftStatus(shiftId: shiftId, newStatus: "Declined")
    }
}


