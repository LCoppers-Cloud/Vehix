import SwiftUI
import SwiftData

struct InventoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    let inventoryItem: AppInventoryItem
    
    @Query private var allStockItems: [StockLocationItem]
    @Query private var vehicles: [Vehix.Vehicle]
    @Query private var warehouses: [AppWarehouse]
    
    @State private var showingEditSheet = false
    @State private var showingTransferSheet = false
    @State private var showingDeleteAlert = false
    @State private var selectedStockItem: StockLocationItem?
    @State private var showingStockDetail = false
    @State private var showingExportSheet = false
    
    // Computed properties for this specific inventory item
    private var itemStockLocations: [StockLocationItem] {
        allStockItems.filter { $0.inventoryItem?.id == inventoryItem.id }
    }
    
    private var warehouseStock: [StockLocationItem] {
        itemStockLocations.filter { $0.warehouse != nil }
    }
    
    private var vehicleStock: [StockLocationItem] {
        itemStockLocations.filter { $0.vehicle != nil }
    }
    
    private var totalQuantity: Int {
        itemStockLocations.reduce(0) { $0 + $1.quantity }
    }
    
    private var totalValue: Double {
        Double(totalQuantity) * inventoryItem.pricePerUnit
    }
    
    private var warehouseQuantity: Int {
        warehouseStock.reduce(0) { $0 + $1.quantity }
    }
    
    private var vehicleQuantity: Int {
        vehicleStock.reduce(0) { $0 + $1.quantity }
    }
    
    private var lowStockLocations: [StockLocationItem] {
        itemStockLocations.filter { $0.isBelowMinimumStock }
    }
    
    private var outOfStockLocations: [StockLocationItem] {
        itemStockLocations.filter { $0.quantity == 0 }
    }
    
    var body: some View {
        NavigationView {
            SwiftUI.ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // Item Header
                    itemHeaderSection
                    
                    // Summary Cards
                    summarySection
                    
                    // Stock Alerts
                    if !lowStockLocations.isEmpty || !outOfStockLocations.isEmpty {
                        alertsSection
                    }
                    
                    // Warehouse Locations
                    if !warehouseStock.isEmpty {
                        warehouseSection
                    }
                    
                    // Vehicle Locations
                    if !vehicleStock.isEmpty {
                        vehicleSection
                    }
                    
                    // Empty state
                    if itemStockLocations.isEmpty {
                        emptyStateSection
                    }
                    
                    // Actions
                    if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer {
                        actionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Inventory Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                customNavigationHeader
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditInventoryItemView(item: inventoryItem)
        }
        .sheet(isPresented: $showingTransferSheet) {
            Text("Transfer Stock - Coming Soon")
        }
        .sheet(isPresented: $showingStockDetail) {
            if let stockItem = selectedStockItem {
                StockLocationDetailView(stockItem: stockItem)
            }
        }
        .alert("Delete Inventory Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteInventoryItem()
            }
        } message: {
            Text("Are you sure you want to delete this inventory item? This will remove it from all locations and cannot be undone.")
        }
    }
    
    // MARK: - Item Header Section
    private var itemHeaderSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(inventoryItem.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if !inventoryItem.partNumber.isEmpty {
                        Text("Part #: \(inventoryItem.partNumber)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(inventoryItem.category)
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(String(format: "%.2f", inventoryItem.pricePerUnit))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("per unit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let description = inventoryItem.itemDescription, !description.isEmpty {
                HStack {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            if let supplier = inventoryItem.supplier {
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.blue)
                    Text("Supplier: \(supplier)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Summary Section
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Overview")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SummaryCard(
                    title: "Total Quantity",
                    value: "\(totalQuantity)",
                    subtitle: "All locations",
                    icon: "cube.box.fill",
                    color: .blue
                )
                
                SummaryCard(
                    title: "Total Value",
                    value: "$\(String(format: "%.0f", totalValue))",
                    subtitle: "System-wide",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                SummaryCard(
                    title: "Locations",
                    value: "\(itemStockLocations.count)",
                    subtitle: "Active",
                    icon: "location.fill",
                    color: .orange
                )
            }
            
            // Breakdown by location type
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Warehouses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(warehouseQuantity) units")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vehicles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(vehicleQuantity) units")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Avg Cost/Location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !itemStockLocations.isEmpty {
                        Text("$\(String(format: "%.2f", totalValue / Double(itemStockLocations.count)))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Alerts Section
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stock Alerts")
                .font(.headline)
            
            if !outOfStockLocations.isEmpty {
                AlertCard(
                    title: "Out of Stock",
                    count: outOfStockLocations.count,
                    message: "locations have zero inventory",
                    color: .red,
                    icon: "exclamationmark.triangle.fill"
                )
            }
            
            if !lowStockLocations.isEmpty {
                AlertCard(
                    title: "Low Stock",
                    count: lowStockLocations.count,
                    message: "locations below minimum level",
                    color: .orange,
                    icon: "exclamationmark.triangle"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Warehouse Section
    private var warehouseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Warehouse Locations")
                    .font(.headline)
                
                Spacer()
                
                Text("\(warehouseQuantity) units")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                ForEach(warehouseStock, id: \.id) { stockItem in
                    LocationStockRow(
                        stockItem: stockItem,
                        locationName: stockItem.warehouse?.name ?? "Unknown Warehouse",
                        locationType: .warehouse,
                        onTap: {
                            selectedStockItem = stockItem
                            showingStockDetail = true
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Vehicle Section
    private var vehicleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Vehicle Locations")
                    .font(.headline)
                
                Spacer()
                
                Text("\(vehicleQuantity) units")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                ForEach(vehicleStock, id: \.id) { stockItem in
                    if let vehicle = vehicles.first(where: { $0.id == stockItem.vehicle?.id }) {
                        LocationStockRow(
                            stockItem: stockItem,
                            locationName: vehicle.displayName,
                            locationType: .vehicle,
                            onTap: {
                                selectedStockItem = stockItem
                                showingStockDetail = true
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Empty State Section
    private var emptyStateSection: some View {
        EmptyStateView(
            icon: "cube.box",
            title: "No Stock Locations",
            message: "This item hasn't been assigned to any warehouses or vehicles yet.",
            actionTitle: authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer ? "Add to Location" : nil
        ) {
            showingTransferSheet = true
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 12) {
            ActionButton(
                title: "Transfer Stock",
                icon: "arrow.triangle.swap",
                color: .blue
            ) {
                showingTransferSheet = true
            }
            
            ActionButton(
                title: "Edit Item Details",
                icon: "pencil.circle",
                color: .green
            ) {
                showingEditSheet = true
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Helper Functions
    private func deleteInventoryItem() {
        // Delete all associated stock locations first
        for stockItem in itemStockLocations {
            modelContext.delete(stockItem)
        }
        
        // Delete the inventory item
        modelContext.delete(inventoryItem)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error deleting inventory item: \(error)")
        }
    }
    
    private func refreshData() {
        // Refresh the data by triggering a re-fetch
        // In SwiftData, this is typically handled automatically
        // but we can force a refresh if needed
    }
    
    // MARK: - Custom Navigation Header
    private var customNavigationHeader: some View {
        HStack {
            Button("Close") {
                dismiss()
            }
            .foregroundColor(.blue)
            
            Spacer()
            
            Text("Inventory Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button("Export") {
                showingExportSheet = true
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
}

// MARK: - Supporting Views

enum LocationType {
    case warehouse
    case vehicle
    
    var icon: String {
        switch self {
        case .warehouse: return "building.2.fill"
        case .vehicle: return "car.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .warehouse: return .blue
        case .vehicle: return .orange
        }
    }
}

struct LocationStockRow: View {
    let stockItem: StockLocationItem
    let locationName: String
    let locationType: LocationType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: locationType.icon)
                    .foregroundColor(locationType.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(locationName)
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

// Placeholder views for sheets
struct StockLocationDetailView: View {
    let stockItem: StockLocationItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Stock Location Details - Coming Soon")
                .navigationTitle("Location Details")
                .toolbar {
                    Group {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") { dismiss() }
                        }
                    }
                }
        }
    }
}

#Preview {
    InventoryDetailView(inventoryItem: AppInventoryItem(
        name: "Sample Item",
        partNumber: "SP-001",
        itemDescription: "Sample description",
        category: "Sample Category",
        pricePerUnit: 10.99,
        supplier: "Sample Supplier"
    ))
    .environmentObject(AppAuthService())
    .modelContainer(for: [AppInventoryItem.self, StockLocationItem.self], inMemory: true)
} 