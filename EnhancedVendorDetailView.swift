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
    
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3308, longitude: -122.0074),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @State private var isEditingLocation = false
    @State private var location: CLLocationCoordinate2D?
    
    // Inventory items from this vendor
    @Query private var allItems: [AppInventoryItem]
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
        
        // Load extended properties if available
        if let extendedData = UserDefaults.standard.dictionary(forKey: "vendor_extended_\(vendor.id)") {
            _contactName = State(initialValue: extendedData["contactName"] as? String ?? "")
            _website = State(initialValue: extendedData["website"] as? String ?? "")
            _paymentTerms = State(initialValue: extendedData["paymentTerms"] as? String ?? "")
            _notes = State(initialValue: extendedData["notes"] as? String ?? "")
            
            // Load location if available
            if let latitude = extendedData["latitude"] as? Double,
               let longitude = extendedData["longitude"] as? Double {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                _location = State(initialValue: coordinate)
                _mapRegion = State(initialValue: MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
            }
        }
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
        // Update basic vendor properties
        vendor.name = name
        vendor.email = email
        vendor.phone = phone.isEmpty ? nil : phone
        vendor.address = address.isEmpty ? nil : address
        vendor.isActive = isActive
        vendor.updatedAt = Date()
        
        // Save extended properties to UserDefaults
        var extendedData: [String: Any] = [
            "contactName": contactName,
            "website": website,
            "paymentTerms": paymentTerms,
            "notes": notes
        ]
        
        // Save location if available
        if let location = location {
            extendedData["latitude"] = location.latitude
            extendedData["longitude"] = location.longitude
        }
        
        UserDefaults.standard.set(extendedData, forKey: "vendor_extended_\(vendor.id)")
        
        // Save changes to SwiftData
        do {
            try modelContext.save()
        } catch {
            print("Error saving vendor changes: \(error)")
        }
    }
    
    private func deleteVendor() {
        // Delete extended data
        UserDefaults.standard.removeObject(forKey: "vendor_extended_\(vendor.id)")
        
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
        email: "sample@example.com",
        phone: "555-0123",
        address: "123 Main St"
    ))
    .modelContainer(for: Vehix.Vendor.self, inMemory: true)
}
