import SwiftUI
import SwiftData
import PhotosUI // Import PhotosUI

struct AddInventoryItemForm: View {
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
    
    // Warehouse list
    @Query(sort: [SortDescriptor(\AppWarehouse.name)])
    private var warehouses: [AppWarehouse]

    var isFormValid: Bool {
        // Updated validation: Check name, partNumber, initialQuantity, price, and warehouse selection
        !name.isEmpty && !partNumber.isEmpty && initialQuantity >= 0 && pricePerUnit >= 0 && selectedWarehouse != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic item information section
                Section("Item Information") {
                    TextField("Name*", text: $name)
                    TextField("Part Number*", text: $partNumber)
                    TextField("Callout Number", text: $calloutNumber)
                    
                    Picker("Category", selection: $category) {
                        Text("Select a category").tag("")
                        ForEach(getUniqueCategories(), id: \.self) { category in
                            Text(category).tag(category)
                        }
                        Text("Add New Category...").tag("__new__")
                    }
                    
                    if category == "__new__" {
                        TextField("New Category Name", text: $category)
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

                Section("Initial Stock Location") {
                    if warehouses.isEmpty {
                        HStack {
                            Text("No warehouses available")
                            Spacer()
                            Button("Create Warehouse") {
                                showingCreateWarehouse = true
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.blue)
                        }
                    } else {
                        Picker("Warehouse", selection: $selectedWarehouse) {
                            Text("Select a warehouse").tag(nil as AppWarehouse?)
                            ForEach(warehouses, id: \.id) { warehouse in
                                Text(warehouse.name).tag(warehouse as AppWarehouse?)
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
                        TextField("Max (Optional)", value: $initialMaxStock, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                // Optional: Add a section for photo/image
                Section("Item Image") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack {
                            Text("Select Image")
                            Spacer()
                            Image(systemName: "photo")
                        }
                    }
                    
                    if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    }
                }
                
                // Barcode section
                Section("Barcode") {
                    HStack {
                        TextField("Barcode", text: $barcodeData)
                        Button(action: {
                            showingScannerSheet = true
                        }) {
                            Image(systemName: "barcode.viewfinder")
                        }
                    }
                }
                
                // Submit button
                Section {
                    Button("Save Item") {
                        saveItem()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Add Inventory Item")
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
            category: category.isEmpty ? "Uncategorized" : category,
            isActive: isActive,
            unit: unit
        )
        
        // Set custom properties (using the associated object pattern from InventoryItemExtended)
        item.price = pricePerUnit
        item.reorderPoint = initialMinStock
        
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