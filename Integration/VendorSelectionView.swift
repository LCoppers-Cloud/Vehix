import SwiftUI
import SwiftData
import CoreLocation

struct VendorSelectionView: View {
    @ObservedObject var creationManager: PurchaseOrderCreationManager
    @EnvironmentObject var authService: AppAuthService
    
    @State private var vendors: [AppVendor] = []
    @State private var nearbyVendors: [AppVendor] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showingAddVendor = false
    @State private var showingNearbyVendors = false
    
    // User's current role
    private var isManager: Bool {
        authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .admin
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading vendors...")
                    .padding()
            } else if vendors.isEmpty && !nearbyVendors.isEmpty {
                // Show nearby vendors when no vendors are available from ServiceTitan
                nearbyVendorsView
            } else if vendors.isEmpty {
                emptyVendorsView
            } else {
                vendorListView
            }
        }
        .onAppear {
            loadVendors()
            checkForNearbyVendors()
        }
        .sheet(isPresented: $showingAddVendor) {
            VendorAdditionView { newVendor in
                vendors.append(newVendor)
                creationManager.selectVendor(newVendor)
            }
        }
    }
    
    // Empty state when no vendors are available
    private var emptyVendorsView: some View {
        VStack {
            Image(systemName: "building.2")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .padding()
            
            Text("No vendors found")
                .font(.headline)
                .padding()
            
            Text("You are not connected to ServiceTitan or no vendors are available.")
                .multilineTextAlignment(.center)
                .padding()
            
            // Only managers can add vendors
            if isManager {
                Button("Add New Vendor") {
                    showingAddVendor = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.top, 10)
            } else {
                Text("Please ask a manager to add vendors to the system.")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    // View for showing nearby vendors
    private var nearbyVendorsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nearby Vendors")
                .font(.headline)
                .padding(.horizontal)
            
            Text("We detected these vendors near your current location:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            List {
                ForEach(nearbyVendors) { vendor in
                    PurchaseOrderVendorRow(vendor: vendor, isNearby: true) {
                        creationManager.selectVendor(vendor)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            // Only managers can add vendors
            if isManager {
                Button("Add Different Vendor") {
                    showingAddVendor = true
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(10)
                .padding()
            }
        }
    }
    
    // Main vendor list
    private var vendorListView: some View {
        VStack {
            // Search bar
            TextField("Search vendors", text: $searchText)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
            
            if !nearbyVendors.isEmpty {
                HStack {
                    Text("📍 Nearby Vendors Available")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button("Show Nearby") {
                        showingNearbyVendors = true
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
            }
            
            Text("Select the vendor for this purchase:")
                .font(.subheadline)
                .padding(.top)
            
            List {
                if !nearbyVendors.isEmpty && showingNearbyVendors {
                    Section(header: Text("Nearby Vendors")) {
                        ForEach(nearbyVendors) { vendor in
                            PurchaseOrderVendorRow(vendor: vendor, isNearby: true) {
                                creationManager.selectVendor(vendor)
                            }
                        }
                    }
                }
                
                Section(header: Text(nearbyVendors.isEmpty ? "Vendors" : "All Vendors")) {
                    ForEach(filteredVendors) { vendor in
                        PurchaseOrderVendorRow(vendor: vendor, isNearby: false) {
                            creationManager.selectVendor(vendor)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            // Only managers can add vendors
            if isManager {
                Button("Add New Vendor") {
                    showingAddVendor = true
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(10)
                .padding()
            }
        }
    }
    
    // Filter vendors based on search text
    private var filteredVendors: [AppVendor] {
        if searchText.isEmpty {
            return vendors.filter { $0.isActive }
        } else {
            return vendors.filter { $0.isActive && $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    // Load vendors from ServiceTitan or database
    private func loadVendors() {
        isLoading = true
        
        creationManager.syncManager.syncVendors { success in
            isLoading = false
            if success {
                vendors = creationManager.syncManager.vendors
            }
        }
    }
    
    // Check for vendors near the user's current location
    private func checkForNearbyVendors() {
        guard let currentLocation = creationManager.currentLocation else { return }
        
        // This would typically query a database or API
        // For now, we'll simulate finding nearby vendors based on current location
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Sample nearby vendors (in a real app, you would use a geospatial query)
            self.nearbyVendors = [
                AppVendor(
                    name: "Home Depot",
                    email: "orders@homedepot.com",
                    phone: "1-800-HOME-DEPOT",
                    address: "\(String(format: "%.4f", currentLocation.latitude)), \(String(format: "%.4f", currentLocation.longitude))",
                    isActive: true
                ),
                AppVendor(
                    name: "Lowe's Hardware",
                    email: "service@lowes.com",
                    phone: "1-800-LOWES",
                    address: "Near your current location",
                    isActive: true
                )
            ]
        }
    }
}

// Vendor row component with nearby indicator
struct PurchaseOrderVendorRow: View {
    let vendor: AppVendor
    let isNearby: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(vendor.name)
                            .font(.headline)
                        
                        if isNearby {
                            Text("📍 Nearby")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(vendor.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let phone = vendor.phone {
                        Text(phone)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Add Vendor View (only available for managers) - renamed to avoid conflicts
struct VendorAdditionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var isActive = true
    
    var onVendorAdded: (AppVendor) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Vendor Information")) {
                    TextField("Vendor Name", text: $name)
                        .autocapitalization(.words)
                    
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    
                    TextField("Address", text: $address)
                    
                    Toggle("Active", isOn: $isActive)
                }
                
                Section {
                    Button("Save Vendor") {
                        saveVendor()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle("Add New Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveVendor()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveVendor() {
        let vendor = AppVendor(
            name: name,
            email: email,
            phone: phone.isEmpty ? nil : phone,
            address: address.isEmpty ? nil : address,
            isActive: isActive
        )
        
        modelContext.insert(vendor)
        try? modelContext.save()
        
        // Call the completion handler with the new vendor
        onVendorAdded(vendor)
        
        dismiss()
    }
} 