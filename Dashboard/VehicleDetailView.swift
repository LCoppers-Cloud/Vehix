import SwiftUI
import SwiftData

struct VehicleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    let vehicle: AppVehicle
    
    @State private var showingEditSheet = false
    @State private var showingSamsaraDetails = false
    @State private var showDeleteConfirmation = false
    @State private var showingAddInventory = false
    @State private var showingInventoryDetail = false
    @State private var selectedStockItem: StockLocationItem?
    @State private var showingAssignmentHistory = false
    
    // Queries for related data
    @Query private var allInventoryItems: [AppInventoryItem]
    @Query private var allUsers: [AuthUser]
    @Query private var assignments: [VehicleAssignment]
    
    // Computed properties
    private var vehicleAssignments: [VehicleAssignment] {
        assignments.filter { $0.vehicleId == vehicle.id }
    }
    
    private var currentAssignment: VehicleAssignment? {
        vehicleAssignments.first { $0.endDate == nil }
    }
    
    private var assignedTechnician: AuthUser? {
        guard let assignment = currentAssignment else { return nil }
        return allUsers.first { $0.id == assignment.userId }
    }
    
    private var canManageVehicles: Bool {
        guard let userRole = authService.currentUser?.userRole else { return false }
        return userRole == .admin || userRole == .dealer || userRole == .premium
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Vehicle Header
                vehicleHeaderSection
                
                // Quick Stats
                quickStatsSection
                
                // Current Assignment
                if let assignment = currentAssignment {
                    currentAssignmentSection(assignment)
                }
                
                // Inventory Section
                inventorySection
                
                // Actions Section
                if canManageVehicles {
                    actionsSection
                }
            }
            .padding()
        }
        .navigationTitle("Vehicle Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit Vehicle") {
                        showingEditSheet = true
                    }
                    
                    if canManageVehicles {
                        Button("Assignment History") {
                            showingAssignmentHistory = true
                        }
                        
                        Button("Add Inventory") {
                            showingAddInventory = true
                        }
                        
                        Divider()
                        
                        Button("Delete Vehicle", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditVehicleForm(vehicle: vehicle)
        }
        .sheet(isPresented: $showingAddInventory) {
            AddInventoryToVehicleView(vehicle: vehicle)
        }
        .sheet(isPresented: $showingInventoryDetail) {
            if let stockItem = selectedStockItem {
                VehicleInventoryDetailView(stockItem: stockItem, vehicle: vehicle)
            }
        }
        .sheet(isPresented: $showingAssignmentHistory) {
            VehicleAssignmentHistoryView(vehicle: vehicle, assignments: vehicleAssignments)
        }
        .alert("Delete Vehicle", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteVehicle()
            }
        } message: {
            Text("Are you sure you want to delete this vehicle? This action cannot be undone.")
        }
    }
    
    // MARK: - Vehicle Header Section
    private var vehicleHeaderSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vehicle.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("VIN: \(vehicle.vin)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let plate = vehicle.licensePlate {
                        Text("License: \(plate)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "car.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Text("\(vehicle.mileage) mi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Quick Stats Section
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Stats")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Inventory Items",
                    value: "\(vehicle.stockItems?.count ?? 0)",
                    subtitle: "Items",
                    icon: "cube.box.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Assignments",
                    value: "\(vehicleAssignments.count)",
                    subtitle: "Total",
                    icon: "person.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Status",
                    value: currentAssignment != nil ? "Assigned" : "Available",
                    subtitle: "Current",
                    icon: currentAssignment != nil ? "checkmark.circle.fill" : "circle",
                    color: currentAssignment != nil ? .green : .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Current Assignment Section
    private func currentAssignmentSection(_ assignment: VehicleAssignment) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Assignment")
                    .font(.headline)
                
                Spacer()
                
                Text("ACTIVE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            
            if let technician = assignedTechnician {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(technician.fullName ?? "Unknown Technician")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(technician.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Started: \(assignment.startDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        let days = Calendar.current.dateComponents([.day], from: assignment.startDate, to: Date()).day ?? 0
                        Text("\(days)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text("days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Inventory Section
    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Vehicle Inventory")
                    .font(.headline)
                
                Spacer()
                
                if canManageVehicles {
                    Button("Add Item") {
                        showingAddInventory = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if let stockItems = vehicle.stockItems, !stockItems.isEmpty {
                VStack(spacing: 8) {
                    ForEach(stockItems, id: \.id) { stockItem in
                        InventoryItemRow(
                            stockItem: stockItem,
                            onTap: {
                                selectedStockItem = stockItem
                                showingInventoryDetail = true
                            }
                        )
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cube.box")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No Inventory Items")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if canManageVehicles {
                        Button("Add First Item") {
                            showingAddInventory = true
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: { showingAssignmentHistory = true }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Assignment History")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Button(action: { showingEditSheet = true }) {
                HStack {
                    Image(systemName: "pencil.circle")
                    Text("Edit Vehicle")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Helper Functions
    private func deleteVehicle() {
        modelContext.delete(vehicle)
        do {
            try modelContext.save()
        } catch {
            print("Error deleting vehicle: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct InventoryItemRow: View {
    let stockItem: StockLocationItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stockItem.inventoryItem?.name ?? "Unknown Item")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Text("Qty: \(stockItem.quantity)")
                            .font(.caption)
                            .foregroundColor(stockItem.isBelowMinimumStock ? .red : .secondary)
                        
                        Text("Min: \(stockItem.minimumStockLevel)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let max = stockItem.maxStockLevel {
                            Text("Max: \(max)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let price = stockItem.inventoryItem?.pricePerUnit {
                        Text("$\(String(format: "%.2f", Double(stockItem.quantity) * price))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    if stockItem.isBelowMinimumStock {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VehicleDetailView(vehicle: AppVehicle(
        make: "Ford",
        model: "Transit",
        year: 2022,
        vin: "1234567890",
        licensePlate: "ABC123",
        mileage: 50000
    ))
    .environmentObject(AppAuthService())
    .modelContainer(for: [AppVehicle.self, VehicleAssignment.self], inMemory: true)
} 