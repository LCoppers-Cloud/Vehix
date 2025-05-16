import Foundation
import SwiftUI
import SwiftData

// Model for ServiceTitan technician data
struct ServiceTitanTechnician: Identifiable, Codable {
    var id: String
    var name: String
    var email: String
    var phone: String?
    var role: String?
    var isActive: Bool
    var serviceTitanId: String
    
    // Convert to User model
    func toUser() -> AppUser {
        let user = AppUser(
            email: email,
            fullName: name,
            role: .technician,
            isVerified: true
        )
        return user
    }
}

class ServiceTitanSyncManager: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var technicians: [ServiceTitanTechnician] = []
    @Published var vehicles: [AppVehicle] = []
    @Published var vendors: [AppVendor] = []
    @Published var jobs: [ServiceTitanJob] = []
    
    private var service: ServiceTitanService
    private var modelContext: ModelContext?
    
    init(service: ServiceTitanService, modelContext: ModelContext? = nil) {
        self.service = service
        self.modelContext = modelContext
    }
    
    // Set model context
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // Get model context (used by PurchaseOrderCreation)
    func getModelContext() -> ModelContext? {
        return modelContext
    }
    
    // Sync technicians from ServiceTitan
    func syncTechnicians(completion: @escaping (Bool) -> Void) {
        guard let modelContext = modelContext else {
            errorMessage = "Model context not available"
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // In a real implementation, this would call the ServiceTitan API
        // For demonstration, we'll simulate fetching technicians
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Simulate technicians from ServiceTitan
            self.technicians = [
                ServiceTitanTechnician(id: "1", name: "John Smith", email: "john.smith@example.com", phone: "555-123-4567", role: "Senior Technician", isActive: true, serviceTitanId: "ST-1001"),
                ServiceTitanTechnician(id: "2", name: "Maria Garcia", email: "maria.garcia@example.com", phone: "555-987-6543", role: "Technician", isActive: true, serviceTitanId: "ST-1002"),
                ServiceTitanTechnician(id: "3", name: "David Lee", email: "david.lee@example.com", phone: "555-456-7890", role: "Apprentice", isActive: true, serviceTitanId: "ST-1003"),
                ServiceTitanTechnician(id: "4", name: "Sarah Johnson", email: "sarah.johnson@example.com", phone: "555-789-0123", role: "Senior Technician", isActive: true, serviceTitanId: "ST-1004"),
                ServiceTitanTechnician(id: "5", name: "Michael Brown", email: "michael.brown@example.com", phone: "555-234-5678", role: "Technician", isActive: false, serviceTitanId: "ST-1005")
            ]
            
            // Also fetch vehicles for assignment
            do {
                let descriptor = FetchDescriptor<AppVehicle>()
                self.vehicles = try modelContext.fetch(descriptor)
            } catch {
                self.errorMessage = "Failed to fetch vehicles: \(error.localizedDescription)"
            }
            
            self.isLoading = false
            completion(true)
        }
    }
    
    // Save a technician to the local database as a User
    func saveTechnician(_ technician: ServiceTitanTechnician, assignedVehicleIds: [String]) {
        guard let modelContext = modelContext else {
            errorMessage = "Model context not available"
            return
        }
        
        // Check if user with this email already exists
        do {
            // Use SwiftData's native predicate
            let descriptor = FetchDescriptor<AppUser>(
                predicate: #Predicate<AppUser> { user in
                    user.email == technician.email
                }
            )
            let existingUsers = try modelContext.fetch(descriptor)
            
            let user: AppUser
            
            if let existingUser = existingUsers.first {
                // Update existing user
                user = existingUser
                user.fullName = technician.name
                user.userRole = .technician
                user.isVerified = true
            } else {
                // Create new user
                user = technician.toUser()
                modelContext.insert(user)
            }
            
            // Assign vehicles
            if !assignedVehicleIds.isEmpty {
                // Get vehicle objects for the IDs
                let vehicleDescriptor = FetchDescriptor<AppVehicle>(
                    predicate: #Predicate<AppVehicle> { vehicle in
                        assignedVehicleIds.contains(vehicle.id)
                    }
                )
                let vehicles = try modelContext.fetch(vehicleDescriptor)
                
                // Create VehicleAssignment records
                for vehicle in vehicles {
                    let assignment = VehicleAssignment(
                        vehicleId: vehicle.id,
                        userId: user.id,
                        startDate: Date(),
                        endDate: nil,
                        vehicle: vehicle,
                        user: user
                    )
                    modelContext.insert(assignment)
                }
            }
            
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save technician: \(error.localizedDescription)"
        }
    }
    
    // Sync vendors from ServiceTitan
    func syncVendors(completion: @escaping (Bool) -> Void) {
        guard modelContext != nil else {
            errorMessage = "Model context not available"
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // In a real implementation, this would call the ServiceTitan API
        // For demonstration, we'll simulate fetching vendors
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Simulate vendors from ServiceTitan - using AppVendor constructor
                          self.vendors = [
                  AppVendor(id: "1", name: "ABC Supply Co.", email: "orders@abcsupply.com", phone: "555-111-2222", isActive: true, serviceTitanId: "ST-V1001"),
                  AppVendor(id: "2", name: "XYZ Parts Inc.", email: "sales@xyzparts.com", phone: "555-333-4444", isActive: true, serviceTitanId: "ST-V1002"),
                  AppVendor(id: "3", name: "Midwest Auto Parts", email: "orders@midwestauto.com", phone: "555-555-6666", isActive: true, serviceTitanId: "ST-V1003"),
                  AppVendor(id: "4", name: "Quality Tools & Supply", email: "info@qualitytools.com", phone: "555-777-8888", isActive: true, serviceTitanId: "ST-V1004"),
                  AppVendor(id: "5", name: "Premier Equipment", email: "sales@premierequip.com", phone: "555-999-0000", isActive: false, serviceTitanId: "ST-V1005")
            ]
            
            self.isLoading = false
            completion(true)
        }
    }
    
    // Sync jobs for a specific technician from ServiceTitan
    func syncJobsForTechnician(techId: String, completion: @escaping (Bool) -> Void) {
        guard modelContext != nil else {
            errorMessage = "Model context not available"
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // In a real implementation, this would call the ServiceTitan API
        // For demonstration, we'll simulate fetching jobs for today
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Current date for job simulation
            let today = Date()
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            
            // Simulate jobs from ServiceTitan
            self.jobs = [
                ServiceTitanJob(
                    id: "J1001",
                    jobNumber: "ST-10045678",
                    customerName: "Johnson Residence",
                    address: "123 Main St",
                    scheduledDate: today,
                    status: "In Progress",
                    jobDescription: "HVAC System Maintenance",
                    serviceTitanId: "ST-JOB-10045678"
                ),
                ServiceTitanJob(
                    id: "J1002",
                    jobNumber: "ST-10045679",
                    customerName: "Smith Commercial Building",
                    address: "456 Business Ave",
                    scheduledDate: today,
                    status: "Scheduled",
                    jobDescription: "Commercial Refrigeration Repair",
                    serviceTitanId: "ST-JOB-10045679"
                ),
                ServiceTitanJob(
                    id: "J1003",
                    jobNumber: "ST-10045680",
                    customerName: "Davis Family",
                    address: "789 Residential Blvd",
                    scheduledDate: today,
                    status: "Scheduled",
                    jobDescription: "Plumbing Installation",
                    serviceTitanId: "ST-JOB-10045680"
                )
            ]
            
            self.isLoading = false
            completion(true)
        }
    }
}

