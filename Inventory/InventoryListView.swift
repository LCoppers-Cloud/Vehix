import SwiftUI
import SwiftData

struct InventoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AppAuthService
    
    // Unified data queries - consistent with other inventory views
    @Query(sort: [SortDescriptor(\Vehix.InventoryItem.name)]) private var allInventoryItems: [AppInventoryItem]
    @Query(sort: [SortDescriptor(\StockLocationItem.createdAt, order: .reverse)]) private var stockLocations: [StockLocationItem]
    @Query(sort: [SortDescriptor(\AppWarehouse.name)]) private var warehouses: [AppWarehouse]
    @Query(sort: [SortDescriptor(\Vehix.Vehicle.licensePlate)]) private var vehicles: [AppVehicle]
    
    @State private var selectedItem: AppInventoryItem?
    @State private var showingAddItem = false
    @State private var showingSharedInventory = false
    @State private var showConfirmDelete = false
    @State private var itemToDelete: AppInventoryItem?
    @State private var showAdjustQuantitySheet = false
    @State private var quantityAdjustItem: AppInventoryItem?
    @State private var showItemDetail = false
    @State private var newQuantity = 0
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showLowStockOnly = false
    
    // For multi-selection mode 
    @State private var isMultiSelecting = false
    @State private var selectedItems: Set<AppInventoryItem> = []
    @State private var showingBulkActionSheet = false
    
    // Since this component is embedded in a tabbed navigation context
    // we're setting this to avoid duplicate .searchable modifiers
    var disableSearch = false
    
    // Computed properties using unified types
    private var inventoryItems: [InventoryItemStatus] {
        return allInventoryItems.toInventoryStatuses(with: stockLocations)
    }
    
    private var filteredItems: [InventoryItemStatus] {
        var filtered = inventoryItems
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                item.item.name.localizedCaseInsensitiveContains(searchText) ||
                item.item.partNumber.localizedCaseInsensitiveContains(searchText) ||
                item.item.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply category filter
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.item.category == selectedCategory }
        }
        
        // Apply low stock filter
        if showLowStockOnly {
            filtered = filtered.filter { $0.status == .lowStock || $0.status == .outOfStock }
        }
        
        return filtered.sorted { $0.item.name < $1.item.name }
    }
    
    private var categories: [String] {
        Array(Set(allInventoryItems.map(\.category))).sorted()
    }

    var body: some View {
        ZStack {
            VStack {
                if !disableSearch {
                    searchBar
                }
                
                filtersBar
                
                if allInventoryItems.isEmpty {
                    emptyStateView
                } else if filteredItems.isEmpty {
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
        .searchable(text: $searchText, prompt: "Search inventory")
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
            AddInventoryItemForm()
                .environment(\.modelContext, modelContext)
        }
        .sheet(isPresented: $showingSharedInventory) {
            SharedInventoryView()
        }
        .sheet(isPresented: $showAdjustQuantitySheet) {
            if let item = quantityAdjustItem {
                AdjustQuantityView(item: item, currentQuantity: getTotalQuantity(for: item)) { newValue in
                    adjustQuantity(item, newValue)
                }
            }
        }
        .sheet(isPresented: $showItemDetail) {
            if let item = selectedItem {
                InventoryItemDetailView(item: item, inventoryManager: InventoryManager())
                    .environmentObject(authService)
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
                .foregroundColor(.gray)
            
            TextField("Search inventory...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // Filters bar
    private var filtersBar: some View {
        HStack {
            Picker("Category", selection: $selectedCategory) {
                Text("All Categories").tag("All")
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            Spacer()
            
            Toggle("Low Stock Only", isOn: $showLowStockOnly)
                .toggleStyle(SwitchToggleStyle())
                .scaleEffect(0.8)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    // Main list view using unified InventoryRowView
    private var mainListView: some View {
        List {
            ForEach(filteredItems, id: \.item.id) { itemStatus in
                HStack {
                    if isMultiSelecting {
                        Button(action: {
                            if selectedItems.contains(itemStatus.item) {
                                selectedItems.remove(itemStatus.item)
                            } else {
                                selectedItems.insert(itemStatus.item)
                            }
                        }) {
                            Image(systemName: selectedItems.contains(itemStatus.item) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedItems.contains(itemStatus.item) ? .blue : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Use the unified InventoryRowView
                    InventoryRowView(itemStatus: itemStatus) {
                        selectedItem = itemStatus.item
                        showItemDetail = true
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
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
            
            if showLowStockOnly {
                Button("Clear Filters") {
                    showLowStockOnly = false
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
                Text("\(allInventoryItems.count) Items")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Text("Total Value: \(formatCurrency(totalInventoryValue))")
                    .font(.caption)
                    .foregroundColor(.white)
                
                if lowStockCount > 0 {
                    Text("\(lowStockCount) items low stock")
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
        // Implement delete logic
        itemToDelete = nil
    }
    
    private func adjustQuantity(_ item: AppInventoryItem, _ newQuantity: Int) {
        // Implement adjust quantity logic
        quantityAdjustItem = nil
        Task {
            await updateStats()
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    private var totalInventoryValue: Double {
        // Implement total inventory value calculation
        return 0.0
    }
    
    private var lowStockCount: Int {
        // Implement low stock count calculation
        return 0
    }
    
    private func updateStats() async {
        // Implement update stats logic
    }
    
    private func getTotalQuantity(for item: AppInventoryItem) -> Int {
        // Implement get total quantity calculation
        return 0
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