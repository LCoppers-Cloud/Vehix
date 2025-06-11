import SwiftUI
import SwiftData
import PhotosUI // Import PhotosUI

public struct AddInventoryItemForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // State variables for form fields
    @State private var name: String = ""
    @State private var partNumber: String = ""
    @State private var calloutNumber: String = "" // Optional, but use String for TextField
    @State private var itemDescription: String = ""
    @State private var category: String = ""
    @State private var pricePerUnit: Double = 0.0
    @State private var supplier: String = ""
    @State private var unit: String = "each" // Added state for unit
    @State private var isActive: Bool = true // Added isActive flag

    // State variables for INITIAL WAREHOUSE stock location
    @State private var initialQuantity: Int = 0
    @State private var initialMinStock: Int = 5
    @State private var initialMaxStock: Int? = nil
    @State private var selectedWarehouse: AppWarehouse?
    @State private var showingCreateWarehouse = false
    
    // State for barcode scanning
    @State private var barcodeData: String = ""
    @State private var showingScannerSheet = false
    
    // State for photo picking
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    
    // Category management
    @State private var isCreatingNewCategory = false
    @State private var newCategoryName = ""
    
    // Warehouse list
    @Query(sort: [SortDescriptor<AppWarehouse>(\.name)]) private var warehouses: [AppWarehouse]
    
    public init() {}

    var isFormValid: Bool {
        // Updated validation: Check name, partNumber, initialQuantity, price, and warehouse selection
        !name.isEmpty && !partNumber.isEmpty && initialQuantity >= 0 && pricePerUnit >= 0 && selectedWarehouse != nil && !finalCategory.isEmpty
    }
    
    private var finalCategory: String {
        if isCreatingNewCategory {
            return newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return category
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Basic item information section
                Section("Item Information") {
                    TextField("Name*", text: $name)
                    TextField("Part Number*", text: $partNumber)
                    TextField("Callout Number", text: $calloutNumber)
                    
                    // Category selection with improved new category handling
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category*")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if isCreatingNewCategory {
                            HStack {
                                TextField("Enter new category name", text: $newCategoryName)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button("Cancel") {
                                    isCreatingNewCategory = false
                                    newCategoryName = ""
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        } else {
                            VStack(spacing: 8) {
                                Picker("Category", selection: $category) {
                                    Text("Select a category").tag("")
                                    ForEach(getUniqueCategories(), id: \.self) { categoryName in
                                        Text(categoryName).tag(categoryName)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                Button(action: {
                                    isCreatingNewCategory = true
                                    category = ""
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add New Category")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        // Show selected/current category
                        if !finalCategory.isEmpty {
                            Text("Category: \(finalCategory)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    
                    HStack {
                        Text("Price ($)")
                        Spacer()
                        TextField("0.00", value: $pricePerUnit, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    
                    HStack {
                        Text("Unit")
                        Spacer()
                        Picker("", selection: $unit) {
                            Text("each").tag("each")
                            Text("box").tag("box")
                            Text("case").tag("case")
                            Text("pair").tag("pair")
                            Text("set").tag("set")
                            Text("kit").tag("kit")
                            Text("pack").tag("pack")
                            Text("roll").tag("roll")
                            Text("gallon").tag("gallon")
                            Text("quart").tag("quart")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    HStack {
                        Text("Active")
                        Spacer()
                        Toggle("", isOn: $isActive)
                    }
                    
                    TextField("Description", text: $itemDescription, axis: .vertical)
                        .lineLimit(3...)
                }

                Section("Warehouse Assignment") {
                    if warehouses.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("No warehouses configured")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                            
                            Text("Items must be assigned to a warehouse when created. You can transfer them to vehicles later.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Create Your First Warehouse") {
                                showingCreateWarehouse = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Text("Or turn off warehouse storage in Settings > Warehouse & Inventory if you only want to track items on vehicles.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Warehouse *", selection: $selectedWarehouse) {
                                Text("Select a warehouse").tag(nil as AppWarehouse?)
                                ForEach(warehouses, id: \.id) { warehouse in
                                    VStack(alignment: .leading) {
                                        Text(warehouse.name)
                                        if !warehouse.address.isEmpty {
                                            Text(warehouse.address)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .tag(warehouse as AppWarehouse?)
                                }
                            }
                            
                            if selectedWarehouse == nil {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("Once assigned to a warehouse, items can be transferred to vehicles by managers.")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            } else if let warehouse = selectedWarehouse {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Will be stored at \(warehouse.name)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        if warehouse.allowVehicleTransfers {
                                            Text("Vehicle transfers enabled")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("Vehicle transfers disabled for this warehouse")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    HStack {
                        Text("Initial Quantity*")
                        Spacer()
                        TextField("Qty", value: $initialQuantity, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Minimum Stock Level")
                        Spacer()
                        TextField("Min", value: $initialMinStock, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Maximum Stock Level")
                        Spacer()
                        TextField("Max", value: Binding(
                            get: { initialMaxStock ?? 0 },
                            set: { initialMaxStock = $0 > 0 ? $0 : nil }
                        ), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                // Optional sections for advanced features
                Section("Additional Information") {
                    TextField("Supplier", text: $supplier)
                    
                    // Photo picker
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Add Photo")
                        }
                        .foregroundColor(.blue)
                    }
                    
                    // Barcode field (for future barcode scanning)
                    TextField("Barcode/SKU", text: $barcodeData)
                }
                
                // Form validation summary
                if !isFormValid {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Required fields:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            
                            if name.isEmpty {
                                Text("• Item name")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            if partNumber.isEmpty {
                                Text("• Part number")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            if finalCategory.isEmpty {
                                Text("• Category")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            if selectedWarehouse == nil {
                                Text("• Warehouse selection")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Inventory Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCreateWarehouse) {
                VehixAddWarehouseForm() { warehouse in
                    selectedWarehouse = warehouse
                }
            }
            // Add sheets for barcode scanning and other features as needed
        }
        .onChange(of: photoItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
    }
    
    // Save the item to the database
    private func saveItem() {
        // Create the inventory item
        let item = AppInventoryItem(
            name: name,
            partNumber: partNumber,
            calloutNumber: calloutNumber.isEmpty ? nil : calloutNumber,
            itemDescription: itemDescription.isEmpty ? nil : itemDescription,
            category: finalCategory,
            isActive: isActive,
            unit: unit
        )
        
        // Set custom properties (using the associated object pattern from InventoryItemExtended)
        item.price = pricePerUnit
        item.reorderPoint = initialMinStock
        item.supplier = supplier.isEmpty ? nil : supplier
        
        // Save the item to get its ID
        modelContext.insert(item)
        
        // If a warehouse is selected, create stock location
        if let warehouse = selectedWarehouse {
            // Create stock location
            let stockLocation = StockLocationItem(
                inventoryItem: item,
                quantity: initialQuantity,
                minimumStockLevel: initialMinStock,
                maxStockLevel: initialMaxStock,
                warehouse: warehouse
            )
            
            modelContext.insert(stockLocation)
        }
        
        // Save the changes
        try? modelContext.save()
        
        // Close the form
        dismiss()
    }
    
    // Helper to get unique categories for the picker
    private func getUniqueCategories() -> [String] {
        let descriptor = FetchDescriptor<AppInventoryItem>()
        do {
            let items = try modelContext.fetch(descriptor)
            let categories = items.compactMap { $0.category.isEmpty ? nil : $0.category }
            return Array(Set(categories)).sorted()
        } catch {
            print("Failed to fetch categories: \(error)")
            return []
        }
    }
}

// Using AddWarehouseForm from the dedicated file

#Preview {
    AddInventoryItemForm()
        .modelContainer(for: AppInventoryItem.self, inMemory: true)
} 