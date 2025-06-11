import SwiftUI
import SwiftData

struct WarehousesView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var authService: AppAuthService
    @State private var showingAddWarehouse = false
    @State private var showingDeleteConfirmation = false
    @State private var warehouseToDelete: AppWarehouse?
    @State private var deletePassword = ""
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if inventoryManager.warehouses.isEmpty {
                    emptyStateView
                } else {
                    warehouseListView
                }
            }
            .navigationTitle("Warehouses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddWarehouse = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddWarehouse) {
                AddWarehouseView()
            }
            .alert("Delete Warehouse", isPresented: $showingDeleteConfirmation) {
                SecureField("Manager Password", text: $deletePassword)
                Button("Delete", role: .destructive) {
                    deleteWarehouse()
                }
                Button("Cancel", role: .cancel) {
                    warehouseToDelete = nil
                    deletePassword = ""
                }
            } message: {
                if let warehouse = warehouseToDelete {
                    Text("Are you sure you want to delete '\(warehouse.name)'? This will permanently remove all inventory data for this warehouse. Enter your manager password to confirm.")
                }
            }
            .alert("Error", isPresented: $showingDeleteError) {
                Button("OK") { }
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Welcome to Warehouse Management")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Get started by creating your first warehouse location")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Text("Warehouses help you:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Organize inventory by location", systemImage: "mappin.and.ellipse")
                    Label("Track stock levels and transfers", systemImage: "arrow.left.arrow.right")
                    Label("Generate reports and analytics", systemImage: "chart.bar.fill")
                    Label("Manage multiple storage facilities", systemImage: "building.columns")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.vertical)
            
            Button(action: { showingAddWarehouse = true }) {
                Label("Create Your First Warehouse", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var warehouseListView: some View {
        List {
            ForEach(inventoryManager.warehouses) { warehouse in
                NavigationLink(destination: WarehouseDetailView(warehouse: warehouse)) {
                    WarehouseRowView(
                        warehouse: warehouse,
                        inventoryManager: inventoryManager,
                        isSelected: warehouse.id == inventoryManager.selectedWarehouse?.id
                    )
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if isManager {
                        Button(role: .destructive) {
                            warehouseToDelete = warehouse
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    
                    Button {
                        // Set as selected warehouse
                        inventoryManager.selectedWarehouse = warehouse
                    } label: {
                        Label("Select", systemImage: "checkmark.circle")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        // Quick view inventory levels
                        inventoryManager.selectedWarehouse = warehouse
                    } label: {
                        Label("View Stock", systemImage: "eye")
                    }
                    .tint(.green)
                }
            }
        }
    }
    
    private var isManager: Bool {
        authService.currentUser?.userRole == .admin || 
        authService.currentUser?.userRole == .dealer
    }
    
    private func deleteWarehouse() {
        guard let warehouse = warehouseToDelete else { return }
        
        Task {
            let result = await inventoryManager.deleteWarehouse(warehouse, managerPassword: deletePassword)
            
            await MainActor.run {
                if result.success {
                    warehouseToDelete = nil
                    deletePassword = ""
                } else {
                    deleteErrorMessage = result.message
                    showingDeleteError = true
                }
            }
        }
    }
}

// Enhanced Warehouse Row View with inventory levels and value
struct WarehouseRowView: View {
    let warehouse: AppWarehouse
    let inventoryManager: InventoryManager
    let isSelected: Bool
    
    private var inventoryValue: Double {
        inventoryManager.getInventoryValue(for: warehouse)
    }
    
    private var itemCount: Int {
        warehouse.stockItems?.count ?? 0
    }
    
    private var totalQuantity: Int {
        warehouse.stockItems?.reduce(0) { $0 + $1.quantity } ?? 0
    }
    
    private var lowStockCount: Int {
        warehouse.stockItems?.filter { $0.isBelowMinimumStock }.count ?? 0
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // Warehouse name and status
                HStack {
                    Text(warehouse.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if !warehouse.isActive {
                        Text("INACTIVE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                }
                
                // Location
                if !warehouse.location.isEmpty {
                    Text(warehouse.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Description
                if warehouse.hasDescription {
                    Text(warehouse.warehouseDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Inventory summary
                HStack(spacing: 16) {
                    // Item count
                    HStack(spacing: 4) {
                        Image(systemName: "box.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("\(itemCount) items")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    // Total quantity
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("\(totalQuantity) qty")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    // Low stock warning
                    if lowStockCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(lowStockCount) low")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // Inventory value
                Text("Value: \(inventoryValue, format: .currency(code: "USD"))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                
                // Quick stats
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(inventoryValue, format: .currency(code: "USD"))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Total Value")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

// Add Warehouse View
struct AddWarehouseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var inventoryManager: InventoryManager
    
    @State private var name = ""
    @State private var location = ""
    @State private var description = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Warehouse Details")) {
                    TextField("Name", text: $name)
                    TextField("Location/Address", text: $location)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section {
                    Text("After creating this warehouse, you can:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Add inventory items to this location", systemImage: "plus.circle")
                        Label("Transfer items between warehouses", systemImage: "arrow.left.arrow.right")
                        Label("Set minimum stock levels", systemImage: "chart.line.uptrend.xyaxis")
                        Label("Generate inventory reports", systemImage: "doc.text")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Warehouse")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    inventoryManager.createWarehouse(name: name, address: location, description: description)
                    dismiss()
                }
                .disabled(name.isEmpty || location.isEmpty)
            )
        }
    }
}

#Preview {
    WarehousesView()
        .environmentObject(InventoryManager())
        .environmentObject(AppAuthService())
}

