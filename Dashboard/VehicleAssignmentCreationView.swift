import SwiftUI
import SwiftData

struct VehicleAssignmentCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let vehicles: [Vehix.Vehicle]
    let technicians: [AuthUser]
    
    @State private var selectedVehicleId: String?
    @State private var selectedTechnicianId: String?
    @State private var startDate = Date()
    @State private var notes = ""
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Get existing assignments to check for conflicts
    @Query private var existingAssignments: [VehicleAssignment]
    
    private var availableVehicles: [Vehix.Vehicle] {
        vehicles.filter { vehicle in
            !existingAssignments.contains { assignment in
                assignment.vehicleId == vehicle.id && assignment.endDate == nil
            }
        }
    }
    
    private var availableTechnicians: [AuthUser] {
        technicians.filter { technician in
            technician.userRole == .technician
        }
    }
    
    private var selectedVehicle: Vehix.Vehicle? {
        guard let id = selectedVehicleId else { return nil }
        return vehicles.first { $0.id == id }
    }
    
    private var selectedTechnician: AuthUser? {
        guard let id = selectedTechnicianId else { return nil }
        return technicians.first { $0.id == id }
    }
    
    private var isFormValid: Bool {
        selectedVehicleId != nil && selectedTechnicianId != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Vehicle Selection") {
                    if availableVehicles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No Available Vehicles")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("All vehicles are currently assigned. End an existing assignment first.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Picker("Select Vehicle", selection: $selectedVehicleId) {
                            Text("Choose a vehicle").tag(nil as String?)
                            ForEach(availableVehicles, id: \.id) { vehicle in
                                VStack(alignment: .leading) {
                                    Text(vehicle.displayName)
                                        .font(.headline)
                                    Text("VIN: \(vehicle.vin)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(vehicle.id as String?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        
                        if let vehicle = selectedVehicle {
                            VehiclePreviewCard(vehicle: vehicle)
                        }
                    }
                }
                
                Section("Technician Selection") {
                    if availableTechnicians.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No Technicians Available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Invite technicians to your team first.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Picker("Select Technician", selection: $selectedTechnicianId) {
                            Text("Choose a technician").tag(nil as String?)
                            ForEach(availableTechnicians, id: \.id) { technician in
                                VStack(alignment: .leading) {
                                    Text(technician.fullName ?? "Unknown")
                                        .font(.headline)
                                    Text(technician.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(technician.id as String?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        
                        if let technician = selectedTechnician {
                            TechnicianPreviewCard(technician: technician)
                        }
                    }
                }
                
                if isFormValid {
                    Section("Assignment Details") {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (Optional)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("Add any notes about this assignment...", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Assignment Summary")
                                .font(.headline)
                            
                            if let vehicle = selectedVehicle, let technician = selectedTechnician {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Vehicle:")
                                            .bold()
                                        Text(vehicle.displayName)
                                    }
                                    
                                    HStack {
                                        Text("Technician:")
                                            .bold()
                                        Text(technician.fullName ?? technician.email)
                                    }
                                    
                                    HStack {
                                        Text("Start Date:")
                                            .bold()
                                        Text(startDate, style: .date)
                                    }
                                    
                                    if !notes.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Notes:")
                                                .bold()
                                            Text(notes)
                                        }
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createAssignment()
                    }
                    .disabled(!isFormValid || isCreating || availableVehicles.isEmpty || availableTechnicians.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createAssignment() {
        guard let vehicleId = selectedVehicleId,
              let technicianId = selectedTechnicianId else {
            return
        }
        
        isCreating = true
        
        // Check for existing active assignments
        let existingVehicleAssignment = existingAssignments.first { 
            $0.vehicleId == vehicleId && $0.endDate == nil 
        }
        
        if existingVehicleAssignment != nil {
            errorMessage = "This vehicle is already assigned to another technician."
            showingError = true
            isCreating = false
            return
        }
        
        // Create new assignment
        let assignment = VehicleAssignment(
            vehicleId: vehicleId,
            userId: technicianId,
            startDate: startDate,
            vehicle: nil,
            user: nil
        )
        
        modelContext.insert(assignment)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to create assignment: \(error.localizedDescription)"
            showingError = true
        }
        
        isCreating = false
    }
}

struct VehiclePreviewCard: View {
    let vehicle: Vehix.Vehicle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.displayName)
                        .font(.subheadline)
                        .bold()
                    Text("VIN: \(vehicle.vin)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mileage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(vehicle.mileage)")
                        .font(.caption)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(vehicle.vehicleType)
                        .font(.caption)
                        .bold()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TechnicianPreviewCard: View {
    let technician: AuthUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(technician.fullName ?? "Unknown")
                        .font(.subheadline)
                        .bold()
                    Text(technician.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    VehicleAssignmentCreationView(
        vehicles: [
            Vehix.Vehicle(
                id: "1",
                make: "Ford",
                model: "Transit",
                year: 2023,
                vin: "1234567890",
                licensePlate: "TEST123"
            )
        ],
        technicians: []
    )
    .modelContainer(for: [VehicleAssignment.self], inMemory: true)
} 