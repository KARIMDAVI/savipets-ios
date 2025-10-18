import SwiftUI
import FirebaseFirestore
import PhotosUI
import FirebaseStorage

struct PetProfileView: View {
    let petId: String
    let pet: PetDataService.Pet
    
    @State private var isEditMode = false
    @State private var editedPet: PetDataService.Pet
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let petService = PetDataService()
    @Environment(\.dismiss) private var dismiss
    
    init(petId: String, pet: PetDataService.Pet) {
        self.petId = petId
        self.pet = pet
        self._editedPet = State(initialValue: pet)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Pet Photo Section
                petPhotoSection
                
                // Basic Info Section
                basicInfoSection
                
                // Notes Section
                notesSection
            }
        }
        .navigationTitle(pet.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditMode {
                    HStack {
                        Button("Cancel") {
                            cancelEdit()
                        }
                        .foregroundColor(.red)
                        
                        Button("Save") {
                            savePet()
                        }
                        .foregroundColor(.blue)
                        .disabled(isLoading)
                    }
                } else {
                    Button("Edit") {
                        startEdit()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhoto, matching: .images)
        .confirmationDialog("Change Photo", isPresented: $showingActionSheet) {
            Button("Camera") {
                // TODO: Implement camera capture
            }
            Button("Photo Library") {
                showingImagePicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .onChange(of: selectedPhoto) { newPhoto in
            Task {
                await uploadPhoto(newPhoto)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Pet Photo Section
    private var petPhotoSection: some View {
        ZStack {
            // Yellow background that ends at middle of pet photo
            VStack(spacing: 0) {
                // Yellow background section
                Rectangle()
                    .fill(Color.yellow.opacity(0.8))
                    .frame(height: 200) // Height to reach middle of 180px circle (90px from top)
                    .overlay(
                        // Decorative hearts in top right
                        HStack {
                            Spacer()
                            VStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "heart")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.6))
                                    Image(systemName: "heart")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                            }
                            .padding(.top, 20)
                            .padding(.trailing, 20)
                        }
                    )
                
                // White background section for bottom half
                Rectangle()
                    .fill(Color.white)
                    .frame(height: 100)
            }
            
            VStack(spacing: 20) {
                // Pet name centered at top
                Text(pet.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
                
                // Circular pet photo positioned to be half in yellow, half in white
                ZStack {
                    // Circular background
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 180, height: 180)
                        .overlay(
                            Circle()
                                .stroke(Color.yellow.opacity(0.4), lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    // Pet photo
                    AsyncImage(url: URL(string: pet.photoURL ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 160, height: 160)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        case .failure(_), .empty:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 160, height: 160)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 160, height: 160)
                        }
                    }
                    
                    // Camera button overlay
                    Button(action: {
                        showingActionSheet = true
                    }) {
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 35, height: 35)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                            )
                    }
                    .offset(x: 60, y: 60)
                }
                
                Spacer()
            }
        }
        .frame(height: 300)
    }
    
    // MARK: - Basic Info Section
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Basic Info")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if !isEditMode {
                    Button("Edit") {
                        startEdit()
                    }
                    .foregroundColor(.blue)
                    .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Left Column
                VStack(alignment: .leading, spacing: 12) {
                    if isEditMode {
                        EditableInfoRow(icon: "pawprint.fill", label: "Name", text: $editedPet.name)
                        EditableInfoRow(icon: "dog.fill", label: "Species", text: $editedPet.species)
                        EditableInfoRow(icon: "heart.text.clipboard", label: "Sex", text: Binding(
                            get: { editedPet.sex ?? "" },
                            set: { editedPet.sex = $0.isEmpty ? nil : $0 }
                        ))
                        EditableInfoRow(icon: "scalemass.fill", label: "Weight", text: Binding(
                            get: { editedPet.weight ?? "" },
                            set: { editedPet.weight = $0.isEmpty ? nil : $0 }
                        ))
                    } else {
                        InfoRow(icon: "pawprint.fill", label: "Name", value: pet.name)
                        InfoRow(icon: "dog.fill", label: "Species", value: pet.species)
                        InfoRow(icon: "heart.text.clipboard", label: "Sex", value: pet.sex ?? "Not specified")
                        InfoRow(icon: "scalemass.fill", label: "Weight", value: pet.weight ?? "Not specified")
                    }
                }
                
                // Right Column
                VStack(alignment: .leading, spacing: 12) {
                    if isEditMode {
                        EditableInfoRow(icon: "quote.bubble.fill", label: "Nickname", text: Binding(
                            get: { editedPet.nickname ?? "" },
                            set: { editedPet.nickname = $0.isEmpty ? nil : $0 }
                        ))
                        EditableInfoRow(icon: "aqi.medium.gauge.open", label: "Breed", text: Binding(
                            get: { editedPet.breed ?? "" },
                            set: { editedPet.breed = $0.isEmpty ? nil : $0 }
                        ))
                        EditableInfoRow(icon: "birthday.cake.fill", label: "Birthdate", text: Binding(
                            get: { formatDate(editedPet.birthdate) },
                            set: { _ in } // TODO: Implement date picker
                        ))
                    } else {
                        InfoRow(icon: "quote.bubble.fill", label: "Nickname", value: pet.nickname ?? "Not specified")
                        InfoRow(icon: "aqi.medium.gauge.open", label: "Breed", value: pet.breed ?? "Not specified")
                        InfoRow(icon: "birthday.cake.fill", label: "Birthdate", value: formatDate(pet.birthdate))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notes")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            
            VStack(spacing: 12) {
                if isEditMode {
                    EditableNoteCard(
                        title: "Event Note",
                        text: Binding(
                            get: { editedPet.eventNote ?? "" },
                            set: { editedPet.eventNote = $0.isEmpty ? nil : $0 }
                        ),
                        description: "Visible on sitter's visit cards"
                    )
                    
                    EditableNoteCard(
                        title: "Private Note",
                        text: Binding(
                            get: { editedPet.privateNote ?? "" },
                            set: { editedPet.privateNote = $0.isEmpty ? nil : $0 }
                        ),
                        description: "Visible only when visit is approved"
                    )
                    
                    EditableNoteCard(
                        title: "Vet Info",
                        text: Binding(
                            get: { editedPet.vetInfo ?? "" },
                            set: { editedPet.vetInfo = $0.isEmpty ? nil : $0 }
                        ),
                        description: "Emergency contact information"
                    )
                } else {
                    NoteCard(
                        title: "Event Note",
                        content: pet.eventNote ?? "No event notes",
                        description: "Visible on sitter's visit cards"
                    )
                    
                    NoteCard(
                        title: "Private Note",
                        content: pet.privateNote ?? "No private notes",
                        description: "Visible only when visit is approved"
                    )
                    
                    NoteCard(
                        title: "Vet Info",
                        content: pet.vetInfo ?? "No vet information",
                        description: "Emergency contact information"
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Helper Methods
    private func startEdit() {
        editedPet = pet
        isEditMode = true
    }
    
    private func cancelEdit() {
        editedPet = pet
        isEditMode = false
    }
    
    private func savePet() {
        isLoading = true
        Task {
            do {
                var fields: [String: Any] = [
                    "name": editedPet.name,
                    "species": editedPet.species,
                    "birthdate": Timestamp(date: editedPet.birthdate),
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                
                // Add optional fields
                if let breed = editedPet.breed { fields["breed"] = breed }
                if let color = editedPet.color { fields["color"] = color }
                if let sex = editedPet.sex { fields["sex"] = sex }
                if let vaccinated = editedPet.vaccinated { fields["vaccinated"] = vaccinated }
                if let nickname = editedPet.nickname { fields["nickname"] = nickname }
                if let weight = editedPet.weight { fields["weight"] = weight }
                if let eventNote = editedPet.eventNote { fields["eventNote"] = eventNote }
                if let privateNote = editedPet.privateNote { fields["privateNote"] = privateNote }
                if let vetInfo = editedPet.vetInfo { fields["vetInfo"] = vetInfo }
                
                try await petService.updatePet(petId: petId, fields: fields)
                
                await MainActor.run {
                    isEditMode = false
                    isLoading = false
                }
                
                // Refresh the pet data
                if (try await petService.getPet(petId: petId)) != nil {
                    await MainActor.run {
                        // Update the pet data - this would need to be handled by the parent view
                        // For now, we'll just exit edit mode
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save pet information: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func uploadPhoto(_ photo: PhotosPickerItem?) async {
        guard let photo = photo else { return }
        
        do {
            if let data = try await photo.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                
                await MainActor.run {
                    isLoading = true
                }
                
                let photoURL = try await petService.uploadPetPhoto(image: image)
                
                // Update pet with new photo URL
                try await petService.updatePet(petId: petId, fields: ["photoURL": photoURL])
                
                await MainActor.run {
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Info Row Component
private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Editable Info Row Component
private struct EditableInfoRow: View {
    let icon: String
    let label: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter \(label.lowercased())", text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 14, weight: .medium))
            }
            
            Spacer()
        }
    }
}

// MARK: - Note Card Component
private struct NoteCard: View {
    let title: String
    let content: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Editable Note Card Component
private struct EditableNoteCard: View {
    let title: String
    @Binding var text: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            
            TextField("Enter \(title.lowercased())", text: $text, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 14))
                .lineLimit(3...6)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

