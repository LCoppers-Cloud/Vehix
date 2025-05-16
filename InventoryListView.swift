import SwiftUI
import SwiftData

struct InventoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var inventoryManager: InventoryManager
    @EnvironmentObject private var authService: AppAuthService
    
    @State private var selectedItem: AppInventoryItem?
    @State private var showingAddItem = false
    @State private var showingSharedInventory = false
    @State private var showWarehousePicker = false
    @State private var showVehiclePicker = false
    @State private var showConfirmDelete = false
    @State private var itemToDelete: AppInventoryItem?
    @State private var showAdjustQuantitySheet = false
    @State private var quantityAdjustItem: AppInventoryItem?
    @State private var showItemDetail = false
    @State private var newQuantity = 0
    @State private var searchText = ""
    
    // Since this component is embedded in a tabbed navigation context
    // we're setting this to avoid duplicate .searchable modifiers
    var disableSearch = false
    
    // For multi-selection mode 
    @State private var isMultiSelecting = false
    @State private var selectedItems: Set<AppInventoryItem> = []
    @State private var showingBulkActionSheet = false
    
    var body: some View {
        ZStack {
            VStack {
                if !disableSearch {
                    searchBar
                }
                
                filtersBar
                
                if inventoryManager.allInventoryItems.isEmpty {
                    emptyStateView
                } else if inventoryManager.filteredItems.isEmpty {
                    noResultsView
                } else {
                    mainListView
                }
            }
            
            // Quick stats view at bottom
            VStack {
                Spacer()
                statsView
            }
            
            // Floating Action Button (FAB) for adding inventory
            if authService.currentUser?.userRole == .admin {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddItem = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color(red: 0.2, green: 0.5, blue: 0.9))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 32)
                        .accessibilityLabel("Add Inventory Item")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await inventoryManager.updateStats()
            }
        }
        .searchable(text: $searchText, prompt: "Search inventory")
        .onChange(of: searchText) { _, newValue in
            inventoryManager.searchQuery = newValue
            inventoryManager.applyFilters()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: {
                        showingAddItem = true
                    }) {
                        Label("Add Item", systemImage: "plus")
                    }
                    
                    Button(action: {
                        showingSharedInventory = true
                    }) {
                        Label("Browse Shared Catalog", systemImage: "square.grid.2x2")
                    }
                    
                    Button(action: {
                        isMultiSelecting.toggle()
                        
                        if !isMultiSelecting {
                            selectedItems.removeAll()
                        }
                    }) {
                        Label(isMultiSelecting ? "Cancel Selection" : "Select Multiple", 
                              systemImage: isMultiSelecting ? "xmark" : "checkmark.circle")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
            
            if isMultiSelecting {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingBulkActionSheet = true
                    }) {
                        Text("\(selectedItems.count) selected")
                            .foregroundColor(.blue)
                            .disabled(selectedItems.isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddInventoryItemView(inventoryManager: inventoryManager)
        }
        .sheet(isPresented: $showingSharedInventory) {
            SharedInventoryView()
        }
        .sheet(isPresented: $showWarehousePicker) {
            WarehousePickerView(selectedWarehouse: $inventoryManager.selectedWarehouse)
        }
        .sheet(isPresented: $showVehiclePicker) {
            VehiclePickerView(selectedVehicle: $inventoryManager.selectedVehicle)
        }
        .sheet(isPresented: $showAdjustQuantitySheet) {
            if let item = quantityAdjustItem {
                AdjustQuantityView(item: item, currentQuantity: inventoryManager.getTotalQuantity(for: item)) { newValue in
                    adjustQuantity(item, newValue)
                }
            }
        }
        .sheet(isPresented: $showItemDetail) {
            if let item = selectedItem {
                InventoryItemDetailView(item: item, inventoryManager: inventoryManager)
            }
        }
        .confirmationDialog(
            "Are you sure you want to delete this item?",
            isPresented: $showConfirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    deleteItem(item)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let item = itemToDelete {
                Text("This will permanently delete \(item.name) from your inventory.")
            }
        }
        .actionSheet(isPresented: $showingBulkActionSheet) {
            ActionSheet(
                title: Text("Bulk Actions"),
                message: Text("What would you like to do with the \(selectedItems.count) selected items?"),
                buttons: [
                    .default(Text("Set Category")) {
                        // Implement bulk category setting
                    },
                    .default(Text("Assign to Vehicle")) {
                        // Implement bulk vehicle assignment
                    },
                    .destructive(Text("Delete Selected")) {
                        // Implement bulk delete
                        for item in selectedItems {
                            deleteItem(item)
                        }
                        selectedItems.removeAll()
                        isMultiSelecting = false
                    },
                    .cancel {
                        // Do nothing
                    }
                ]
            )
        }
    }
    
    // Search bar for filtering inventory
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search inventory", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
    }
    
    // Filter and sort options
    private var filtersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Menu {
                    Picker("Sort by", selection: $inventoryManager.sortOption) {
                        Text("Name (A-Z)").tag(InventoryManager.SortOption.nameAsc)
                        Text("Name (Z-A)").tag(InventoryManager.SortOption.nameDesc)
                        Text("Category (A-Z)").tag(InventoryManager.SortOption.categoryAsc)
                        Text("Category (Z-A)").tag(InventoryManager.SortOption.categoryDesc)
                        Text("Quantity (Low to High)").tag(InventoryManager.SortOption.quantityAsc)
                        Text("Quantity (High to Low)").tag(InventoryManager.SortOption.quantityDesc)
                        Text("Value (Low to High)").tag(InventoryManager.SortOption.valueAsc)
                        Text("Value (High to Low)").tag(InventoryManager.SortOption.valueDesc)
                    }
                } label: {
                    HStack {
                        Text("Sort")
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
                .onChange(of: inventoryManager.sortOption) { _, _ in
                    inventoryManager.applyFilters()
                }
                
                // Category filter
                Menu {
                    Button("All Categories") {
                        inventoryManager.selectedCategory = nil
                        inventoryManager.applyFilters()
                    }
                    
                    Divider()
                    
                    // Get categories directly from the allInventoryItems
                    let categories = inventoryManager.allInventoryItems
                        .map { $0.category }
                        .sorted()
                        .removingDuplicates()
                    
                    ForEach(categories, id: \.self) { category in
                        Button(category) {
                            inventoryManager.selectedCategory = category
                            inventoryManager.applyFilters()
                        }
                    }
                } label: {
                    HStack {
                        Text(inventoryManager.selectedCategory ?? "Category")
                        Image(systemName: "chevron.down")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(inventoryManager.selectedCategory != nil ? Color.blue : Color(.systemGray5))
                    .foregroundColor(inventoryManager.selectedCategory != nil ? .white : .primary)
                    .cornerRadius(8)
                }
                
                // Location filter
                Button(action: {
                    showWarehousePicker = true
                }) {
                    HStack {
                        Text(inventoryManager.selectedWarehouse?.name ?? "Location")
                        Image(systemName: "chevron.down")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(inventoryManager.selectedWarehouse != nil ? Color.blue : Color(.systemGray5))
                    .foregroundColor(inventoryManager.selectedWarehouse != nil ? .white : .primary)
                    .cornerRadius(8)
                }
                
                // Vehicle filter
                Button(action: {
                    showVehiclePicker = true
                }) {
                    HStack {
                        Text(inventoryManager.selectedVehicle?.make ?? "Vehicle")
                        Image(systemName: "chevron.down")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(inventoryManager.selectedVehicle != nil ? Color.blue : Color(.systemGray5))
                    .foregroundColor(inventoryManager.selectedVehicle != nil ? .white : .primary)
                    .cornerRadius(8)
                }
                
                if inventoryManager.hasActiveFilters {
                    Button("Clear Filters") {
                        inventoryManager.clearFilters()
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // Main list of inventory items
    private var mainListView: some View {
        List {
            ForEach(inventoryManager.filteredItems) { item in
                InventoryListItemRow(
                    item: item, 
                    isMultiSelecting: isMultiSelecting,
                    isSelected: selectedItems.contains(item),
                    onSelect: {
                        if isMultiSelecting {
                            if selectedItems.contains(item) {
                                selectedItems.remove(item)
                            } else {
                                selectedItems.insert(item)
                            }
                        } else {
                            selectedItem = item
                            showItemDetail = true
                        }
                    },
                    onDelete: {
                        itemToDelete = item
                        showConfirmDelete = true
                    },
                    onAdjustQuantity: {
                        quantityAdjustItem = item
                        newQuantity = inventoryManager.getTotalQuantity(for: item)
                        showAdjustQuantitySheet = true
                    }
                )
            }
        }
    }
    
    // Empty state when no inventory items exist
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.box")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("No Inventory Items")
                .font(.title2)
                .bold()
            
            Text("Add your first inventory item to start tracking your parts and supplies.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button(action: {
                showingAddItem = true
            }) {
                Text("Add Item")
                    .bold()
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
            
            Button(action: {
                showingSharedInventory = true
            }) {
                Text("Browse Shared Catalog")
                    .padding()
                    .frame(minWidth: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue, lineWidth: 2)
                    )
            }
        }
        .padding()
    }
    
    // View for when search has no results
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No matching items found")
                .font(.headline)
            
            Text("Try adjusting your search or filters")
                .foregroundColor(.secondary)
            
            if inventoryManager.hasActiveFilters {
                Button("Clear Filters") {
                    inventoryManager.clearFilters()
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Stats summary view
    private var statsView: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .center) {
                Text("\(inventoryManager.totalItemCount) Items")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Text("Total Value: \(formatCurrency(inventoryManager.totalInventoryValue))")
                    .font(.caption)
                    .foregroundColor(.white)
                
                if inventoryManager.lowStockCount > 0 {
                    Text("\(inventoryManager.lowStockCount) items low stock")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(8)
            .background(Color.blue.opacity(0.8))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding(.bottom, 8)
    }
    
    // Helper functions
    private func deleteItem(_ item: AppInventoryItem) {
        inventoryManager.deleteItem(item)
        itemToDelete = nil
    }
    
    private func adjustQuantity(_ item: AppInventoryItem, _ newQuantity: Int) {
        inventoryManager.updateItemQuantity(item: item, newQuantity: newQuantity)
        quantityAdjustItem = nil
        Task {
            await inventoryManager.updateStats()
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// Component for displaying an inventory item in a list row
struct InventoryListItemRow: View {
    let item: AppInventoryItem
    let isMultiSelecting: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onAdjustQuantity: () -> Void
    
    @EnvironmentObject private var inventoryManager: InventoryManager
    
    private var stockLocations: [StockLocationItem] {
        inventoryManager.findStockLocations(for: item)
    }
    
    private var totalQuantity: Int {
        inventoryManager.getTotalQuantity(for: item)
    }
    
    private var isLowStock: Bool {
        inventoryManager.isBelowMinimumStock(item: item)
    }
    
    var body: some View {
        HStack {
            if isMultiSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .imageScale(.large)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(isLowStock ? .orange : .primary)
                
                Text("ID: \(item.partNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(totalQuantity) in stock")
                        .font(.caption)
                        .foregroundColor(totalQuantity > 0 ? .secondary : .red)
                    
                    if isLowStock && totalQuantity > 0 {
                        Text("Low Stock")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    } else if totalQuantity == 0 {
                        Text("Out of Stock")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                }
                
                // Show warehouse locations
                if let warehouseLocation = stockLocations.first(where: { $0.warehouse != nil }) {
                    Text("Warehouse: \(warehouseLocation.warehouse?.name ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Show vehicle assignments
                if let vehicleLocation = stockLocations.first(where: { $0.vehicle != nil }),
                   let vehicle = vehicleLocation.vehicle {
                    Text("Assigned to: \(vehicle.make) \(vehicle.model)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("$\(String(format: "%.2f", item.pricePerUnit))")
                    .font(.subheadline)
                    .bold()
                
                Text(formatCurrency(Double(totalQuantity) * item.pricePerUnit))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !isMultiSelecting {
                    Menu {
                        Button(action: onAdjustQuantity) {
                            Label("Adjust Quantity", systemImage: "plusminus")
                        }
                        
                        Button(action: {
                            // Implement move to different location
                        }) {
                            Label("Move Location", systemImage: "arrow.up.arrow.down")
                        }
                        
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete Item", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 30, height: 30)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .padding(.vertical, 4)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// View for adjusting item quantity
struct AdjustQuantityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var inventoryManager: InventoryManager
    
    let item: AppInventoryItem
    @State private var quantity: Int
    let onSave: (Int) -> Void
    
    init(item: AppInventoryItem, currentQuantity: Int, onSave: @escaping (Int) -> Void) {
        self.item = item
        self._quantity = State(initialValue: currentQuantity)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text(item.name)
                            .font(.headline)
                        Spacer()
                        Text("Unit Price: $\(String(format: "%.2f", item.pricePerUnit))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...999)
                    
                    HStack {
                        Text("-10")
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                            .onTapGesture {
                                quantity = max(0, quantity - 10)
                            }
                        
                        Text("-5")
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                            .onTapGesture {
                                quantity = max(0, quantity - 5)
                            }
                        
                        Text("-1")
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                            .onTapGesture {
                                quantity = max(0, quantity - 1)
                            }
                        
                        Spacer()
                        
                        Text("+1")
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                            .onTapGesture {
                                quantity = min(999, quantity + 1)
                            }
                        
                        Text("+5")
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                            .onTapGesture {
                                quantity = min(999, quantity + 5)
                            }
                        
                        Text("+10")
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                            .onTapGesture {
                                quantity = min(999, quantity + 10)
                            }
                    }
                }
                
                Section {
                    Button("Save") {
                        onSave(quantity)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Adjust Quantity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#if DEBUG
struct WarehousePickerView: View {
    @Binding var selectedWarehouse: AppWarehouse?
    var body: some View {
        Text("Warehouse Picker Placeholder")
    }
}

struct VehiclePickerView: View {
    @Binding var selectedVehicle: AppVehicle?
    var body: some View {
        Text("Vehicle Picker Placeholder")
    }
}

struct InventoryItemDetailView: View {
    let item: AppInventoryItem
    let inventoryManager: InventoryManager
    var body: some View {
        Text("Inventory Item Detail Placeholder for \(item.name)")
    }
}
#endif

// Extension to make Array's removingDuplicates work
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()
        
        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }
}

// View for creating a new inventory item
struct AddInventoryItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var inventoryManager: InventoryManager
    
    @State private var name: String = ""
    @State private var partNumber: String = ""
    @State private var category: String = ""
    @State private var quantity: Int = 1
    @State private var price: Double = 0.0
    @State private var description: String = ""
    @State private var minimumStockLevel: Int = 5
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Name", text: $name)
                    TextField("Part Number", text: $partNumber)
                    TextField("Category", text: $category)
                    TextField("Description", text: $description)
                    
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("Price", value: $price, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Inventory Settings")) {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...999)
                    Stepper("Minimum Stock Level: \(minimumStockLevel)", value: $minimumStockLevel, in: 1...100)
                }
                
                Section {
                    Button("Add Item") {
                        saveItem()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(name.isEmpty || category.isEmpty)
                }
            }
            .navigationTitle("Add Inventory Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveItem() {
        // Create the item with the specified details
        let newItem = inventoryManager.createInventoryItem(
            name: name,
            category: category,
            quantity: quantity
        )
        
        // Update additional properties
        newItem.partNumber = partNumber
        newItem.itemDescription = description
        newItem.price = price
        
        // Get the stock location that was just created and update its minimum stock level
        if let stockLocation = inventoryManager.findStockLocations(for: newItem).first {
            stockLocation.minimumStockLevel = minimumStockLevel
        }
        
        try? inventoryManager.modelContext.save()
        dismiss()
    }
} 