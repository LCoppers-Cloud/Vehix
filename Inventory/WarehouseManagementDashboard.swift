import SwiftUI
import SwiftData

struct WarehouseManagementDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var authService: AppAuthService
    
    @State private var showingAddWarehouse = false
    @State private var selectedWarehouse: AppWarehouse?
    @State private var showingWarehouseDetail = false
    @State private var searchText = ""
    @State private var sortBy: WarehouseSortOption = .name
    @State private var showingDeleteConfirmation = false
    @State private var warehouseToDelete: AppWarehouse?
    
    private var filteredWarehouses: [AppWarehouse] {
        var warehouses = inventoryManager.warehouses
        
        // Apply search filter
        if !searchText.isEmpty {
            warehouses = warehouses.filter { warehouse in
                warehouse.name.localizedCaseInsensitiveContains(searchText) ||
                warehouse.location.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        switch sortBy {
        case .name:
            warehouses.sort { $0.name < $1.name }
        case .location:
            warehouses.sort { $0.location < $1.location }
        case .itemCount:
            warehouses.sort { ($0.stockItems?.count ?? 0) > ($1.stockItems?.count ?? 0) }
        case .value:
            warehouses.sort { 
                inventoryManager.getInventoryValue(for: $0) > inventoryManager.getInventoryValue(for: $1)
            }
        }
        
        return warehouses
    }
    
    private var totalInventoryValue: Double {
        inventoryManager.warehouses.reduce(0) { total, warehouse in
            total + inventoryManager.getInventoryValue(for: warehouse)
        }
    }
    
    private var totalItemCount: Int {
        inventoryManager.warehouses.reduce(0) { total, warehouse in
            total + (warehouse.stockItems?.count ?? 0)
        }
    }
    
    private var lowStockWarehouseCount: Int {
        inventoryManager.warehouses.filter { warehouse in
            warehouse.stockItems?.contains { $0.isBelowMinimumStock } ?? false
        }.count
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary header
                summaryHeaderView
                
                // Search and sort controls
                searchAndSortView
                
                // Warehouse list
                if filteredWarehouses.isEmpty {
                    if inventoryManager.warehouses.isEmpty {
                        emptyStateView
                    } else {
                        noResultsView
                    }
                } else {
                    warehouseGridView
                }
            }
            .navigationTitle("Warehouse Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddWarehouse = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddWarehouse) {
                AddWarehouseView()
            }
            .sheet(isPresented: $showingWarehouseDetail) {
                if let warehouse = selectedWarehouse {
                    WarehouseDetailView(warehouse: warehouse)
                }
            }
            .alert("Delete Warehouse", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteWarehouse()
                }
                Button("Cancel", role: .cancel) {
                    warehouseToDelete = nil
                }
            } message: {
                if let warehouse = warehouseToDelete {
                    Text("Are you sure you want to delete '\(warehouse.name)'? This will permanently remove all inventory data for this warehouse.")
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var summaryHeaderView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Warehouse Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(inventoryManager.warehouses.count) locations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                WarehouseSummaryCard(
                    title: "Total Value",
                    value: totalInventoryValue.formatted(.currency(code: "USD")),
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                WarehouseSummaryCard(
                    title: "Total Items",
                    value: "\(totalItemCount)",
                    icon: "box.fill",
                    color: .blue
                )
                
                WarehouseSummaryCard(
                    title: "Low Stock",
                    value: "\(lowStockWarehouseCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: lowStockWarehouseCount > 0 ? .orange : .gray
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var searchAndSortView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search warehouses...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .cornerRadius(8)
            
            // Sort options
            HStack {
                Text("Sort by:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Sort", selection: $sortBy) {
                    Text("Name").tag(WarehouseSortOption.name)
                    Text("Location").tag(WarehouseSortOption.location)
                    Text("Item Count").tag(WarehouseSortOption.itemCount)
                    Text("Value").tag(WarehouseSortOption.value)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private var warehouseGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(filteredWarehouses) { warehouse in
                    WarehouseCard(
                        warehouse: warehouse,
                        inventoryManager: inventoryManager,
                        isManager: isManager,
                        onTap: {
                            selectedWarehouse = warehouse
                            showingWarehouseDetail = true
                        },
                        onSelect: {
                            inventoryManager.selectedWarehouse = warehouse
                        },
                        onDelete: {
                            warehouseToDelete = warehouse
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Warehouses Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first warehouse to start managing inventory locations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { showingAddWarehouse = true }) {
                Label("Create First Warehouse", systemImage: "plus.circle.fill")
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
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No Results Found")
                .font(.headline)
            
            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Clear Search") {
                searchText = ""
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var isManager: Bool {
        authService.currentUser?.userRole == .admin || 
        authService.currentUser?.userRole == .dealer
    }
    
    private func deleteWarehouse() {
        guard let warehouse = warehouseToDelete else { return }
        
        Task {
            let result = await inventoryManager.deleteWarehouse(warehouse, managerPassword: "admin1234")
            
            await MainActor.run {
                warehouseToDelete = nil
                if !result.success {
                    // Handle error if needed
                    print("Failed to delete warehouse: \(result.message)")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct WarehouseSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct WarehouseCard: View {
    let warehouse: AppWarehouse
    let inventoryManager: InventoryManager
    let isManager: Bool
    let onTap: () -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void
    
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
    
    private var isSelected: Bool {
        warehouse.id == inventoryManager.selectedWarehouse?.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(warehouse.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(warehouse.location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Menu {
                    Button(action: onTap) {
                        Label("View Details", systemImage: "eye")
                    }
                    
                    Button(action: onSelect) {
                        Label(isSelected ? "Selected" : "Select", systemImage: "checkmark.circle")
                    }
                    
                    if isManager {
                        Divider()
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // Status indicators
            HStack {
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
                
                if isSelected {
                    Text("SELECTED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            // Stats
            VStack(spacing: 8) {
                HStack {
                    Text("Value:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(inventoryValue.formatted(.currency(code: "USD")))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Items:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(itemCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Quantity:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(totalQuantity)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                if lowStockCount > 0 {
                    HStack {
                        Text("Low Stock:")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                        Text("\(lowStockCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Quick action button
            Button(action: onTap) {
                Text("View Details")
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Enums

enum WarehouseSortOption: String, CaseIterable {
    case name = "Name"
    case location = "Location"
    case itemCount = "Item Count"
    case value = "Value"
}

#Preview {
    WarehouseManagementDashboard()
        .environmentObject(InventoryManager())
        .environmentObject(AppAuthService())
} 