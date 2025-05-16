import SwiftUI
import SwiftData
import PhotosUI

/// View for technicians to record inventory usage
struct InventoryUsageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AppAuthService
    
    @StateObject private var usageManager = InventoryUsageManager()
    
    @State private var selectedInventoryItems: [AppInventoryItem] = []
    @State private var itemQuantities: [String: Int] = [:]
    @State private var selectedJobId: String?
    @State private var selectedJobNumber: String?
    @State private var comments: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var alertMessage = ""
    @State private var showingTutorial = false
    
    // Select from current vehicle or all inventory
    @State private var showVehicleInventoryOnly = true
    
    // Fetch stock locations
    @Query private var stockLocations: [StockLocationItem]
    
    var body: some View {
        NavigationStack {
            Form {
                jobSection
                
                inventorySection
                
                photoSection
                
                Section("Additional Information") {
                    TextField("Comments", text: $comments, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Button(action: submitUsage) {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Submit Inventory Usage")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSubmitting || selectedInventoryItems.isEmpty || hasInvalidQuantities)
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Record Inventory Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingTutorial = true
                    }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(alertMessage)
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .fullScreenCover(isPresented: $showingTutorial) {
                InventoryUsageTutorialView(showTutorial: $showingTutorial)
            }
            .onAppear {
                usageManager.setModelContext(modelContext)
                checkFirstTimeUser()
            }
        }
    }
    
    // Job selection section
    private var jobSection: some View {
        Section("Job Information") {
            // In a real app, this would be a picker that loads jobs from ServiceTitan
            // For this prototype, we'll use a simple text field
            TextField("Job Number", text: Binding(
                get: { self.selectedJobNumber ?? "" },
                set: { self.selectedJobNumber = $0.isEmpty ? nil : $0 }
            ))
            
            // Toggle to choose between current vehicle and all inventory
            Toggle("Show Only Current Vehicle Inventory", isOn: $showVehicleInventoryOnly)
        }
    }
    
    // Inventory selection section
    private var inventorySection: some View {
        Section(header: Text("Select Items Used"),
                footer: Text("Add all items used during this job.")) {
            NavigationLink {
                InventorySelectionView(
                    selectedItems: selectedItems,
                    showVehicleOnly: showVehicleInventoryOnly
                )
            } label: {
                HStack {
                    Text("Select Inventory Items")
                    Spacer()
                    Text("\(selectedInventoryItems.count) selected")
                        .foregroundColor(.secondary)
                }
            }
            
            if !selectedInventoryItems.isEmpty {
                ForEach(selectedInventoryItems) { item in
                    // Find stock location for this item to get quantity
                    let stockLocation = findStockLocationForItem(item)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.headline)
                            
                            Text(item.partNumber)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Quantity stepper
                        Stepper(
                            value: Binding(
                                get: { itemQuantities[item.id] ?? 1 },
                                set: { itemQuantities[item.id] = $0 }
                            ),
                            // Use stockLocation's quantity instead of item.quantity
                            in: 1...(stockLocation?.quantity ?? 1),
                            step: 1
                        ) {
                            Text("\(itemQuantities[item.id] ?? 1)")
                                .font(.headline)
                                .frame(minWidth: 40, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
    
    // Photo upload section
    private var photoSection: some View {
        Section("Photo Evidence") {
            if let data = photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                    .padding(.vertical, 8)
                
                Button(role: .destructive) {
                    photoData = nil
                    selectedPhotoItem = nil
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Add Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
    }
    
    // Helper to find stock location for an inventory item
    private func findStockLocationForItem(_ item: AppInventoryItem) -> StockLocationItem? {
        stockLocations.first(where: { $0.inventoryItem?.id == item.id })
    }
    
    // Properly creates a binding to the selected items array
    private var selectedItems: Binding<[AppInventoryItem]> {
        Binding<[AppInventoryItem]>(
            get: { selectedInventoryItems },
            set: { selectedInventoryItems = $0 }
        )
    }
    
    // Validation to check if all quantities are valid
    private var hasInvalidQuantities: Bool {
        for item in selectedInventoryItems {
            if let stockLocation = findStockLocationForItem(item) {
                let quantity = itemQuantities[item.id] ?? 1
                if quantity <= 0 || quantity > stockLocation.quantity {
                    return true
                }
            } else {
                return true // No stock location found for this item
            }
        }
        return false
    }
    
    // Submit inventory usage
    private func submitUsage() {
        guard !selectedInventoryItems.isEmpty else { return }
        guard let user = authService.currentUser else { 
            alertMessage = "You must be logged in to record inventory usage"
            showingErrorAlert = true
            return
        }
        
        isSubmitting = true
        
        // Process each selected item
        let dispatchGroup = DispatchGroup()
        var allSuccessful = true
        var errorMessages: [String] = []
        
        // Find stock location for first item to get vehicle (if any)
        var vehicle: AppVehicle? = nil
        if let firstItem = selectedInventoryItems.first,
           let stockLocation = findStockLocationForItem(firstItem) {
            vehicle = stockLocation.vehicle
        }
        
        for item in selectedInventoryItems {
            guard let stockLocation = findStockLocationForItem(item), stockLocation.quantity >= (itemQuantities[item.id] ?? 1) else {
                errorMessages.append("\(item.name): No stock location found or insufficient quantity")
                allSuccessful = false
                continue
            }
            
            dispatchGroup.enter()
            
            let quantity = itemQuantities[item.id] ?? 1
            
            usageManager.recordItemUsage(
                item: item,
                quantity: quantity,
                jobId: selectedJobId,
                jobNumber: selectedJobNumber,
                technician: user,
                vehicle: vehicle,
                serviceRecord: nil as AppServiceRecord?, // Could be linked to service record if needed
                imageData: photoData,
                comments: comments
            ) { success, error in
                if !success {
                    allSuccessful = false
                    if let error = error {
                        errorMessages.append("\(item.name): \(error)")
                    }
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            isSubmitting = false
            
            if allSuccessful {
                alertMessage = "Inventory usage recorded successfully"
                showingSuccessAlert = true
            } else {
                alertMessage = "Failed to record some items:\n" + errorMessages.joined(separator: "\n")
                showingErrorAlert = true
            }
        }
    }
    
    // Check if this is the first time using the feature
    private func checkFirstTimeUser() {
        let key = "hasSeenInventoryUsageTutorial"
        if !UserDefaults.standard.bool(forKey: key) {
            showingTutorial = true
            UserDefaults.standard.set(true, forKey: key)
        }
    }
}

/// View for selecting inventory items for usage
struct InventorySelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedItems: [AppInventoryItem]
    var showVehicleOnly: Bool
    
    @State private var searchText = ""
    @State private var selectedCategories: Set<String> = []
    @State private var allItems: [AppInventoryItem] = []
    @State private var categories: [String] = []
    
    // Fetch stock locations
    @Query private var stockLocations: [StockLocationItem]
    
    var filteredItems: [AppInventoryItem] {
        var result = allItems
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.partNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by categories
        if !selectedCategories.isEmpty {
            result = result.filter { selectedCategories.contains($0.category) }
        }
        
        return result
    }
    
    var body: some View {
        VStack {
            // Search bar
            SearchBar(text: $searchText, placeholder: "Search items...")
                .padding(.horizontal)
            
            // Category filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.self) { category in
                        CategoryFilterButton(
                            title: category,
                            isSelected: selectedCategories.contains(category),
                            action: {
                                toggleCategory(category)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 10)
            
            // Inventory items list
            List {
                ForEach(filteredItems) { item in
                    ItemSelectionRow(
                        item: item, 
                        stockLocation: findStockLocationForItem(item),
                        isSelected: selectedItems.contains(where: { $0.id == item.id }),
                        toggleAction: {
                            toggleItemSelection(item)
                        }
                    )
                }
            }
            .listStyle(PlainListStyle())
            
            // Selection summary and done button
            VStack {
                Text("\(selectedItems.count) items selected")
                    .foregroundColor(.secondary)
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(radius: 2)
        }
        .navigationTitle("Select Inventory Items")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadInventoryItems()
        }
    }
    
    // Helper to find stock location for an inventory item
    private func findStockLocationForItem(_ item: AppInventoryItem) -> StockLocationItem? {
        stockLocations.first(where: { $0.inventoryItem?.id == item.id })
    }
    
    // Load inventory items
    private func loadInventoryItems() {
        do {
            if showVehicleOnly {
                // Get items from stock locations that have vehicles
                let items = stockLocations
                    .filter { $0.vehicle != nil && $0.inventoryItem != nil }
                    .compactMap { $0.inventoryItem }
                allItems = Array(Set(items)) // Remove duplicates
            } else {
                // Fetch all items
                let descriptor = FetchDescriptor<AppInventoryItem>()
                allItems = try modelContext.fetch(descriptor)
            }
            
            // Extract unique categories
            categories = Array(Set(allItems.map { $0.category })).sorted()
        } catch {
            print("Failed to fetch inventory items: \(error)")
        }
    }
    
    // Toggle category selection
    private func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
    
    // Toggle item selection
    private func toggleItemSelection(_ item: AppInventoryItem) {
        if let index = selectedItems.firstIndex(where: { $0.id == item.id }) {
            selectedItems.remove(at: index)
        } else {
            selectedItems.append(item)
        }
    }
}

// Search bar component
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.primary)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// Category filter button
struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// Item selection row
struct ItemSelectionRow: View {
    let item: AppInventoryItem
    let stockLocation: StockLocationItem?
    let isSelected: Bool
    let toggleAction: () -> Void
    
    var body: some View {
        Button(action: toggleAction) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    
                    Text(item.partNumber)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        if let stockLocation = stockLocation {
                            Text("Qty: \(stockLocation.quantity)")
                                .font(.caption)
                            
                            if let vehicle = stockLocation.vehicle {
                                Text("(\(vehicle.displayName))")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        } else {
                            Text("Qty: 0")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Text(item.category)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor(for: item.category))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color("vehix-blue"))
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Get color for category
    private func categoryColor(for category: String) -> Color {
        let colors: [Color] = [Color("vehix-blue"), Color("vehix-green"), .purple, Color("vehix-orange"), .red, .teal]
        let hash = abs(category.hashValue)
        let index = hash % colors.count
        return colors[index]
    }
}

// Tutorial view
struct InventoryUsageTutorialView: View {
    @Binding var showTutorial: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Tutorial content
                    InventoryTutorialStep(
                        title: "Record Inventory Usage",
                        description: "Track inventory items used during jobs to maintain accurate stock levels.",
                        icon: "shippingbox"
                    )
                    
                    InventoryTutorialStep(
                        title: "Select Items",
                        description: "Choose items from your vehicle's inventory or the main warehouse.",
                        icon: "checklist"
                    )
                    
                    InventoryTutorialStep(
                        title: "Add Details",
                        description: "Enter job information and add photos for better record keeping.",
                        icon: "doc.text.image"
                    )
                    
                    InventoryTutorialStep(
                        title: "Submit Usage",
                        description: "Submit the form to update inventory levels automatically.",
                        icon: "arrow.up.doc"
                    )
                }
                .padding()
            }
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Get Started") {
                        showTutorial = false
                    }
                }
            }
        }
    }
}

// Tutorial step component
struct InventoryTutorialStep: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    InventoryUsageView()
        .environmentObject(AppAuthService())
} 