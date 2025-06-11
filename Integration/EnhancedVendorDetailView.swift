import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct EnhancedVendorDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let vendor: AppVendor
    
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var address: String
    @State private var contactName: String = ""
    @State private var website: String = ""
    @State private var paymentTerms: String = ""
    @State private var notes: String = ""
    @State private var isActive: Bool
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEmailTemplate = false
    @State private var isDataLoaded = false
    
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3308, longitude: -122.0074),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @State private var isEditingLocation = false
    @State private var location: CLLocationCoordinate2D?
    
    @Query(sort: [SortDescriptor<AppInventoryItem>(\.name)]) private var allItems: [AppInventoryItem]
    private var vendorItems: [AppInventoryItem] {
        allItems.filter { $0.supplier == vendor.id }
    }
    
    init(vendor: AppVendor) {
        self.vendor = vendor
        _name = State(initialValue: vendor.name)
        _email = State(initialValue: vendor.email)
        _phone = State(initialValue: vendor.phone ?? "")
        _address = State(initialValue: vendor.address ?? "")
        _isActive = State(initialValue: vendor.isActive)
        
        // Initialize with empty values - will load from file in onAppear
        _contactName = State(initialValue: "")
        _website = State(initialValue: "")
        _paymentTerms = State(initialValue: "")
        _notes = State(initialValue: "")
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
                        .disabled(name.isEmpty)
                    } else {
                        Menu {
                            Button(action: {
                                isEditing = true
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(action: {
                                showingEmailTemplate = true
                            }) {
                                Label("Email Template", systemImage: "envelope")
                            }
                            
                            Button(role: .destructive, action: {
                                showingDeleteConfirmation = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Delete Vendor", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteVendor()
                }
            } message: {
                Text("Are you sure you want to delete this vendor? This cannot be undone.")
            }
            .sheet(isPresented: $showingEmailTemplate) {
                VendorEmailTemplateView(vendor: vendor, items: vendorItems)
            }
            .onAppear {
                loadVendorExtendedData()
                isDataLoaded = true
            }
        }
    }
    
    // MARK: - View Components
    
    private var detailView: some View {
        Group {
            // Basic information section
            Section(header: Text("Basic Information")) {
                VendorDetailRow(label: "Name", value: vendor.name)
                
                if !email.isEmpty {
                    VendorDetailRow(label: "Email", value: email)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let emailURL = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(emailURL)
                            }
                        }
                }
                
                if !phone.isEmpty {
                    VendorDetailRow(label: "Phone", value: phone)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let phoneURL = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                                UIApplication.shared.open(phoneURL)
                            }
                        }
                }
                
                if !contactName.isEmpty {
                    VendorDetailRow(label: "Contact", value: contactName)
                }
                
                if !website.isEmpty {
                    VendorDetailRow(label: "Website", value: website)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let url = URL(string: website) {
                                UIApplication.shared.open(url)
                            }
                        }
                }
                
                VendorDetailRow(label: "Status", value: vendor.isActive ? "Active" : "Inactive")
                
                if let serviceTitanId = vendor.serviceTitanId {
                    VendorDetailRow(label: "ServiceTitan ID", value: serviceTitanId)
                }
            }
            
            // Address and map section
            if !address.isEmpty || location != nil {
                Section(header: Text("Location")) {
                    if !address.isEmpty {
                        Text(address)
                            .font(.callout)
                    }
                    
                    if let location = location {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: location,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        ))) {
                            Marker(vendor.name, coordinate: location)
                        }
                        .frame(height: 200)
                        .cornerRadius(8)
                        
                        Button(action: {
                            openInMaps(coordinate: location, name: vendor.name)
                        }) {
                            Label("Open in Maps", systemImage: "map")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            
            // Payment terms section
            if !paymentTerms.isEmpty {
                Section(header: Text("Payment Terms")) {
                    Text(paymentTerms)
                }
            }
            
            // Notes section
            if !notes.isEmpty {
                Section(header: Text("Notes")) {
                    Text(notes)
                }
            }
            
            // Inventory items from this vendor
            Section(header: Text("Inventory Items")) {
                if vendorItems.isEmpty {
                    Text("No inventory items from this vendor")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(vendorItems) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                
                                if !item.partNumber.isEmpty {
                                    Text(item.partNumber)
                                        .font(.caption)
                                }
                            }
                            
                            Spacer()
                            
                            // Get total quantity from all stock locations
                            let totalQty = item.stockLocationItems?.reduce(0) { $0 + $1.quantity } ?? 0
                            Text("Qty: \(totalQty)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var editForm: some View {
        Group {
            Section(header: Text("Basic Information")) {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                TextField("Phone", text: $phone)
                TextField("Address", text: $address)
                TextField("Contact Name", text: $contactName)
                TextField("Website", text: $website)
                TextField("Payment Terms", text: $paymentTerms)
                Toggle("Active", isOn: $isActive)
            }
            
            Section(header: Text("Notes")) {
                TextEditor(text: $notes)
                    .frame(height: 100)
            }
            
            if let location = location {
                Section(header: Text("Location")) {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))) {
                        Marker(vendor.name, coordinate: location)
                    }
                    .frame(height: 200)
                    .cornerRadius(8)
                }
            }
            
            Section {
                Button("Update Location") {
                    geocodeAddress(address)
                }
                .disabled(address.isEmpty)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveChanges() {
        // Only save if data has been loaded to prevent crashes during initialization
        guard isDataLoaded else {
            print("⚠️ Skipping save - data not yet loaded")
            return
        }
        
        // Update basic vendor properties
        vendor.name = name
        vendor.email = email
        vendor.phone = phone.isEmpty ? nil : phone
        vendor.address = address.isEmpty ? nil : address
        vendor.isActive = isActive
        vendor.updatedAt = Date()
        
        // Save extended properties to a file instead of UserDefaults
        saveVendorExtendedData()
        
        // Save changes to SwiftData
        do {
            try modelContext.save()
        } catch {
            print("Error saving vendor changes: \(error)")
        }
    }
    
    private func deleteVendor() {
        // Delete extended data file
        deleteVendorExtendedData()
        
        // Delete from SwiftData
        modelContext.delete(vendor)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error deleting vendor: \(error)")
        }
    }
    
    private func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: nil)
    }
    
    private func geocodeAddress(_ address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error)")
                return
            }
            
            if let location = placemarks?.first?.location?.coordinate {
                self.location = location
                self.mapRegion = MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        }
    }
    
    // MARK: - File Management
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private func vendorExtendedDataURL() -> URL {
        getDocumentsDirectory().appendingPathComponent("vendor_extended_\(vendor.id).json")
    }
    
    private func saveVendorExtendedData() {
        // Don't save if data hasn't been loaded yet
        guard isDataLoaded else {
            print("⚠️ Skipping save - vendor data not loaded yet")
            return
        }
        
        // Create JSON-safe dictionary with proper type checking
        var extendedData: [String: String] = [:]
        
        // Only add non-empty strings to avoid JSON issues
        if !contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            extendedData["contactName"] = contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            extendedData["website"] = website.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !paymentTerms.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            extendedData["paymentTerms"] = paymentTerms.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            extendedData["notes"] = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Save location separately as numbers to ensure JSON compatibility
        var finalData: [String: Any] = extendedData
        if let location = location {
            // Ensure coordinates are valid finite numbers
            let lat = location.latitude
            let lon = location.longitude
            
            if lat.isFinite && lon.isFinite && 
               lat >= -90 && lat <= 90 && 
               lon >= -180 && lon <= 180 {
                finalData["latitude"] = lat
                finalData["longitude"] = lon
            } else {
                print("⚠️ Invalid coordinates detected, skipping location save")
            }
        }
        
        // Skip saving if there's no actual data to save
        if finalData.isEmpty {
            print("📂 No extended data to save for vendor")
            return
        }
        
        // Validate JSON compatibility before serialization
        guard JSONSerialization.isValidJSONObject(finalData) else {
            print("⚠️ Extended data is not valid JSON object")
            return
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: finalData, options: .prettyPrinted)
            try data.write(to: vendorExtendedDataURL())
            print("✅ Vendor extended data saved successfully")
        } catch {
            print("❌ Error saving vendor extended data: \(error)")
        }
    }
    
    private func loadVendorExtendedData() {
        let url = vendorExtendedDataURL()
        guard FileManager.default.fileExists(atPath: url.path) else { 
            print("📂 No extended data file found for vendor \(vendor.id)")
            return 
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            // Handle empty files
            guard !data.isEmpty else {
                print("📂 Extended data file is empty for vendor \(vendor.id)")
                return
            }
            
            if let extendedData = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                contactName = extendedData["contactName"] as? String ?? ""
                website = extendedData["website"] as? String ?? ""
                paymentTerms = extendedData["paymentTerms"] as? String ?? ""
                notes = extendedData["notes"] as? String ?? ""
                
                if let lat = extendedData["latitude"] as? Double,
                   let lon = extendedData["longitude"] as? Double {
                    location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    mapRegion = MKCoordinateRegion(
                        center: location!,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                }
                print("✅ Vendor extended data loaded successfully")
            } else {
                print("⚠️ Could not parse extended data as dictionary")
            }
        } catch {
            print("❌ Error loading vendor extended data: \(error)")
            // Don't crash the app, just continue with empty data
        }
    }
    
    private func deleteVendorExtendedData() {
        try? FileManager.default.removeItem(at: vendorExtendedDataURL())
    }
}

// Helper view for detail rows
struct VendorDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    EnhancedVendorDetailView(vendor: AppVendor(
        name: "Sample Vendor",
                        email: "sample@icloud.com",
        phone: "555-0123",
        address: "123 Main St"
    ))
    .modelContainer(for: Vehix.Vendor.self, inMemory: true)
}
