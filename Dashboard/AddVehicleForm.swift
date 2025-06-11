import SwiftUI
import SwiftData
import PhotosUI

struct AddVehicleForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    @EnvironmentObject var samsaraService: SamsaraService
    
    // Vehicle Information
    @State private var make = ""
    @State private var model = ""
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var vin = ""
    @State private var licensePlate = ""
    @State private var color = ""
    @State private var vehicleType: VehicleType = .gas
    @State private var mileage = 0
    @State private var notes = ""
    
    // Photo
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var vehiclePhoto: UIImage?
    @State private var photoData: Data?
    
    // Technician Assignment
    @State private var selectedTechnicianId: String?
    @State private var assignmentStartDate = Date()
    
    // GPS Tracking
    @State private var enableSamsaraTracking = false
    @State private var enableAppleGPSTracking = false
    
    // Initial Inventory
    @State private var addInitialInventory = false
    @State private var selectedInventoryItems: Set<String> = []
    @State private var inventoryQuantities: [String: Int] = [:]
    
    // UI State
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var currentStep = 1
    
    // Data
    @Query private var technicians: [AuthUser]
    @Query private var inventoryItems: [AppInventoryItem]
    
    private var availableTechnicians: [AuthUser] {
        technicians.filter { $0.userRole == .technician }
    }
    
    private var isFormValid: Bool {
        !make.isEmpty && !model.isEmpty && year > 1900 && !vin.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                switch currentStep {
                case 1:
                    vehicleInfoSection
                case 2:
                    technicianAssignmentSection
                case 3:
                    trackingOptionsSection
                case 4:
                    inventorySetupSection
                default:
                    reviewSection
                }
            }
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentStep < 5 {
                        Button("Next") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .disabled(!isStepValid)
                    } else {
                        Button("Create") {
                            createVehicle()
                        }
                        .disabled(!isFormValid || isCreating)
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Form Sections
    
    private var vehicleInfoSection: some View {
        Section {
            VStack(spacing: 16) {
                Text("Vehicle Information")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Photo picker
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack {
                        if let vehiclePhoto = vehiclePhoto {
                            Image(uiImage: vehiclePhoto)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 120)
                                .overlay {
                                    VStack {
                                        Image(systemName: "camera.fill")
                                            .font(.title)
                                        Text("Add Photo")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)
                                }
                        }
                    }
                }
                .onChange(of: selectedPhoto) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            vehiclePhoto = image
                            photoData = data
                        }
                    }
                }
                
                VStack(spacing: 12) {
                    HStack {
                        TextField("Make", text: $make)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Model", text: $model)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        TextField("Year", value: $year, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        
                        Picker("Type", selection: $vehicleType) {
                            ForEach(VehicleType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    TextField("VIN", text: $vin)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                    
                    TextField("License Plate", text: $licensePlate)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                    
                    HStack {
                        TextField("Color", text: $color)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Mileage", value: $mileage, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                    }
                    
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3)
                }
            }
        }
    }
    
    private var technicianAssignmentSection: some View {
        Section {
            VStack(spacing: 16) {
                Text("Technician Assignment")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if availableTechnicians.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("No Technicians Available")
                            .font(.headline)
                        
                        Text("Add technicians to your team first, then assign them to vehicles.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Skip for Now") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Text("Assign this vehicle to a technician (optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Select Technician", selection: $selectedTechnicianId) {
                            Text("No Assignment").tag(nil as String?)
                            ForEach(availableTechnicians, id: \.id) { technician in
                                Text(technician.fullName ?? technician.email)
                                    .tag(technician.id as String?)
                            }
                        }
                        .pickerStyle(.wheel)
                        
                        if selectedTechnicianId != nil {
                            DatePicker("Assignment Start Date", selection: $assignmentStartDate, displayedComponents: .date)
                        }
                    }
                }
            }
        }
    }
    
    private var trackingOptionsSection: some View {
        Section {
            VStack(spacing: 16) {
                Text("GPS Tracking Options")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 16) {
                    // Samsara Integration
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable Samsara GPS Tracking", isOn: $enableSamsaraTracking)
                            .font(.subheadline)
                        
                        if enableSamsaraTracking {
                            Text("• Automatic mileage updates\n• Real-time location tracking\n• Fleet management integration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Apple GPS Tracking
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable Apple GPS Tracking", isOn: $enableAppleGPSTracking)
                            .font(.subheadline)
                        
                        if enableAppleGPSTracking {
                            Text("• Basic location tracking\n• Inventory usage location recording\n• No additional hardware required")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    if !enableSamsaraTracking && !enableAppleGPSTracking {
                        Text("You can enable tracking later in vehicle settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }
    
    private var inventorySetupSection: some View {
        Section {
            VStack(spacing: 16) {
                Text("Initial Inventory Setup")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Toggle("Add Initial Inventory", isOn: $addInitialInventory)
                    .font(.subheadline)
                
                if addInitialInventory {
                    if inventoryItems.isEmpty {
                        Text("No inventory items available. Create inventory items first.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(spacing: 8) {
                            Text("Select items to add to this vehicle:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(inventoryItems.prefix(10), id: \.id) { item in
                                HStack {
                                    Button(action: {
                                        if selectedInventoryItems.contains(item.id) {
                                            selectedInventoryItems.remove(item.id)
                                            inventoryQuantities.removeValue(forKey: item.id)
                                        } else {
                                            selectedInventoryItems.insert(item.id)
                                            inventoryQuantities[item.id] = 1
                                        }
                                    }) {
                                        Image(systemName: selectedInventoryItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedInventoryItems.contains(item.id) ? .blue : .secondary)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .font(.subheadline)
                                        Text(item.category)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedInventoryItems.contains(item.id) {
                                        Stepper("Qty: \(inventoryQuantities[item.id] ?? 1)", 
                                               value: Binding(
                                                get: { inventoryQuantities[item.id] ?? 1 },
                                                set: { inventoryQuantities[item.id] = $0 }
                                               ), 
                                               in: 1...100)
                                        .labelsHidden()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var reviewSection: some View {
        Section {
            VStack(spacing: 16) {
                Text("Review & Create")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Vehicle:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(year) \(make) \(model)")
                    }
                    
                    HStack {
                        Text("VIN:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(vin)
                    }
                    
                    HStack {
                        Text("License Plate:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(licensePlate.isEmpty ? "Not specified" : licensePlate)
                    }
                    
                    if let technicianId = selectedTechnicianId,
                       let technician = availableTechnicians.first(where: { $0.id == technicianId }) {
                        HStack {
                            Text("Assigned to:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(technician.fullName ?? technician.email)
                        }
                    }
                    
                    if enableSamsaraTracking || enableAppleGPSTracking {
                        HStack {
                            Text("GPS Tracking:")
                                .fontWeight(.medium)
                            Spacer()
                            VStack(alignment: .trailing) {
                                if enableSamsaraTracking {
                                    Text("Samsara")
                                }
                                if enableAppleGPSTracking {
                                    Text("Apple GPS")
                                }
                            }
                        }
                    }
                    
                    if addInitialInventory && !selectedInventoryItems.isEmpty {
                        HStack {
                            Text("Initial Inventory:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(selectedInventoryItems.count) items")
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                if isCreating {
                    ProgressView("Creating vehicle...")
                        .padding()
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1:
            return !make.isEmpty && !model.isEmpty && year > 1900 && !vin.isEmpty
        case 2:
            return true // Technician assignment is optional
        case 3:
            return true // GPS tracking is optional
        case 4:
            return true // Initial inventory is optional
        default:
            return isFormValid
        }
    }
    
    // MARK: - Actions
    
    private func createVehicle() {
        guard isFormValid else {
            errorMessage = "Please fill in all required fields"
            showingError = true
            return
        }
        
        isCreating = true
        
        Task {
            do {
                // Create the vehicle
                let vehicle = Vehix.Vehicle(
                    make: make,
                    model: model,
                    year: year,
                    vin: vin,
                    licensePlate: licensePlate.isEmpty ? nil : licensePlate,
                    color: color.isEmpty ? nil : color,
                    mileage: mileage,
                    notes: notes.isEmpty ? nil : notes,
                    isTrackedBySamsara: enableSamsaraTracking,
                    photoData: photoData
                )
                
                // Set vehicle type
                vehicle.vehicleType = vehicleType.rawValue
                
                // Generate Samsara ID if tracking is enabled
                if enableSamsaraTracking {
                    vehicle.samsaraVehicleId = "SAM-\(UUID().uuidString.prefix(8))"
                }
                
                modelContext.insert(vehicle)
                
                // Create technician assignment if selected
                if let technicianId = selectedTechnicianId,
                   let technician = availableTechnicians.first(where: { $0.id == technicianId }) {
                    let assignment = VehicleAssignment(
                        vehicleId: vehicle.id,
                        userId: technician.id,
                        startDate: assignmentStartDate,
                        endDate: nil,
                        vehicle: vehicle,
                        user: technician
                    )
                    modelContext.insert(assignment)
                }
                
                // Add initial inventory if selected
                if addInitialInventory {
                    for itemId in selectedInventoryItems {
                        if let item = inventoryItems.first(where: { $0.id == itemId }),
                           let quantity = inventoryQuantities[itemId] {
                            let stockItem = StockLocationItem(
                                inventoryItem: item,
                                quantity: quantity,
                                minimumStockLevel: max(1, quantity / 4), // Set minimum to 25% of initial
                                vehicle: vehicle
                            )
                            modelContext.insert(stockItem)
                        }
                    }
                }
                
                try modelContext.save()
                
                // Update StoreKit manager counts
                await MainActor.run {
                    storeKitManager.updateCounts(
                        staff: storeKitManager.currentStaffCount,
                        vehicles: storeKitManager.currentVehicleCount + 1,
                        technicians: storeKitManager.currentTechnicianCount
                    )
                }
                
                await MainActor.run {
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create vehicle: \(error.localizedDescription)"
                    showingError = true
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    AddVehicleForm()
        .environmentObject(AppAuthService())
        .environmentObject(StoreKitManager())
        .environmentObject(SamsaraService())
} 