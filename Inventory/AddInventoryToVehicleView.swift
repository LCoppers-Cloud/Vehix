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
            allInventoryItems
        } else {
            allInventoryItems.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.partNumber.localizedCaseInsensitiveContains(searchText) ||
                item.category.localizedCaseInsensitiveContains(searchText)
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

#Preview {
    // Preview requires a vehicle - this would normally be passed from VehicleDetailView
    Text("Add Inventory to Vehicle Preview")
        .navigationTitle("Add Inventory")
} 