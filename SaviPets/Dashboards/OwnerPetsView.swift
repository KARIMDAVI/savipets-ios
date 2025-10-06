import SwiftUI
import FirebaseFirestore
import UIKit
import PhotosUI
import FirebaseStorage

struct OwnerPetsView: View {
    @State private var pets: [PetDataService.Pet] = []
    @State private var showAdd: Bool = false
    @State private var editingPet: PetDataService.Pet? = nil
    private let svc = PetDataService()

    // MARK: Category paging (Dogs, Cats, Birds, Critters)
    enum PetType: String, CaseIterable, Identifiable { case dog = "dog", cat = "cat", bird = "bird", critter = "critter"; var id: String { rawValue } }
    @State private var selectedType: PetType = .dog

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Segmented type picker for quick jumps; also supports horizontal swipe below
                Picker("Type", selection: $selectedType) {
                    Text("Dogs").tag(PetType.dog)
                    Text("Cats").tag(PetType.cat)
                    Text("Birds").tag(PetType.bird)
                    Text("Critters").tag(PetType.critter)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Horizontally swipe between types
                TabView(selection: $selectedType) {
                    ForEach(PetType.allCases) { type in
                        CategoryPage(type: type, pets: petsFor(type)) { pet in
                            editingPet = pet
                        }
                        .tag(type)
                        .padding(.bottom) // space from bottom safe area
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .navigationTitle("My Pets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) { Button(action: { showAdd.toggle() }) { Image(systemName: "plus") } }
            }
            .task { await reload() }
            .onReceive(NotificationCenter.default.publisher(for: .petsDidChange)) { _ in
                Task { await reload() }
            }
            .sheet(isPresented: $showAdd) { AddPetSheet(onSaved: { Task { await reload(); showAdd = false } }) }
            .sheet(item: Binding(get: { editingPet }, set: { editingPet = $0 })) { pet in
                EditPetSheet(pet: pet, onSaved: { Task { await reload(); editingPet = nil } }, onDeleted: {
                    Task { await reload(); editingPet = nil }
                })
            }
        }
    }

    private func petsFor(_ type: PetType) -> [PetDataService.Pet] {
        pets.filter { $0.species.lowercased() == type.rawValue }
    }

    @MainActor
    private func reload() async {
        do { pets = try await svc.listPets() } catch { pets = [] }
    }
}

struct PetGridCard: View {
    let name: String
    let photoURL: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 110)

                if let s = photoURL, let url = URL(string: s) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 110)
                                .clipped()
                        case .failure(_):
                            Image(systemName: "pawprint.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.gray.opacity(0.35))
                                .padding(24)
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "pawprint.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.gray.opacity(0.35))
                        .padding(24)
                }
            }
            .frame(height: 110)
            .clipped()

            Text(name)
                .font(.headline)
                .lineLimit(1)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SPDesignSystem.Colors.glassBorder, lineWidth: 1)
        )
    }
}

private struct EditPetSheet: View, Identifiable {
    var id: String { pet.id ?? UUID().uuidString }
    let pet: PetDataService.Pet
    var onSaved: () -> Void
    var onDeleted: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var species: String = "dog"
    @State private var breed: String = ""
    @State private var color: String = ""
    @State private var sex: String = "Male"
    @State private var vaccinated: Bool = true
    @State private var birthdate: Date = Date()
    @State private var eventNote: String = ""
    @State private var privateNote: String = ""
    @State private var vetInfo: String = ""
    @State private var photo: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isSaving: Bool = false
    @State private var isDeleting: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var error: String? = nil

    private let svc = PetDataService()

