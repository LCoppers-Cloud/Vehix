import SwiftUI
import SwiftData

struct EditInventoryItemView: View {
    let item: AppInventoryItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String
    @State private var partNumber: String
    @State private var category: String
    @State private var pricePerUnit: Double
    @State private var itemDescription: String
    @State private var supplier: String
    @State private var isActive: Bool
    @State private var selectedCategory: String
    
    @State private var showingDeleteConfirmation = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // Common categories for picker
    private let commonCategories = [
        "Parts & Components",
        "Tools & Equipment", 
        "Safety Equipment",
        "Consumables",
        "Electrical",
        "Mechanical",
        "Hydraulic",
        "Supplies",
        "Maintenance",
        "Other"
    ]
    
    init(item: AppInventoryItem) {
        self.item = item
        self._name = State(initialValue: item.name)
        self._partNumber = State(initialValue: item.partNumber)
        self._category = State(initialValue: item.category)
        self._pricePerUnit = State(initialValue: item.pricePerUnit)
        self._itemDescription = State(initialValue: item.itemDescription ?? "")
        self._supplier = State(initialValue: item.supplier ?? "")
        self._isActive = State(initialValue: item.isActive)
        self._selectedCategory = State(initialValue: item.category)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                basicInformationSection
                pricingDetailsSection
                statusSection
                statisticsSection
                actionsSection
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Delete Item", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteItem()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete '\(item.name)'? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var basicInformationSection: some View {
        Section("Basic Information") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Item Name")
                    .font(.headline)
                TextField("Enter item name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Part Number")
                    .font(.headline)
                TextField("Enter part number", text: $partNumber)
                    .textFieldStyle(.roundedBorder)
            }
            
            categorySelectionView
        }
    }
    
    private var categorySelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.headline)
            
            HStack {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(commonCategories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                
                Button("Custom") {
                    selectedCategory = category
                }
                .font(.caption)
            }
            
            if selectedCategory == category {
                TextField("Custom category", text: $category)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text("Using: \(selectedCategory)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .onAppear {
                        category = selectedCategory
                    }
                    .onChange(of: selectedCategory) { _, newValue in
                        category = newValue
                    }
            }
        }
    }
    
    private var pricingDetailsSection: some View {
        Section("Pricing & Details") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Price per Unit")
                    .font(.headline)
                
                HStack {
                    Text("$")
                        .foregroundColor(.secondary)
                    TextField("0.00", value: $pricePerUnit, format: .currency(code: "USD"))
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Supplier")
                    .font(.headline)
                TextField("Enter supplier name", text: $supplier)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                TextField("Enter item description", text: $itemDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
        }
    }
    
    private var statusSection: some View {
        Section("Status") {
            Toggle("Active Item", isOn: $isActive)
            
            if !isActive {
                Text("Inactive items will not appear in new stock orders")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var statisticsSection: some View {
        Section("Item Statistics") {
            VStack(spacing: 12) {
                StatisticRow(
                    label: "Total Quantity",
                    value: "\(item.stockTotalQuantity)",
                    icon: "cube.box.fill",
                    color: .blue
                )
                
                StatisticRow(
                    label: "Total Value",
                    value: "$\(String(format: "%.2f", calculateTotalValue()))",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                StatisticRow(
                    label: "Locations",
                    value: "\(getStockLocationsCount())",
                    icon: "mappin.circle.fill",
                    color: .purple
                )
                
                StatisticRow(
                    label: "Created",
                    value: item.createdAt.formatted(date: .abbreviated, time: .omitted),
                    icon: "calendar.circle.fill",
                    color: .orange
                )
            }
        }
    }
    
    private var actionsSection: some View {
        Section("Actions") {
            Button("Delete Item") {
                showingDeleteConfirmation = true
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
        }
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !partNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        pricePerUnit >= 0
    }
    
    private func saveChanges() {
        // Trim whitespace from text fields
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPartNumber = partNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSupplier = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate required fields
        guard !trimmedName.isEmpty else {
            showError("Item name is required")
            return
        }
        
        guard !trimmedPartNumber.isEmpty else {
            showError("Part number is required")
            return
        }
        
        guard !trimmedCategory.isEmpty else {
            showError("Category is required")
            return
        }
        
        guard pricePerUnit >= 0 else {
            showError("Price per unit must be non-negative")
            return
        }
        
        // Check for duplicate part number (excluding current item)
        let allItems = try? modelContext.fetch(FetchDescriptor<AppInventoryItem>())
        let existingItem = allItems?.first { $0.partNumber == trimmedPartNumber && $0.id != item.id }
        
        if existingItem != nil {
            showError("An item with part number '\(trimmedPartNumber)' already exists")
            return
        }
        
        // Update the item
        item.name = trimmedName
        item.partNumber = trimmedPartNumber
        item.category = trimmedCategory
        item.pricePerUnit = pricePerUnit
        item.supplier = trimmedSupplier.isEmpty ? nil : trimmedSupplier
        item.itemDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
        item.isActive = isActive
        item.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            showError("Failed to save changes: \(error.localizedDescription)")
        }
    }
    
    private func deleteItem() {
        // Check if item has any stock locations
        if getStockLocationsCount() > 0 {
            showError("Cannot delete item with existing stock. Please remove all stock first.")
            return
        }
        
        modelContext.delete(item)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            showError("Failed to delete item: \(error.localizedDescription)")
        }
    }
    
    private func calculateTotalValue() -> Double {
        // In a real implementation, this would calculate total value across all stock locations
        // For now, using the item's total quantity and price per unit
        return Double(item.stockTotalQuantity) * item.pricePerUnit
    }
    
    private func getStockLocationsCount() -> Int {
        // In a real implementation, this would count stock locations for this item
        // For now, returning 0 since we don't have a direct relationship
        return 0
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
}

// MARK: - Supporting Views

struct StatisticRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    // Create a sample item for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: AppInventoryItem.self, configurations: config)
    let context = container.mainContext
    
    let sampleItem = AppInventoryItem(
        name: "Sample Part",
        partNumber: "SP001",
        category: "Tools",
        pricePerUnit: 25.99
    )
    
    // Insert the sample item into the context
    context.insert(sampleItem)
    
    return EditInventoryItemView(item: sampleItem)
        .modelContainer(container)
} 