// ServiceTitan Job model
struct ServiceTitanJob: Identifiable, Codable {
    var id: String
    var jobNumber: String
    var customerName: String
    var address: String
    var scheduledDate: Date
    var status: String
    var jobDescription: String
    var serviceTitanId: String
    
    // Format job number and description for display
    var displayName: String {
        return "\(jobNumber) - \(customerName)"
    }
    
    var displayDescription: String {
        return "\(jobDescription) at \(address)"
    }
}

// View for syncing and assigning technicians
struct ServiceTitanTechnicianSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var syncManager: ServiceTitanSyncManager
    @State private var showingConfirmation = false
    @State private var selectedTechnicians: Set<String> = []
    @State private var technicianVehicles: [String: [String]] = [:] // Map tech ID to vehicle IDs
    
    init(service: ServiceTitanService) {
        self._syncManager = StateObject(wrappedValue: ServiceTitanSyncManager(service: service))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if syncManager.isLoading {
                    ProgressView("Syncing with ServiceTitan...")
                        .padding()
                } else if let error = syncManager.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Retry") {
                            syncTechnicians()
                        }
                        .padding()
                    }
                } else if syncManager.technicians.isEmpty {
                    VStack {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .padding()
                        
                        Text("Sync technicians from ServiceTitan")
                            .font(.headline)
                            .padding()
                        
                        Text("Downloading technicians will allow you to assign them to vehicles and track their work.")
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Start Sync") {
                            syncTechnicians()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                    }
                } else {
                    List {
                        Section(header: Text("Select Technicians to Import")) {
                            ForEach(syncManager.technicians.filter { $0.isActive }) { tech in
                                TechnicianRow(
                                    technician: tech,
                                    isSelected: selectedTechnicians.contains(tech.id),
                                    vehicles: syncManager.vehicles,
                                    selectedVehicles: Binding(
                                        get: { technicianVehicles[tech.id] ?? [] },
                                        set: { technicianVehicles[tech.id] = $0 }
                                    ),
                                    toggleSelection: {
                                        toggleTechnicianSelection(tech.id)
                                    }
                                )
                            }
                        }
                        
                        Section(header: Text("Inactive Technicians")) {
                            ForEach(syncManager.technicians.filter { !$0.isActive }) { tech in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(tech.name)
                                            .foregroundColor(.secondary)
                                        Text(tech.email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("Inactive")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .contentShape(Rectangle())
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Technician Sync")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    showingConfirmation = true
                }
                .disabled(selectedTechnicians.isEmpty)
            )
            .alert(isPresented: $showingConfirmation) {
                Alert(
                    title: Text("Confirm Import"),
                    message: Text("Import \(selectedTechnicians.count) technicians and assign them to the selected vehicles?"),
                    primaryButton: .default(Text("Import")) {
                        saveTechnicians()
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                syncManager.setModelContext(modelContext)
            }
        }
    }
    
    private func syncTechnicians() {
        syncManager.syncTechnicians { success in
            if success {
                // Pre-select all active technicians
                selectedTechnicians = Set(syncManager.technicians.filter { $0.isActive }.map { $0.id })
            }
        }
    }
    
    private func toggleTechnicianSelection(_ techId: String) {
        if selectedTechnicians.contains(techId) {
            selectedTechnicians.remove(techId)
        } else {
            selectedTechnicians.insert(techId)
        }
    }
    
    private func saveTechnicians() {
        // Process each selected technician
        for techId in selectedTechnicians {
            if let technician = syncManager.technicians.first(where: { $0.id == techId }) {
                syncManager.saveTechnician(technician, assignedVehicleIds: technicianVehicles[techId] ?? [])
            }
        }
        
        // Dismiss the view
        dismiss()
    }
}

// Technician row with vehicle selection
struct TechnicianRow: View {
    let technician: ServiceTitanTechnician
    let isSelected: Bool
    let vehicles: [AppVehicle]
    @Binding var selectedVehicles: [String]
    let toggleSelection: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            HStack {
                Button(action: toggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                
                VStack(alignment: .leading) {
                    Text(technician.name)
                        .font(.headline)
                    Text(technician.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .disabled(!isSelected)
                .opacity(isSelected ? 1.0 : 0.5)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleSelection()
            }
            
            if isSelected && isExpanded {
                Divider()
                
                VStack(alignment: .leading) {
                    Text("Assign Vehicles:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    ForEach(vehicles) { vehicle in
                        VehicleSelectionRow(
                            vehicle: vehicle,
                            isSelected: selectedVehicles.contains(vehicle.id),
                            toggle: {
                                toggleVehicleSelection(vehicle.id)
                            }
                        )
                    }
                }
                .padding(.leading)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func toggleVehicleSelection(_ vehicleId: String) {
        if selectedVehicles.contains(vehicleId) {
            selectedVehicles.removeAll { $0 == vehicleId }
        } else {
            selectedVehicles.append(vehicleId)
        }
    }
}

// Vehicle selection row
struct VehicleSelectionRow: View {
    let vehicle: AppVehicle
    let isSelected: Bool
    let toggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: toggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            
            Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                .font(.subheadline)
            
            Spacer()
            
            if let plate = vehicle.licensePlate {
                Text(plate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggle()
        }
        .padding(.vertical, 2)
    }
} 