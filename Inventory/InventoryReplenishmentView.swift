import SwiftUI
import SwiftData


struct InventoryReplenishmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var usageManager = InventoryUsageManager()
    @State private var selectedTab = 0 // 0 = Warehouse, 1 = Vehicles
    @State private var isLoading = false
    @State private var showingGeneratePOAlert = false
    @State private var showingSuccessAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Warehouse").tag(0)
                    Text("Vehicles").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if isLoading {
                    loadingView
                } else if selectedTab == 0 {
                    warehouseReplenishmentView
                } else {
                    vehicleReplenishmentView
                }
                
                Spacer()
                
                if selectedTab == 0 && !usageManager.needsReplenishment.isEmpty {
                    // Generate Purchase Order button
                    Button(action: {
                        showingGeneratePOAlert = true
                    }) {
                        Text("Generate Purchase Orders")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .navigationTitle("Inventory Replenishment")
            .alert("Generate Purchase Orders", isPresented: $showingGeneratePOAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Generate") {
                    generatePurchaseOrders()
                }
            } message: {
                Text("This will create purchase orders for all items that need replenishment. Continue?")
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                usageManager.setModelContext(modelContext)
                loadReplenishmentData()
            }
        }
    }
    
    // Loading view
    private var loadingView: some View {
        VStack {
            ProgressView()
                .padding()
            
            Text("Loading inventory data...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Warehouse replenishment view
    private var warehouseReplenishmentView: some View {
        Group {
            if usageManager.needsReplenishment.isEmpty {
                emptyWarehouseView
            } else {
                List {
                    ForEach(usageManager.needsReplenishment) { item in
                        WarehouseItemRow(item: item)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
    }
    
    // Empty warehouse view
    private var emptyWarehouseView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .padding()
            
            Text("All Inventory Levels Are Good")
                .font(.headline)
            
            Text("There are no items that need replenishment at this time.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: loadReplenishmentData) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    // Vehicle replenishment view
    private var vehicleReplenishmentView: some View {
        VStack {
            // Add manual refresh button at the top
            HStack {
                Spacer()
                Button(action: {
                    Task {
                        await refreshVehicleData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(.trailing)
            }
            
            ScrollView {
                if usageManager.vehicleReplenishmentItems.isEmpty {
                    emptyVehicleView
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(usageManager.vehicleReplenishmentItems.keys), id: \.self) { vehicleId in
                            VehicleReplenishmentSection(
                                vehicleId: vehicleId,
                                items: usageManager.vehicleReplenishmentItems[vehicleId] ?? [],
                                onCreateTask: {
                                    createVehicleReplenishmentTask(for: vehicleId)
                                },
                                technicianNameProvider: { vehicle in currentAssignedTechnicianName(modelContext: modelContext, vehicle: vehicle) }
                            )
                            .onAppear {
                                // Load vehicle data when section appears
                                Task {
                                    await loadVehicleData(for: vehicleId)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }
    
    // Empty vehicle view
    private var emptyVehicleView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .padding()
            
            Text("All Vehicles Are Stocked")
                .font(.headline)
            
            Text("There are no vehicles that need inventory replenishment at this time.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: loadReplenishmentData) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    // Load replenishment data
    private func loadReplenishmentData() {
        isLoading = true
        
        Task {
            await usageManager.loadReplenishmentNeeds()
            
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }
    
    // Generate purchase orders for warehouse replenishment
    private func generatePurchaseOrders() {
        Task {
            if let po = await usageManager.generateWarehouseReplenishmentOrder() {
                DispatchQueue.main.async {
                    alertMessage = "Purchase Order \(po.poNumber) generated successfully."
                    showingSuccessAlert = true
                    loadReplenishmentData() // Refresh data
                }
            } else {
                DispatchQueue.main.async {
                    alertMessage = "Failed to generate purchase orders. Please try again."
                    showingSuccessAlert = true
                }
            }
        }
    }
    
    // Create vehicle replenishment task
    private func createVehicleReplenishmentTask(for vehicleId: String) {
        Task {
            if let taskId = await usageManager.createVehicleReplenishmentTask(for: vehicleId) {
                DispatchQueue.main.async {
                    alertMessage = "Replenishment Task \(taskId) created successfully."
                    showingSuccessAlert = true
                    loadReplenishmentData() // Refresh data
                }
            } else {
                DispatchQueue.main.async {
                    alertMessage = "Failed to create replenishment task. Please try again."
                    showingSuccessAlert = true
                }
            }
        }
    }
    
    // Load vehicle data
    private func loadVehicleData(for vehicleId: String) async {
        await usageManager.loadVehicleData(for: vehicleId)
    }
    
    // Refresh vehicle data
    private func refreshVehicleData() async {
        await usageManager.fetchVehicleReplenishmentData()
    }
    
    // Move this helper function outside the struct and mark as fileprivate
    fileprivate func currentAssignedTechnicianName(modelContext: ModelContext, vehicle: AppVehicle) -> String? {
        let now = Date()
        let vehicleId = vehicle.id
        do {
            let assignmentDescriptor = FetchDescriptor<VehicleAssignment>(
                predicate: #Predicate<VehicleAssignment> { assignment in
                    assignment.vehicleId == vehicleId
                }
            )
            let assignments = try modelContext.fetch(assignmentDescriptor)
            let validAssignments = assignments.filter { $0.endDate == nil || ($0.endDate ?? .distantFuture) > now }
            if let assignment = validAssignments.first, let user = assignment.user {
                return user.fullName ?? user.email
            }
        } catch {
            return nil
        }
        return nil
    }
}

// Warehouse item row
struct WarehouseItemRow: View {
    let item: AppInventoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(.headline)
            
            // Handle non-optional partNumber
            Text("Part #: \(item.partNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Stock: \(item.totalQuantity)")
                        .font(.callout)
                    
                    Text("Reorder Point: \(item.reorderPoint)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    // Calculate this inline to avoid using custom extension property
                    let totalQty = item.totalQuantity
                    let suggestedOrder = max(1, item.reorderPoint * 2 - totalQty)
                    Text("Suggested Order: \(suggestedOrder)")
                        .font(.callout)
                        .foregroundColor(.blue)
                    
                    if let supplier = item.supplier, !supplier.isEmpty {
                        Text("Supplier: \(supplier)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Safely check the estimated days using the computed property
            let daysUntilDepletion = item.estimatedDaysUntilDepletion
            if daysUntilDepletion < 30 {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    
                    Text("Will deplete in \(daysUntilDepletion) days at current usage")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

// Vehicle replenishment section
struct VehicleReplenishmentSection: View {
    let vehicleId: String
    let items: [AppInventoryItem]
    let onCreateTask: () -> Void
    let technicianNameProvider: (AppVehicle) -> String?
    
    @Environment(\.modelContext) private var modelContext
    @State private var vehicle: AppVehicle?
    @State private var isExpanded = true
    
    var body: some View {
        Group {
            if let vehicle = vehicle {
                DisclosureGroup(
                    isExpanded: $isExpanded,
                    content: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                                .font(.headline)
                            
                            if let licensePlate = vehicle.licensePlate, !licensePlate.isEmpty {
                                Text("Plate: \(licensePlate)")
                                    .font(.subheadline)
                            }
                            
                            // Assigned technician
                            if let techName = technicianNameProvider(vehicle) {
                                Text("Assigned to: \(techName)")
                                    .font(.caption)
                            }
                            
                            // Items list
                            ForEach(items) { item in
                                VehicleItemRow(item: item)
                            }
                            
                            // Create task button
                            Button(action: onCreateTask) {
                                Text("Create Replenishment Task")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding(.top)
                        }
                    },
                    label: {
                        Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                            .font(.headline)
                    }
                )
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
            } else {
                Text("Vehicle not found")
                    .italic()
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .onAppear {
            // Call loadVehicle when the view appears to ensure data is loaded
            loadVehicle()
        }
    }
    
    private func loadVehicle() {
        Task {
            do {
                // iOS 18+ compatible approach with async/await pattern
                let descriptor = FetchDescriptor<AppVehicle>()
                let allVehicles = try modelContext.fetch(descriptor)
                DispatchQueue.main.async {
                    self.vehicle = allVehicles.first(where: { $0.id == vehicleId })
                }
            } catch {
                print("Error loading vehicle: \(error.localizedDescription)")
            }
        }
    }
}

// Vehicle item row
struct VehicleItemRow: View {
    let item: AppInventoryItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                
                if !item.partNumber.isEmpty {
                    Text(item.partNumber)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Current: \(item.totalQuantity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let totalQty = item.totalQuantity
                let suggestedQuantity = max(1, item.reorderPoint * 2 - totalQty)
                Text("Needed: \(suggestedQuantity)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}

// Model for vehicle replenishment items
struct ReplenishmentItem: Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var partNumber: String
    var quantity: Int
    var minimumRequired: Int
    var suggestedReplenishmentQuantity: Int
    
    // Create from an inventory item
    static func from(_ item: AppInventoryItem) -> ReplenishmentItem {
        let totalQty = item.totalQuantity
        let minLevel = (item.stockLocationItems?.first?.minimumStockLevel ?? 0)
        
        return ReplenishmentItem(
            id: item.id,
            name: item.name,
            partNumber: item.partNumber,
            quantity: totalQty,
            minimumRequired: minLevel,
            suggestedReplenishmentQuantity: max(1, item.reorderPoint * 2 - totalQty)
        )
    }
}

// Note: All AppInventoryItem extension properties used in this view are 
// already defined in InventoryItemExtended.swift

#Preview {
    InventoryReplenishmentView()
} 