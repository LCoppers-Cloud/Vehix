import SwiftUI
import SwiftData

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

struct WarehouseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var inventoryManager: InventoryManager
    
    let warehouse: AppWarehouse
    
    @State private var showingAddInventory = false
    @State private var showingTransfer = false
    @State private var selectedStockItem: StockLocationItem?
    @State private var showingEditQuantity = false
    @State private var editingQuantity = 0
    @State private var searchText = ""
    @State private var sortOrder = InventorySort.nameAsc
    @State private var showingEditWarehouse = false
    
    var body: some View {
        List {
            Section {
                DetailRow(label: "Name", value: warehouse.name)
                DetailRow(label: "Location", value: warehouse.location)
                if warehouse.hasDescription {
                    DetailRow(label: "Description", value: warehouse.warehouseDescription)
                }
                DetailRow(label: "Status", value: warehouse.isActive ? "Active" : "Inactive")
                DetailRow(label: "Created", value: DateFormatter.shortDate.string(from: warehouse.createdAt))
            } header: {
                Text("Warehouse Details")
            }
            
            Section {
                DetailRow(label: "Total Items", value: "\(warehouse.stockItems?.count ?? 0)")
                DetailRow(label: "Total Value", value: String(format: "$%.2f", inventoryManager.getInventoryValue(for: warehouse)))
                
                let lowStockItems = warehouse.stockItems?.filter { $0.isBelowMinimumStock } ?? []
                if !lowStockItems.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(lowStockItems.count) items below minimum stock")
                            .foregroundColor(.orange)
                    }
                }
            } header: {
                Text("Inventory Summary")
            }
            
            Section {
                ForEach(filteredAndSortedItems) { stockItem in
                    if let item = stockItem.inventoryItem {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .font(.headline)
                                    Text("Quantity: \(stockItem.quantity)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Menu {
                                    Button(action: {
                                        editingQuantity = stockItem.quantity
                                        selectedStockItem = stockItem
                                        showingTransfer = false
                                    }) {
                                        Label("Edit Quantity", systemImage: "number")
                                    }
                                    
                                    Button(action: {
                                        selectedStockItem = stockItem
                                        showingTransfer = true
                                    }) {
                                        Label("Transfer", systemImage: "arrow.right")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if stockItem.isBelowMinimumStock {
                                Text("Low Stock")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Inventory Items")
            }
        }
        .searchable(text: $searchText, prompt: "Search inventory")
        .navigationTitle(warehouse.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditWarehouse = true }) {
                        Label("Edit Warehouse", systemImage: "pencil")
                    }
                    
                    Button(action: { showingAddInventory = true }) {
                        Label("Add Inventory", systemImage: "plus")
                    }
                    
                    Menu("Sort By") {
                        ForEach(InventorySort.allCases, id: \.self) { sort in
                            Button(sort.rawValue) {
                                sortOrder = sort
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddInventory) {
            AddInventoryView(warehouse: warehouse)
        }
        .sheet(item: $selectedStockItem) { stockItem in
            if showingTransfer {
                InventoryTransferView(sourceWarehouse: warehouse, stockItem: stockItem)
            } else {
                EditStockQuantityView(stockItem: stockItem)
            }
        }
        .sheet(isPresented: $showingEditWarehouse) {
            EditWarehouseView(warehouse: warehouse)
        }
    }
    
    private var filteredAndSortedItems: [StockLocationItem] {
        let items = warehouse.stockItems ?? []
        
        // Filter
        let filtered = searchText.isEmpty ? items : items.filter { stockItem in
            guard let item = stockItem.inventoryItem else { return false }
            return item.name.localizedCaseInsensitiveContains(searchText)
        }
        
        // Sort
        return filtered.sorted { item1, item2 in
            guard let inv1 = item1.inventoryItem,
                  let inv2 = item2.inventoryItem else { return false }
            
            switch sortOrder {
            case .nameAsc:
                return inv1.name < inv2.name
            case .nameDesc:
                return inv1.name > inv2.name
            case .priceAsc:
                return inv1.pricePerUnit < inv2.pricePerUnit
            case .priceDesc:
                return inv1.pricePerUnit > inv2.pricePerUnit
            case .dateAddedAsc:
                return inv1.createdAt < inv2.createdAt
            case .dateAddedDesc:
                return inv1.createdAt > inv2.createdAt
            case .categoryAsc:
                return inv1.category < inv2.category
            case .categoryDesc:
                return inv1.category > inv2.category
            }
        }
    }
}

struct EditStockQuantityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let stockItem: StockLocationItem
    @State private var newQuantity: Int
    @State private var notes = ""
    
    init(stockItem: StockLocationItem) {
        self.stockItem = stockItem
        _newQuantity = State(initialValue: stockItem.quantity)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Update Quantity")) {
                    if let item = stockItem.inventoryItem {
                        DetailRow(label: "Item", value: item.name)
                        DetailRow(label: "Current Quantity", value: "\(stockItem.quantity)")
                    }
                    
                    Stepper("New Quantity: \(newQuantity)", value: $newQuantity, in: 0...10000)
                    TextField("Notes", text: $notes)
                }
            }
            .navigationTitle("Edit Quantity")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { updateQuantity() }
            )
        }
    }
    
    private func updateQuantity() {
        let difference = newQuantity - stockItem.quantity
        stockItem.quantity = newQuantity
        
        // Create a record of the quantity change
        if let item = stockItem.inventoryItem {
            let record = AppInventoryUsageRecord(
                id: UUID().uuidString,
                inventoryItemId: item.id,
                quantity: abs(difference),
                timestamp: Date(),
                notes: "Manual quantity adjustment: \(notes)\nChange: \(difference > 0 ? "+" : "")\(difference)"
            )
            modelContext.insert(record)
        }
        
        dismiss()
    }
}

