import SwiftUI
import SwiftData

struct AddInventoryToVehicleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let vehicle: AppVehicle
    
    @Query private var allInventoryItems: [AppInventoryItem]
    
    @State private var selectedItems: Set<String> = []
    @State private var quantities: [String: Int] = [:]
    @State private var minimumLevels: [String: Int] = [:]
    @State private var searchText: String = ""
    @State private var showingAddNewItem = false
    
    var filteredItems: [AppInventoryItem] {
        if searchText.isEmpty {
            return allInventoryItems
        } else {
            return allInventoryItems.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                (item.partNumber?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (item.category.localizedCaseInsensitiveContains(searchText))
            }
        }
    }
    
    // Get items already assigned to this vehicle
    var existingItemIds: Set<String> {
        let ids = vehicle.stockItems?.compactMap { $0.inventoryItem?.id } ?? []
        return Set(ids)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search inventory", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Selected items count
                if !selectedItems.isEmpty {
                    HStack {
                        Text("\(selectedItems.count) item(s) selected")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Button("Clear All") {
                            selectedItems.removeAll()
                            quantities.removeAll()
                            minimumLevels.removeAll()
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                }
                
                List {
                    Section(header: Text("Available Inventory Items")) {
                        ForEach(filteredItems) { item in
                            if !existingItemIds.contains(item.id) {
                                ItemSelectionRow(
                                    item: item,
                                    isSelected: selectedItems.contains(item.id),
                                    quantity: Binding(
                                        get: { quantities[item.id] ?? 1 },
                                        set: { quantities[item.id] = $0 }
                                    ),
                                    minimumLevel: Binding(
                                        get: { minimumLevels[item.id] ?? 1 },
                                        set: { minimumLevels[item.id] = $0 }
                                    ),
                                    onToggle: { isSelected in
                                        if isSelected {
                                            selectedItems.insert(item.id)
                                            // Initialize with defaults if not set
                                            if quantities[item.id] == nil {
                                                quantities[item.id] = 1
                                            }
                                            if minimumLevels[item.id] == nil {
                                                minimumLevels[item.id] = 1
                                            }
                                        } else {
                                            selectedItems.remove(item.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    if !existingItemIds.isEmpty {
                        Section(header: Text("Already Assigned to This Vehicle")) {
                            ForEach(allInventoryItems.filter { existingItemIds.contains($0.id) }) { item in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .fontWeight(.medium)
                                        Text(item.category)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Show current quantity
                                    if let stockItem = vehicle.stockItems?.first(where: { $0.inventoryItem?.id == item.id }) {
                                        Text("Qty: \(stockItem.quantity)")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Add New Item button
                Button(action: { 
                    showingAddNewItem = true
                }) {
                    Label("Create New Inventory Item", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Add Inventory to Vehicle")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Selected") {
                        assignItemsToVehicle()
                    }
                    .disabled(selectedItems.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddNewItem) {
                // This would be your existing inventory creation view
                // but with the vehicle pre-assigned
                Text("Create New Inventory Item View")
                    .padding()
            }
        }
    }
    
    private func assignItemsToVehicle() {
        // Create StockLocationItems for each selected inventory item
        for itemId in selectedItems {
            // Find the inventory item
            guard let item = allInventoryItems.first(where: { $0.id == itemId }) else {
                continue
            }
            
            // Get quantity and minimum level for this item
            let quantity = quantities[itemId] ?? 1
            let minimumLevel = minimumLevels[itemId] ?? 1
            
            // Create a new StockLocationItem linking the inventory item to this vehicle
            let stockItem = StockLocationItem(
                inventoryItem: item,
                quantity: quantity,
                minimumStockLevel: minimumLevel,
                vehicle: vehicle
            )
            
            // Insert into database
            modelContext.insert(stockItem)
        }
        
        // Save changes
        try? modelContext.save()
        
        // Dismiss the view
        dismiss()
    }
}

// Helper view for each inventory item row with selection controls
struct ItemSelectionRow: View {
    let item: AppInventoryItem
    let isSelected: Bool
    @Binding var quantity: Int
    @Binding var minimumLevel: Int
    let onToggle: (Bool) -> Void
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name)
                        .fontWeight(.medium)
                    
                    if let partNumber = item.partNumber, !partNumber.isEmpty {
                        Text("Part #: \(partNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(item.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { onToggle($0) }
                ))
                .labelsHidden()
            }
            
            if isSelected {
                Divider()
                
                HStack {
                    Text("Quantity:")
                    
                    Stepper(value: $quantity, in: 1...999) {
                        Text("\(quantity)")
                            .frame(minWidth: 30)
                            .padding(.horizontal, 8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .padding(.top, 4)
                
                HStack {
                    Text("Min Level:")
                    
                    Stepper(value: $minimumLevel, in: 1...999) {
                        Text("\(minimumLevel)")
                            .frame(minWidth: 30)
                            .padding(.horizontal, 8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AppVehicle.self, AppInventoryItem.self, StockLocationItem.self, configurations: config)
        
        // Create sample data
        let vehicle = AppVehicle(
            make: "Toyota",
            model: "Camry",
            year: 2022,
            mileage: 15000
        )
        
        let context = ModelContext(container)
        context.insert(vehicle)
        
        // Add some sample inventory items
        for i in 1...10 {
            let item = AppInventoryItem(
                name: "Sample Item \(i)",
                partNumber: "P-\(1000 + i)",
                category: i % 3 == 0 ? "Tools" : (i % 3 == 1 ? "Parts" : "Materials")
            )
            context.insert(item)
        }
        
        return AddInventoryToVehicleView(vehicle: vehicle)
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
} 