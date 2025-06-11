import SwiftUI
import SwiftData
import PhotosUI

struct EditVehicleForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Reference to the vehicle being edited
    let vehicle: AppVehicle
    
    // Callback when vehicle is updated
    var onVehicleUpdated: ((AppVehicle) -> Void)?
    
    // Vehicle properties - initialize with current values
    @State private var make: String
    @State private var model: String
    @State private var year: Int
    @State private var vin: String
    @State private var licensePlate: String
    @State private var color: String
    @State private var mileage: Int
    @State private var notes: String
    @State private var vehicleType: String
    
    // Photo picker state
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showDeleteConfirmation = false
    
    // Initializer to set up state properties with existing vehicle data
    init(vehicle: AppVehicle, onVehicleUpdated: ((AppVehicle) -> Void)? = nil) {
        self.vehicle = vehicle
        self.onVehicleUpdated = onVehicleUpdated
        
        // Initialize state properties with vehicle data
        _make = State(initialValue: vehicle.make)
        _model = State(initialValue: vehicle.model)
        _year = State(initialValue: vehicle.year)
        _vin = State(initialValue: vehicle.vin)
        _licensePlate = State(initialValue: vehicle.licensePlate ?? "")
        _color = State(initialValue: vehicle.color ?? "")
        _mileage = State(initialValue: vehicle.mileage)
        _notes = State(initialValue: vehicle.notes ?? "")
        _vehicleType = State(initialValue: vehicle.vehicleType)
        _photoData = State(initialValue: vehicle.photoData)
    }
    
    var isFormValid: Bool {
        !make.isEmpty && !model.isEmpty && year > 2000 && year <= Calendar.current.component(.year, from: Date()) + 1
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Vehicle details section
                Section(header: Text("Vehicle Details")) {
                    TextField("Make*", text: $make)
                        .autocapitalization(.words)
                    
                    TextField("Model*", text: $model)
                        .autocapitalization(.words)
                    
                    Picker("Year*", selection: $year) {
                        ForEach((2000...Calendar.current.component(.year, from: Date()) + 1).reversed(), id: \.self) { year in
                            Text(String(format: "%d", year)).tag(year)
                        }
                    }
                    
                    Picker("Type", selection: $vehicleType) {
                        ForEach(VehicleType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type.rawValue)
                        }
                    }
                    
                    TextField("VIN", text: $vin)
                        .textInputAutocapitalization(.characters)
                    
                    TextField("License Plate", text: $licensePlate)
                        .textInputAutocapitalization(.characters)
                    
                    TextField("Color", text: $color)
                        .autocapitalization(.words)
                }
                
                // Mileage section
                Section(header: Text("Mileage")) {
                    HStack {
                        Text("Current Mileage")
                        Spacer()
                        TextField("Mileage", value: $mileage, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                // Photo section
                Section(header: Text("Vehicle Photo")) {
                    VStack {
                        if let data = photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        } else {
                            Image(systemName: "car.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Change Photo", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .onChange(of: selectedPhoto) { oldValue, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    photoData = data
                                }
                            }
                        }
                        
                        if photoData != nil {
                            Button(role: .destructive) {
                                photoData = nil
                            } label: {
                                Label("Remove Photo", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
                
                // Notes section
                Section(header: Text("Notes")) {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(5...)
                }
                
                // Delete section
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Vehicle")
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Edit Vehicle")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateVehicle()
                    }
                    .disabled(!isFormValid)
                }
            }
            .confirmationDialog(
                "Delete Vehicle",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    // Delete the vehicle
                    modelContext.delete(vehicle)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this vehicle? This cannot be undone.")
            }
        }
    }
    
    private func updateVehicle() {
        // Update vehicle properties
        vehicle.make = make
        vehicle.model = model
        vehicle.year = year
        vehicle.vin = vin
        vehicle.licensePlate = licensePlate.isEmpty ? nil : licensePlate
        vehicle.color = color.isEmpty ? nil : color
        vehicle.mileage = mileage
        vehicle.notes = notes.isEmpty ? nil : notes
        vehicle.photoData = photoData
        vehicle.vehicleType = vehicleType
        vehicle.updatedAt = Date()
        
        // Save changes
        try? modelContext.save()
        
        // Call completion handler
        onVehicleUpdated?(vehicle)
        
        // Dismiss form
        dismiss()
    }
}

#Preview {
    // Preview requires an existing vehicle - this would normally be passed from VehicleDetailView
    Text("Edit Vehicle Preview")
        .navigationTitle("Edit Vehicle")
} 