struct AddInventoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var inventoryManager: InventoryManager
    
    let warehouse: AppWarehouse
    
    @State private var selectedItem: AppInventoryItem?
    @State private var quantity = 1
    @State private var showingItemPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Item")) {
                    Button(action: { showingItemPicker = true }) {
                        if let item = selectedItem {
                            Text(item.name)
                        } else {
                            Text("Choose an Item")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if selectedItem != nil {
                    Section(header: Text("Quantity")) {
                        Stepper("Quantity: \(quantity)", value: $quantity, in: 1...10000)
                    }
                }
            }
            .navigationTitle("Add Inventory")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Add") { addInventory() }
                    .disabled(selectedItem == nil)
            )
            .sheet(isPresented: $showingItemPicker) {
                ItemPickerView(selectedItem: $selectedItem)
            }
        }
    }
    
    private func addInventory() {
        guard let item = selectedItem else { return }
        
        // Check if item already exists in warehouse
        if let existingStock = warehouse.stockItems?.first(where: { $0.inventoryItem?.id == item.id }) {
            existingStock.quantity += quantity
        } else {
            // Create new stock location
            let stockItem = StockLocationItem(
                inventoryItem: item,
                quantity: quantity,
                warehouse: warehouse
            )
            if warehouse.stockItems == nil {
                warehouse.stockItems = []
            }
            warehouse.stockItems?.append(stockItem)
        }
        
        dismiss()
    }
}

struct ItemPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var inventoryManager: InventoryManager
    @Binding var selectedItem: AppInventoryItem?
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            List(filteredItems) { item in
                Button(action: {
                    selectedItem = item
                    dismiss()
                }) {
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.headline)
                        Text(item.category)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search items")
            .navigationTitle("Select Item")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
    
    private var filteredItems: [AppInventoryItem] {
        let items = inventoryManager.allInventoryItems
        if searchText.isEmpty {
            return items
        }
        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            item.category.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// Edit Warehouse View
struct EditWarehouseView: View {
    @Environment(\.dismiss) private var dismiss
    
    let warehouse: AppWarehouse
    
    @State private var name: String
    @State private var location: String
    @State private var description: String
    @State private var isActive: Bool
    
    init(warehouse: AppWarehouse) {
        self.warehouse = warehouse
        _name = State(initialValue: warehouse.name)
        _location = State(initialValue: warehouse.location)
        _description = State(initialValue: warehouse.warehouseDescription)
        _isActive = State(initialValue: warehouse.isActive)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Warehouse Details") {
                    TextField("Name", text: $name)
                    TextField("Location/Address", text: $location)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section("Status") {
                    Toggle("Active", isOn: $isActive)
                }
                
                Section {
                    DetailRow(label: "Created", value: DateFormatter.shortDate.string(from: warehouse.createdAt))
                    DetailRow(label: "Last Updated", value: DateFormatter.shortDate.string(from: warehouse.updatedAt))
                } header: {
                    Text("Information")
                }
            }
            .navigationTitle("Edit Warehouse")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { saveWarehouse() }
                    .disabled(name.isEmpty || location.isEmpty)
            )
        }
    }
    
    private func saveWarehouse() {
        warehouse.name = name
        warehouse.location = location
        warehouse.warehouseDescription = description
        warehouse.isActive = isActive
        warehouse.updatedAt = Date()
        
        dismiss()
    }
}