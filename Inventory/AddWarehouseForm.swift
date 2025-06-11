import SwiftUI
import SwiftData

struct VehixAddWarehouseForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var onSave: ((AppWarehouse) -> Void)?

    @State private var name = ""
    @State private var location = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Warehouse Details") {
                    TextField("Name", text: $name)
                    TextField("Location/Address", text: $location)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section {
                    Button("Save Warehouse") {
                        saveWarehouse()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(name.isEmpty || location.isEmpty)
                }
            }
            .navigationTitle("Add Warehouse")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveWarehouse() {
        // Create warehouse with description
        let warehouse = AppWarehouse(
            id: UUID().uuidString,
            name: name,
            location: location,
            warehouseDescription: description
        )
        
        modelContext.insert(warehouse)
        try? modelContext.save()
        
        onSave?(warehouse)
        dismiss()
    }
}

struct DeleteWarehouseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AppAuthService
    
    let warehouse: AppWarehouse
    let onDelete: (String) -> Void
    
    @State private var managerPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                            .padding(.bottom, 10)
                        
                        Text("You are about to delete \"\(warehouse.name)\"")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text("This action will permanently delete this warehouse and all stock location data associated with it. This cannot be undone.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                Section("Manager Authorization Required") {
                    SecureField("Enter your password", text: $managerPassword)
                        .autocorrectionDisabled(true)
                        .textContentType(.password)
                }
                
                Section {
                    Button("Delete Warehouse") {
                        validateAndDelete()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.red)
                    .disabled(managerPassword.isEmpty)
                }
            }
            .navigationTitle("Delete Warehouse")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func validateAndDelete() {
        // Check for admin or dealer role
        guard let currentUser = authService.currentUser,
              currentUser.userRole == .admin || currentUser.userRole == .dealer else {
            errorMessage = "You don't have permission to delete warehouses"
            showingError = true
            return
        }
        
        // Call the delete function with the manager password
        onDelete(managerPassword)
        dismiss()
    }
}

// For compatibility with existing code, create a type alias
typealias AddWarehouseForm = VehixAddWarehouseForm

#Preview {
    VehixAddWarehouseForm()
} 