    init(pet: PetDataService.Pet, onSaved: @escaping () -> Void, onDeleted: (() -> Void)? = nil) {
        self.pet = pet
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _name = State(initialValue: pet.name)
        _species = State(initialValue: pet.species)
        _breed = State(initialValue: pet.displayBreed ?? "")
        _color = State(initialValue: pet.displayColor ?? "")
        _sex = State(initialValue: pet.sex ?? "Male")
        _vaccinated = State(initialValue: pet.vaccinated ?? true)
        _birthdate = State(initialValue: pet.birthdate)
        _eventNote = State(initialValue: pet.eventNote ?? "")
        _privateNote = State(initialValue: pet.privateNote ?? "")
        _vetInfo = State(initialValue: pet.vetInfo ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    if let photo { Image(uiImage: photo).resizable().scaledToFill().frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 12)) }
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(photo == nil ? "Choose Photo" : "Change Photo", systemImage: "photo")
                    }
                    .onChange(of: selectedPhotoItem) { item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                                await MainActor.run { photo = img }
                                // Persist immediately when editing an existing pet
                                if let pid = pet.id {
                                    if let url = try? await svc.uploadPetPhoto(petId: pid, image: img) {
                                        try? await svc.updatePet(petId: pid, fields: ["photoURL": url])
                                        NotificationCenter.default.post(name: .petsDidChange, object: nil)
                                    }
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    // Preload existing photo for preview when editing
                    if photo == nil, let urlString = pet.photoURL, let url = URL(string: urlString) {
                        Task { @MainActor in
                            if let (data, _) = try? await URLSession.shared.data(from: url), let img = UIImage(data: data) {
                                self.photo = img
                            }
                        }
                    }
                }
                Section("Basic Info") {
                    TextField("Pet's name", text: $name)
                    Picker("Type", selection: $species) { Text("Dog").tag("dog"); Text("Cat").tag("cat"); Text("Bird").tag("bird"); Text("Critter").tag("critter") }
                    TextField("Pet's breed", text: $breed)
                    TextField("Pet's color", text: $color)
                    Picker("Sex", selection: $sex) { Text("Male").tag("Male"); Text("Female").tag("Female") }
                    DatePicker("Birthdate", selection: $birthdate, displayedComponents: .date)
                    Toggle("Vaccinated", isOn: $vaccinated)
                }
                Section("Notes") {
                    TextField("Event Note", text: $eventNote)
                    TextField("Private note", text: $privateNote)
                    TextField("Vet info (for emergency)", text: $vetInfo)
                }

                Section {
                    Button(action: { showDeleteConfirmation = true }) {
                        HStack { Image(systemName: "trash"); Text("Delete Pet") }
                            .foregroundColor(.red)
                    }
                    .disabled(isDeleting)
                }
                if let error { Text(error).foregroundColor(.red) }
            }
            .navigationTitle("Edit Pet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(isSaving ? "Saving..." : "Save") { Task { await save() } }.disabled(isSaving) }
            }
            .confirmationDialog("Delete Pet", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) { Task { await deletePet() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(name)? This action cannot be undone.")
            }
        }
    }

    private func pickPhoto() {
        // For brevity, integrate UIImagePickerController / PHPickerViewController in your project setup.
        // Placeholder: no-op. This keeps within scope of asked changes.
    }

    @MainActor
    private func save() async {
        guard let petId = pet.id else { return }
        isSaving = true
        var fields: [String: Any] = [
            "name": name,
            "species": species,
            "breed": breed,
            "color": color,
            "sex": sex,
            "vaccinated": vaccinated,
            "birthdate": Timestamp(date: birthdate),
            "eventNote": eventNote,
            "privateNote": privateNote,
            "vetInfo": vetInfo
        ]
        if let photo {
            if let url = try? await svc.uploadPetPhoto(image: photo) { fields["photoURL"] = url }
        }
        do {
            try await svc.updatePet(petId: petId, fields: fields)
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    @MainActor
    private func deletePet() async {
        guard let petId = pet.id else { return }
        isDeleting = true
        error = nil
        do {
            try await svc.deletePet(petId: petId)
            onDeleted?()
            NotificationCenter.default.post(name: .petsDidChange, object: nil)
            dismiss()
        } catch {
            self.error = "Failed to delete pet: \(error.localizedDescription)"
        }
        isDeleting = false
    }
}

private struct AddPetSheet: View {
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var species: String = "dog"
    @State private var breed: String = ""
    @State private var color: String = ""
    @State private var sex: String = "Male"
    @State private var vaccinated: Bool = true
    @State private var birthdate: Date = Date()
    @State private var eventNote: String = ""
    @State private var privateNote: String = ""
    @State private var vetInfo: String = ""
    @State private var error: String? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var photo: UIImage? = nil
    @State private var uploadedPhotoURL: String? = nil
    @State private var isUploading: Bool = false
    private let svc = PetDataService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    if let photo { Image(uiImage: photo).resizable().scaledToFill().frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 12)) }
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(photo == nil ? "Choose Photo" : "Change Photo", systemImage: "photo")
                    }
                    .onChange(of: selectedPhotoItem) { item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                                await MainActor.run { photo = img; isUploading = true; error = nil }
                                // Upload immediately so the chosen image persists even before Save
                                do {
                                    let url = try await svc.uploadPetPhoto(image: img)
                                    await MainActor.run { uploadedPhotoURL = url; isUploading = false }
                                } catch {
                                    await MainActor.run { self.error = "Upload failed: \(error.localizedDescription)"; isUploading = false }
                                }
                            }
                        }
                    }
                    if isUploading { ProgressView("Uploading...") }
                }
                Section("Basic Info") {
                    TextField("Pet's name", text: $name)
                    Picker("Type", selection: $species) {
                        Text("Dog").tag("dog"); Text("Cat").tag("cat"); Text("Bird").tag("bird"); Text("Critter").tag("critter")
                    }
                    TextField("Pet's breed", text: $breed)
                    TextField("Pet's color", text: $color)
                    Picker("Sex", selection: $sex) { Text("Male").tag("Male"); Text("Female").tag("Female") }
                    DatePicker("Birthdate", selection: $birthdate, displayedComponents: .date)
                    Toggle("Vaccinated", isOn: $vaccinated)
                }
                Section("Notes") {
                    TextField("Event Note", text: $eventNote)
                    TextField("Private note", text: $privateNote)
                    TextField("Vet info (for emergency)", text: $vetInfo)
                }
                if let error { Text(error).foregroundColor(.red) }
            }
            .navigationTitle("Add Pet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } } }
            }
        }
    }

    @MainActor
    private func save() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { error = "Name required"; return }
        var photoURL: String? = uploadedPhotoURL
        if photoURL == nil, let image = photo {
            // Fallback: upload on save if not already uploaded
            do { photoURL = try await svc.uploadPetPhoto(image: image) } catch { self.error = error.localizedDescription; return }
        }
        let pet = PetDataService.Pet(
            id: nil,
            name: name,
            species: species,
            breed: breed.isEmpty ? nil : breed,
            color: color.isEmpty ? nil : color,
            sex: sex,
            vaccinated: vaccinated,
            birthdate: birthdate,
            photoURL: photoURL,
            eventNote: eventNote.isEmpty ? nil : eventNote,
            privateNote: privateNote.isEmpty ? nil : privateNote,
            vetInfo: vetInfo.isEmpty ? nil : vetInfo
        )
        do {
            try await svc.addPet(pet)
            onSaved()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Safe accessors for optional model fields
private extension PetDataService.Pet {
    // Use reflection to safely read properties if model shape differs.
    var displayBreed: String? {
        // If the property exists, return it; otherwise nil
        if let value = Mirror(reflecting: self).children.first(where: { $0.label == "breed" })?.value as? String {
            return value
        }
        return nil
    }

    var displayColor: String? {
        if let value = Mirror(reflecting: self).children.first(where: { $0.label == "color" })?.value as? String {
            return value
        }
        return nil
    }
}

extension Notification.Name {
    static let petsDidChange = Notification.Name("petsDidChange")
}

// MARK: - Category Page (centered cards, consistent size, safe padding)
private struct CategoryPage: View {
    let type: OwnerPetsView.PetType
    let pets: [PetDataService.Pet]
    var onTap: (PetDataService.Pet) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = 20
            let verticalPadding: CGFloat = 20
            let cardWidth = geo.size.width - (horizontalPadding * 2)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    if pets.isEmpty {
                        if #available(iOS 17.0, *) {
                            ContentUnavailableView("No \(typeLabel.plural) yet", systemImage: "pawprint", description: Text("Tap + to add your first \(typeLabel.singularLowercased)."))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "pawprint").font(.largeTitle).foregroundColor(.secondary)
                                Text("No \(typeLabel.plural) yet").font(.headline)
                                Text("Tap + to add your first \(typeLabel.singularLowercased).")
                                    .font(.subheadline).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: geo.size.height - (verticalPadding * 2))
                        }
                    } else {
                        let columns: [GridItem] = [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ]
                        LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
                            ForEach(pets) { pet in
                                PetGridCard(name: pet.name, photoURL: pet.photoURL)
                                    .onTapGesture { onTap(pet) }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
        }
    }

    private var typeLabel: (plural: String, singularLowercased: String) {
        switch type {
        case .dog: return ("Dogs", "dog")
        case .cat: return ("Cats", "cat")
        case .bird: return ("Birds", "bird")
        case .critter: return ("Critters", "critter")
        }
    }
}
