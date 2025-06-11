import SwiftUI
import SwiftData

struct VehicleInventoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    @State var stockItem: StockLocationItem
    let vehicle: AppVehicle
    
    @State private var editingQuantity = false
    @State private var editingMinimum = false
    @State private var editingMaximum = false
    @State private var newQuantity = ""
    @State private var newMinimum = ""
    @State private var newMaximum = ""
    @State private var showingTransferSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Query for warehouse stock of the same item
    @Query private var allStockItems: [StockLocationItem]
    
    private var warehouseStock: [StockLocationItem] {
        allStockItems.filter { 
            $0.inventoryItem?.id == stockItem.inventoryItem?.id && 
            $0.warehouse != nil 
        }
    }
    
    private var totalSystemStock: Int {
        allStockItems.filter { $0.inventoryItem?.id == stockItem.inventoryItem?.id }
            .reduce(0) { $0 + $1.quantity }
    }
    
    private var totalSystemValue: Double {
        let price = stockItem.inventoryItem?.pricePerUnit ?? 0
        return Double(totalSystemStock) * price
    }
    
    var body: some View {
        NavigationView {
            SwiftUI.ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // Item Header
                    itemHeaderSection
                    
                    // Current Stock Information
                    currentStockSection
                    
                    // System-wide Stock Overview
                    systemStockSection
                    
                    // Stock Level Management
                    stockLevelManagementSection
                    
                    // Actions Section
                    if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .premium {
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
            .sheet(isPresented: $showingTransferSheet) {
                NavigationView {
                    VStack {
                        Text("Transfer Stock - Coming Soon")
                            .font(.title2)
                            .padding()
                        
                        Text("This feature will allow you to transfer stock from this vehicle.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Spacer()
                    }
                    .navigationTitle("Transfer Stock")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                showingTransferSheet = false
                            }
                        }
                    }
                }
            }
            .alert("Delete Item", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteStockItem()
                }
            } message: {
                Text("Are you sure you want to remove this item from the vehicle? This will delete the stock record but not the inventory item itself.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                setupEditingValues()
            }
        }
    }
    
    // MARK: - Item Header Section
    private var itemHeaderSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(stockItem.inventoryItem?.name ?? "Unknown Item")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let category = stockItem.inventoryItem?.category {
                        Text(category)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let description = stockItem.inventoryItem?.itemDescription, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let price = stockItem.inventoryItem?.pricePerUnit {
                        Text("$\(String(format: "%.2f", price))")
                            .font(.headline)
                            .foregroundColor(.green)
                        Text("per unit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Status indicators
            HStack(spacing: 12) {
                StatusBadge(
                    text: stockItem.isBelowMinimumStock ? "Low Stock" : "In Stock",
                    color: stockItem.isBelowMinimumStock ? .red : .green
                )
                
                if let supplier = stockItem.inventoryItem?.supplier {
                    StatusBadge(text: "Supplier: \(supplier)", color: .blue)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Current Stock Section
    private var currentStockSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vehicle Stock")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                EditableStockCard(
                    title: "Current Qty",
                    value: "\(stockItem.quantity)",
                    isEditing: editingQuantity,
                    editValue: $newQuantity,
                    onEdit: { editingQuantity = true },
                    onSave: { updateQuantity() },
                    onCancel: { cancelQuantityEdit() },
                    color: stockItem.isBelowMinimumStock ? .red : .blue
                )
                
                EditableStockCard(
                    title: "Minimum",
                    value: "\(stockItem.minimumStockLevel)",
                    isEditing: editingMinimum,
                    editValue: $newMinimum,
                    onEdit: { editingMinimum = true },
                    onSave: { updateMinimum() },
                    onCancel: { cancelMinimumEdit() },
                    color: .orange
                )
                
                EditableStockCard(
                    title: "Maximum",
                    value: stockItem.maxStockLevel != nil ? "\(stockItem.maxStockLevel!)" : "Not Set",
                    isEditing: editingMaximum,
                    editValue: $newMaximum,
                    onEdit: { editingMaximum = true },
                    onSave: { updateMaximum() },
                    onCancel: { cancelMaximumEdit() },
                    color: .purple
                )
            }
            
            // Value calculation
            if let price = stockItem.inventoryItem?.pricePerUnit {
                HStack {
                    Text("Total Value:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("$\(String(format: "%.2f", Double(stockItem.quantity) * price))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - System Stock Section
    private var systemStockSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System-wide Overview")
                .font(.headline)
            
            // Summary cards
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SummaryCard(
                    title: "Total Quantity",
                    value: "\(totalSystemStock)",
                    subtitle: "All locations",
                    icon: "cube.box.fill",
                    color: .blue
                )
                
                SummaryCard(
                    title: "Total Value",
                    value: "$\(String(format: "%.0f", totalSystemValue))",
                    subtitle: "System-wide",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
            }
            
            // Location breakdown
            if !warehouseStock.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Warehouse Locations")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(warehouseStock, id: \.id) { warehouseStockItem in
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text(warehouseStockItem.warehouse?.name ?? "Unknown Warehouse")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("\(warehouseStockItem.quantity)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(warehouseStockItem.isBelowMinimumStock ? .red : .primary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Stock Level Management Section
    private var stockLevelManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stock Level Guidelines")
                .font(.headline)
            
            VStack(spacing: 12) {
                StockLevelIndicator(
                    title: "Current Level",
                    current: stockItem.quantity,
                    minimum: stockItem.minimumStockLevel,
                    maximum: stockItem.maxStockLevel
                )
                
                if stockItem.isBelowMinimumStock {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Stock is below minimum level. Consider restocking.")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if let max = stockItem.maxStockLevel, stockItem.quantity > max {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Stock exceeds maximum level. Consider redistributing.")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
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
            Button(action: { showingTransferSheet = true }) {
                HStack {
                    Image(systemName: "arrow.triangle.swap")
                    Text("Transfer Stock")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Button(action: { showingDeleteAlert = true }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Remove from Vehicle")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
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
    private var hasChanges: Bool {
        editingQuantity || editingMinimum || editingMaximum
    }
    
    private func setupEditingValues() {
        newQuantity = "\(stockItem.quantity)"
        newMinimum = "\(stockItem.minimumStockLevel)"
        newMaximum = stockItem.maxStockLevel != nil ? "\(stockItem.maxStockLevel!)" : ""
    }
    
    private func updateQuantity() {
        guard let quantity = Int(newQuantity), quantity >= 0 else {
            errorMessage = "Please enter a valid quantity (0 or greater)"
            showingError = true
            return
        }
        
        stockItem.quantity = quantity
        stockItem.updatedAt = Date()
        editingQuantity = false
    }
    
    private func updateMinimum() {
        guard let minimum = Int(newMinimum), minimum >= 0 else {
            errorMessage = "Please enter a valid minimum level (0 or greater)"
            showingError = true
            return
        }
        
        stockItem.minimumStockLevel = minimum
        stockItem.updatedAt = Date()
        editingMinimum = false
    }
    
    private func updateMaximum() {
        if newMaximum.isEmpty {
            stockItem.maxStockLevel = nil
        } else {
            guard let maximum = Int(newMaximum), maximum >= stockItem.minimumStockLevel else {
                errorMessage = "Maximum level must be greater than or equal to minimum level"
                showingError = true
                return
            }
            stockItem.maxStockLevel = maximum
        }
        
        stockItem.updatedAt = Date()
        editingMaximum = false
    }
    
    private func cancelQuantityEdit() {
        newQuantity = "\(stockItem.quantity)"
        editingQuantity = false
    }
    
    private func cancelMinimumEdit() {
        newMinimum = "\(stockItem.minimumStockLevel)"
        editingMinimum = false
    }
    
    private func cancelMaximumEdit() {
        newMaximum = stockItem.maxStockLevel != nil ? "\(stockItem.maxStockLevel!)" : ""
        editingMaximum = false
    }
    
    private func saveChanges() {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func deleteStockItem() {
        modelContext.delete(stockItem)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to delete item: \(error.localizedDescription)"
            showingError = true
        }
    }
    
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
            
            Button("Save") {
                saveChanges()
            }
            .disabled(!hasChanges)
            .foregroundColor(hasChanges ? .blue : .gray)
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

struct EditableStockCard: View {
    let title: String
    let value: String
    let isEditing: Bool
    @Binding var editValue: String
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isEditing {
                VStack(spacing: 8) {
                    TextField("Value", text: $editValue)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    
                    HStack(spacing: 8) {
                        Button("Cancel") { onCancel() }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Save") { onSave() }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(color)
                    }
                }
            } else {
                Button(action: onEdit) {
                    Text(value)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct StockLevelIndicator: View {
    let title: String
    let current: Int
    let minimum: Int
    let maximum: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Text("0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    // Current level indicator
                    if let max = maximum, max > 0 {
                        let progress = min(Double(current) / Double(max), 1.0)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(current < minimum ? Color.red : Color.green)
                            .frame(width: nil, height: 8)
                            .scaleEffect(x: progress, y: 1, anchor: .leading)
                    }
                }
                
                if let max = maximum {
                    Text("\(max)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("∞")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Current: \(current)")
                    .font(.caption)
                    .foregroundColor(current < minimum ? .red : .primary)
                
                Spacer()
                
                Text("Min: \(minimum)")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                if let max = maximum {
                    Text("Max: \(max)")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
        }
    }
}

#Preview {
    VehicleInventoryDetailView(
        stockItem: StockLocationItem(),
        vehicle: AppVehicle(
            make: "Ford",
            model: "Transit",
            year: 2022,
            vin: "1234567890",
            licensePlate: "ABC123",
            mileage: 50000
        )
    )
    .environmentObject(AppAuthService())
    .modelContainer(for: [StockLocationItem.self], inMemory: true)
} 