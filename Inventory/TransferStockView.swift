import SwiftUI
import SwiftData

/// A sheet view for managers to initiate a stock transfer from a warehouse to a vehicle.
struct TransferStockView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService // To get requesting manager
    
    /// The specific stock item record in the warehouse being transferred FROM.
    let sourceStockItem: StockLocationItem
    
    /// State for the transfer details.
    @State private var quantityToTransfer: Int = 1
    @State private var selectedVehicleId: String? = nil
    @State private var notes: String = ""
    
    /// State for loading vehicles.
    @State private var targetVehicles: [Vehix.Vehicle] = []
    @State private var isLoadingVehicles = false
    @State private var errorMessage: String? = nil

    /// Computed property to get the linked inventory item definition.
    private var inventoryItem: AppInventoryItem? {
        sourceStockItem.inventoryItem
    }
    
    /// Computed property for validation.
    private var isTransferValid: Bool {
        guard let vehicleId = selectedVehicleId, !vehicleId.isEmpty, 
              quantityToTransfer > 0, 
              quantityToTransfer <= sourceStockItem.quantity else { // Check against available qty
            return false
        }
        return true
    }

    var body: some View {
        NavigationView {
            Form {
                // Section: Item Details (Read-only)
                Section("Item Details") {
                    if let item = inventoryItem {
                        HStack {
                            Text("Item:")
                            Spacer()
                            Text(item.name).foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Part #:")
                            Spacer()
                            Text(item.partNumber).foregroundColor(.secondary)
                        }
                    } else {
                        Text("Error: Item details not found.").foregroundColor(.red)
                    }
                    HStack {
                        Text("From:")
                        Spacer()
                        Text(sourceStockItem.locationName).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Available Qty:")
                        Spacer()
                        Text("\(sourceStockItem.quantity)").foregroundColor(.secondary)
                    }
                }
                
                // Section: Transfer Details
                Section("Transfer Details") {
                    // Vehicle Picker
                    Picker("Transfer To Vehicle*", selection: $selectedVehicleId) {
                        if isLoadingVehicles {
                            ProgressView()
                        } else {
                            Text("Select Vehicle").tag(String?.none) // Placeholder
                            ForEach(targetVehicles) { vehicle in
                                Text(vehicle.displayName).tag(vehicle.id as String?) // Tag with Optional ID
                            }
                        }
                    }
                    .onAppear(perform: loadVehicles)
                    
                    // Quantity Stepper/TextField
                    Stepper("Quantity to Transfer*: \(quantityToTransfer)", 
                            value: $quantityToTransfer, 
                            in: 1...sourceStockItem.quantity) // Max is available quantity
                    
                    // Optional Notes
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                }
                
                // Error Message Display
                if let error = errorMessage {
                    Section {
                        Text("Error: \(error)").foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Request Stock Transfer")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Request Transfer") {
                        initiateTransferRequest()
                    }
                    .disabled(!isTransferValid || isLoadingVehicles)
                }
            }
        }
    }
    
    /// Fetches the list of vehicles available for transfer.
    private func loadVehicles() {
        isLoadingVehicles = true
        errorMessage = nil
        Task {
            do {
                let descriptor = FetchDescriptor<Vehix.Vehicle>(sortBy: [SortDescriptor(\Vehix.Vehicle.make), SortDescriptor(\Vehix.Vehicle.model)])
                targetVehicles = try modelContext.fetch(descriptor)
            } catch {
                print("Failed to load vehicles: \(error)")
                errorMessage = "Could not load vehicle list."
            }
            isLoadingVehicles = false
        }
    }
    
    /// Handles the creation of the PendingTransfer record and initiates notification.
    private func initiateTransferRequest() {
        guard isTransferValid, 
              let manager = authService.currentUser, 
              let item = inventoryItem, 
              let sourceWarehouse = sourceStockItem.warehouse, // Assuming source is always warehouse
              let vehicleId = selectedVehicleId,
              let targetVehicle = targetVehicles.first(where: { $0.id == vehicleId }) 
        else {
            errorMessage = "Invalid data for transfer."
            return
        }

        // ** TODO: Find the currently assigned technician for the targetVehicle **
        // This requires querying VehicleAssignment based on targetVehicle.id and current date
        let assignedTechnician: AuthUser? = findTechnicianForVehicle(vehicleId: vehicleId)
        
        guard let technician = assignedTechnician else {
             errorMessage = "Could not find currently assigned technician for this vehicle."
             // Optionally allow transfer anyway, but without notification/acceptance?
             return
         }

        // ** Create PendingTransfer record **
        let newTransfer = PendingTransfer(
            quantity: quantityToTransfer,
            notes: notes.isEmpty ? nil : notes,
            inventoryItem: item,
            fromWarehouse: sourceWarehouse,
            toVehicle: targetVehicle,
            requestingManager: manager,
            assignedTechnician: technician
        )
        
        modelContext.insert(newTransfer)
        
        // ** TODO: Trigger Push Notification **
        // This requires APNs setup and a way to send the notification (e.g., backend call)
        // sendPushNotification(to: technician, message: "...")

        print("Pending transfer record created: \(newTransfer.id)")
        // Consider saving context explicitly if needed
        // try? modelContext.save()
        
        dismiss() // Dismiss the sheet after initiating
    }
    
    /// Placeholder: Finds the technician currently assigned to the vehicle.
    /// Needs actual implementation using VehicleAssignment model.
    private func findTechnicianForVehicle(vehicleId: String) -> AuthUser? {
        let now = Date()
        // Construct a predicate to find the active assignment for the given vehicle ID
        let vehiclePredicate = #Predicate<VehicleAssignment> { assignment in
            assignment.vehicle?.id == vehicleId && // Match the vehicle ID
            assignment.startDate <= now &&         // Assignment must have started
            (assignment.endDate == nil || assignment.endDate! > now) // Assignment must not have ended
        }
        
        // Sort by start date descending in case of overlaps (take the latest)
        let sortDescriptor = SortDescriptor(\VehicleAssignment.startDate, order: .reverse)
        
        let fetchDescriptor = FetchDescriptor<VehicleAssignment>(predicate: vehiclePredicate, sortBy: [sortDescriptor])
        
        do {
            let assignments = try modelContext.fetch(fetchDescriptor)
            // Return the user from the most recent active assignment
            return assignments.first?.user 
        } catch {
            print("Error fetching vehicle assignment for vehicleId \(vehicleId): \(error)")
            errorMessage = "Could not check vehicle assignment." // Inform the user
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: StockLocationItem.self, AppInventoryItem.self, AppWarehouse.self, 
        Vehix.Vehicle.self, AuthUser.self, VehicleAssignment.self,
        configurations: config
    )
    
    // Set up preview data
    let modelContext = container.mainContext
    let item = AppInventoryItem(name: "Preview Filter", partNumber: "PF-001")
    let warehouse = AppWarehouse(name: "Preview WH", location: "Preview Loc")
    // No vehicles for clean start
    let managerUser = AuthUser(email: "manager@preview.com", role: .admin)
    let techUser = AuthUser(email: "tech@preview.com", role: .technician)
    let sourceStock = StockLocationItem(inventoryItem: item, quantity: 50, minimumStockLevel: 10, warehouse: warehouse)
    
    // No vehicle assignments for clean start
    
    // Insert all the data
    modelContext.insert(item)
    modelContext.insert(warehouse)
    modelContext.insert(managerUser)
    modelContext.insert(techUser)
    modelContext.insert(sourceStock)
    
    // Set up auth service
    let auth = AppAuthService()
    auth.currentUser = managerUser
    
    // Create and return the view
    return TransferStockView(sourceStockItem: sourceStock)
        .modelContainer(container)
        .environmentObject(auth)
} 