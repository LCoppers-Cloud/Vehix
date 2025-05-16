import SwiftUI
import SwiftData
import PhotosUI

struct AddVehicleForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Callback when vehicle is created
    var onVehicleCreated: ((AppVehicle) -> Void)?
    
    // Vehicle properties
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var vin: String = ""
    @State private var licensePlate: String = ""
    @State private var color: String = ""
    @State private var mileage: Int = 0
    @State private var notes: String = ""
    @State private var vehicleType: String = VehicleType.gas.rawValue
    
    // Photo picker state
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    
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
                Section(header: Text("Photo (Optional)")) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let data = photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            HStack {
                                Image(systemName: "car.fill")
                                    .font(.largeTitle)
                                    .padding()
                                    .foregroundColor(.blue)
                                
                                Text("Add Vehicle Photo")
                                    .foregroundColor(.blue)
                                
                                Spacer()
                            }
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                photoData = data
                            }
                        }
                    }
                    
                    if photoData != nil {
                        Button("Remove Photo", role: .destructive) {
                            selectedPhoto = nil
                            photoData = nil
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                // Notes section
                Section(header: Text("Notes")) {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(5...)
                }
            }
            .navigationTitle("Add Vehicle")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveVehicle()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private func saveVehicle() {
        // Create new vehicle with all properties
        let newVehicle = AppVehicle(
            id: UUID().uuidString, // Ensure unique ID
            make: make,
            model: model,
            year: year,
            vin: vin,
            licensePlate: licensePlate.isEmpty ? nil : licensePlate,
            color: color.isEmpty ? nil : color,
            mileage: mileage,
            notes: notes.isEmpty ? nil : notes,
            photoData: photoData
        )
        
        // Set vehicle type
        newVehicle.vehicleType = vehicleType
        
        // Insert into database
        modelContext.insert(newVehicle)
        try? modelContext.save()
        
        // Call completion handler
        onVehicleCreated?(newVehicle)
        
        // Dismiss form
        dismiss()
    }
}

#Preview {
    AddVehicleForm()
        .modelContainer(for: AppVehicle.self, inMemory: true)
} 