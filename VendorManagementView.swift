import SwiftUI
import SwiftData

struct VendorManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppVendor.name) private var vendors: [AppVendor]
    
    @StateObject private var vendorManager = VendorRecognitionManager()
    @State private var searchText = ""
    @State private var showingAddVendor = false
    @State private var selectedVendor: AppVendor?
    @State private var showingDeleteConfirmation = false
    @State private var showTutorial = false
    
    var filteredVendors: [AppVendor] {
        if searchText.isEmpty {
            return vendors
        } else {
            return vendors.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if vendorManager.isLoading {
                    ProgressView("Loading vendors...")
                } else if vendors.isEmpty {
                    emptyStateView
                } else {
                    vendorListView
                }
            }
            .navigationTitle("Vendors")
            .searchable(text: $searchText, prompt: "Search vendors")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddVendor = true
                    }) {
                        Label("Add Vendor", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            Task {
                                await vendorManager.fetchVendorsFromCloudKit()
                            }
                        }) {
                            Label("Sync with Cloud", systemImage: "arrow.triangle.2.circlepath.circle")
                        }
                        
                        Button(action: {
                            showTutorial = true
                        }) {
                            Label("View Tutorial", systemImage: "questionmark.circle")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddVendor) {
                AddVendorView()
            }
            .sheet(item: $selectedVendor) { vendor in
                EnhancedVendorDetailView(vendor: vendor)
            }
            .alert("Delete Vendor", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let vendor = selectedVendor {
                        modelContext.delete(vendor)
                        try? modelContext.save()
                        selectedVendor = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this vendor? This cannot be undone.")
            }
            .fullScreenCover(isPresented: $showTutorial) {
                VendorTutorialView(showTutorial: $showTutorial)
            }
            .onAppear {
                vendorManager.setModelContext(modelContext)
                checkFirstTimeUser()
            }
        }
    }
    
    // Check if it's the first time using vendor management
    private func checkFirstTimeUser() {
        let hasSeenVendorTutorial = UserDefaults.standard.bool(forKey: "hasSeenVendorTutorial")
        if !hasSeenVendorTutorial {
            showTutorial = true
            UserDefaults.standard.set(true, forKey: "hasSeenVendorTutorial")
        }
    }
    
    // Empty state view when no vendors are available
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2")
                .font(.system(size: 70))
                .foregroundColor(.gray)
            
            Text("No Vendors Found")
                .font(.title2)
            
            Text("Add vendors or sync with the cloud database")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: {
                showingAddVendor = true
            }) {
                Label("Add Vendor", systemImage: "plus")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
            
            Button(action: {
                Task {
                    await vendorManager.fetchVendorsFromCloudKit()
                }
            }) {
                Label("Sync with Cloud", systemImage: "arrow.triangle.2.circlepath")
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // List view for displaying vendors
    private var vendorListView: some View {
        List {
            ForEach(filteredVendors) { vendor in
                VendorRow(vendor: vendor)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedVendor = vendor
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            selectedVendor = vendor
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// Row for displaying a vendor in the list
struct VendorRow: View {
    let vendor: AppVendor
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vendor.name)
                    .font(.headline)
                
                Text(vendor.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let phone = vendor.phone {
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if vendor.isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// View for adding a new vendor
struct AddVendorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var isActive = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Vendor Name", text: $name)
                    TextField("Email", text: $email)
                    TextField("Phone", text: $phone)
                    TextField("Address", text: $address)
                    Toggle("Active", isOn: $isActive)
                }
                
                Section {
                    Button("Save Vendor") {
                        saveVendor()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(name.isEmpty || email.isEmpty)
                }
            }
            .navigationTitle("Add Vendor")
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
                    .disabled(name.isEmpty || email.isEmpty)
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
        
        dismiss()
    }
}

// Detail view for a vendor
struct VendorDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let vendor: AppVendor
    
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var address: String
    @State private var isActive: Bool
    @State private var isEditing = false
    
    init(vendor: AppVendor) {
        self.vendor = vendor
        _name = State(initialValue: vendor.name)
        _email = State(initialValue: vendor.email)
        _phone = State(initialValue: vendor.phone ?? "")
        _address = State(initialValue: vendor.address ?? "")
        _isActive = State(initialValue: vendor.isActive)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if isEditing {
                    editForm
                } else {
                    detailView
                }
            }
            .navigationTitle(isEditing ? "Edit Vendor" : "Vendor Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                            isEditing = false
                        }
                        .disabled(name.isEmpty || email.isEmpty)
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
            }
        }
    }
    
    private var detailView: some View {
        Group {
            Section {
                HStack {
                    Text("Name")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(vendor.name)
                }
                
                HStack {
                    Text("Email")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(vendor.email)
                }
                
                if let phone = vendor.phone {
                    HStack {
                        Text("Phone")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(phone)
                    }
                }
                
                if let address = vendor.address {
                    HStack {
                        Text("Address")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(address)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                HStack {
                    Text("Status")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(vendor.isActive ? "Active" : "Inactive")
                        .foregroundColor(vendor.isActive ? .green : .red)
                }
                
                HStack {
                    Text("Created")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(vendor.createdAt, style: .date)
                }
                
                HStack {
                    Text("Last Updated")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(vendor.updatedAt, style: .date)
                }
            }
            
            // In a real app, you would show related receipts here
            Section("Related Receipts") {
                Text("No receipts found with this vendor")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
    
    private var editForm: some View {
        Group {
            Section {
                TextField("Vendor Name", text: $name)
                TextField("Email", text: $email)
                TextField("Phone (optional)", text: $phone)
                TextField("Address (optional)", text: $address)
                Toggle("Active", isOn: $isActive)
            }
            
            Section {
                Button("Cancel") {
                    // Reset to original values
                    name = vendor.name
                    email = vendor.email
                    phone = vendor.phone ?? ""
                    address = vendor.address ?? ""
                    isActive = vendor.isActive
                    isEditing = false
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.red)
            }
        }
    }
    
    private func saveChanges() {
        vendor.name = name
        vendor.email = email
        vendor.phone = phone.isEmpty ? nil : phone
        vendor.address = address.isEmpty ? nil : address
        vendor.isActive = isActive
        vendor.updatedAt = Date()
        
        try? modelContext.save()
    }
}

#Preview {
    VendorManagementView()
        .modelContainer(for: Vehix.Vendor.self, inMemory: true)
} 