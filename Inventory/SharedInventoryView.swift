import SwiftUI
import SwiftData

struct SharedInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var cloudKitManager: CloudKitManager
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [AppInventoryItem] = []
    @State private var errorMessage: String?
    @State private var selectedCategories: Set<String> = []
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    
    // Common categories for filtering
    let categories = ["Brakes", "Engine", "Electrical", "Filters", "Fluids", "Suspension", "HVAC", "Lighting", "Exhaust", "Tools", "Other"]
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search shared inventory catalog", text: $searchText)
                        .onSubmit {
                            searchSharedInventory()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button(action: searchSharedInventory) {
                        Text("Search")
                            .bold()
                    }
                    .disabled(searchText.isEmpty)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Categories filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            FilterChip(
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
                
                // Search results or instructions
                if isSearching {
                    ProgressView("Searching shared inventory...")
                        .padding()
                } else if let error = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                            .padding()
                        
                        Text("No items found matching '\(searchText)'")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if searchResults.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue.opacity(0.7))
                            .padding()
                        
                        Text("Search the Shared Inventory Catalog")
                            .font(.headline)
                        
                        Text("Find parts and supplies shared by other Vehix users. Search by part name, number, or browse by category.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Benefits:")
                                .font(.headline)
                            
                            HStack(alignment: .top) {
                                Text("•")
                                Text("Access to thousands of pre-configured parts")
                            }
                            
                            HStack(alignment: .top) {
                                Text("•")
                                Text("Quickly add items to your inventory")
                            }
                            
                            HStack(alignment: .top) {
                                Text("•")
                                Text("Save time on data entry")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    .padding()
                } else {
                    // Results list
                    List {
                        ForEach(filteredResults) { item in
                            SharedInventoryItemRow(item: item) {
                                importItem(item)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Shared Inventory")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(successMessage)
            }
        }
    }
    
    // Filtered results based on selected categories
    private var filteredResults: [AppInventoryItem] {
        if selectedCategories.isEmpty {
            return searchResults
        } else {
            return searchResults.filter { selectedCategories.contains($0.category) }
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
    
    // Search shared inventory
    private func searchSharedInventory() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        // Simulate search delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSearching = false
            self.errorMessage = "Shared inventory search is currently under development. This feature will be available in a future update."
            self.searchResults = []
        }
    }
    
    // Import an item into the user's inventory
    private func importItem(_ item: AppInventoryItem) {
        // Create a copy of the shared item
        let newItem = AppInventoryItem()
        newItem.name = item.name
        newItem.partNumber = item.partNumber
        newItem.itemDescription = item.itemDescription
        newItem.category = item.category
        newItem.pricePerUnit = item.pricePerUnit
        newItem.reorderPoint = item.reorderPoint
        newItem.supplier = item.supplier
        
        // Save to the user's inventory
        modelContext.insert(newItem)
        
        // Create a default StockLocationItem for a warehouse if available
        // Fetch the default warehouse (first one found)
        let fetchDescriptor = FetchDescriptor<AppWarehouse>()
        if let defaultWarehouse = try? modelContext.fetch(fetchDescriptor).first {
            // Create stock location item
            let stockItem = StockLocationItem(
                inventoryItem: newItem,
                quantity: 0, // Start with 0 quantity since it's not physically in inventory yet
                minimumStockLevel: 5, // Default minimum stock level
                warehouse: defaultWarehouse
            )
            modelContext.insert(stockItem)
        }
        
        do {
            try modelContext.save()
            successMessage = "\(item.name) added to your inventory"
            showSuccessAlert = true
        } catch {
            errorMessage = "Failed to import item: \(error.localizedDescription)"
        }
    }
}

// Reusable filter chip component
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// Inventory item row with import button
struct SharedInventoryItemRow: View {
    let item: AppInventoryItem
    let importAction: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                Text("Part #: \(item.partNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let description = item.itemDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text("Category: \(item.category)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                if item.pricePerUnit > 0 {
                    Text("$\(String(format: "%.2f", item.pricePerUnit))")
                        .font(.callout)
                        .bold()
                } else {
                    Text("No price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: importAction) {
                    Text("Import")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
            }
            .frame(width: 80)
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    SharedInventoryView()
} 