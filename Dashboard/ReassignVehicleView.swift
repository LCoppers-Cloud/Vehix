import SwiftUI
import SwiftData

struct ReassignVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let vehicle: Vehix.Vehicle
    let currentAssignment: VehicleAssignment?
    let technicians: [AuthUser]
    
    @State private var selectedTechnicianId: String?
    @State private var newStartDate = Date()
    @State private var endCurrentAssignment = true
    @State private var notes = ""
    @State private var isReassigning = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Get current assignment
    @Query private var assignments: [VehicleAssignment]
    
    private var availableTechnicians: [AuthUser] {
        technicians.filter { technician in
            technician.userRole == .technician && 
            technician.id != currentAssignment?.userId
        }
    }
    
    private var selectedTechnician: AuthUser? {
        guard let id = selectedTechnicianId else { return nil }
        return technicians.first { $0.id == id }
    }
    
    private var isFormValid: Bool {
        selectedTechnicianId != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Vehicle Information") {
                    VehicleInfoCard(vehicle: vehicle)
                }
                
                Section("Current Assignment") {
                    if let assignment = currentAssignment,
                       let currentTechnician = assignment.user {
                        CurrentAssignmentCard(
                            technician: currentTechnician,
                            assignment: assignment
                        )
                    } else {
                        Text("No current assignment")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("New Assignment") {
                    if availableTechnicians.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No Available Technicians")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("All technicians are currently assigned or there are no other technicians available.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Picker("Select New Technician", selection: $selectedTechnicianId) {
                            Text("Choose a technician").tag(nil as String?)
                            ForEach(availableTechnicians, id: \.id) { technician in
                                VStack(alignment: .leading) {
                                    Text(technician.fullName ?? technician.email)
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
                            TechnicianPreviewCard(
                                technician: technician
                            )
                        }
                    }
                }
                
                if isFormValid {
                    Section("Reassignment Details") {
                        DatePicker("New Start Date", selection: $newStartDate, displayedComponents: .date)
                        
                        if currentAssignment != nil {
                            Toggle("End Current Assignment", isOn: $endCurrentAssignment)
                            
                            if endCurrentAssignment {
                                Text("The current assignment will be ended on \(newStartDate, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (Optional)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("Add any notes about this reassignment...", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reassignment Summary")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Vehicle:")
                                        .bold()
                                    Text(vehicle.displayName)
                                }
                                
                                if let currentTechnician = currentAssignment?.user {
                                    HStack {
                                        Text("From:")
                                            .bold()
                                        Text(currentTechnician.fullName ?? currentTechnician.email)
                                    }
                                }
                                
                                if let newTechnician = selectedTechnician {
                                    HStack {
                                        Text("To:")
                                            .bold()
                                        Text(newTechnician.fullName ?? newTechnician.email)
                                    }
                                }
                                
                                HStack {
                                    Text("Effective Date:")
                                        .bold()
                                    Text(newStartDate, style: .date)
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
            .navigationTitle("Reassign Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reassign") {
                        reassignVehicle()
                    }
                    .disabled(!isFormValid || isReassigning || availableTechnicians.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func reassignVehicle() {
        guard let newTechnicianId = selectedTechnicianId,
              let _ = selectedTechnician else {
            return
        }
        
        isReassigning = true
        
        // End current assignment if requested
        if let current = currentAssignment, endCurrentAssignment {
            current.endDate = newStartDate
            current.updatedAt = Date()
        }
        
        // Create new assignment
        let newAssignment = VehicleAssignment(
            vehicleId: vehicle.id,
            userId: newTechnicianId,
            startDate: newStartDate,
            vehicle: nil,
            user: nil
        )
        
        modelContext.insert(newAssignment)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to reassign vehicle: \(error.localizedDescription)"
            showingError = true
        }
        
        isReassigning = false
    }
}

struct VehicleInfoCard: View {
    let vehicle: Vehix.Vehicle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.displayName)
                        .font(.headline)
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
                        .font(.subheadline)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(vehicle.vehicleType)
                        .font(.subheadline)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("License")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(vehicle.licensePlate ?? "N/A")
                        .font(.subheadline)
                        .bold()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CurrentAssignmentCard: View {
    let technician: AuthUser
    let assignment: VehicleAssignment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(technician.fullName ?? technician.email)
                        .font(.subheadline)
                        .bold()
                    Text(technician.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Since")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(assignment.startDate, style: .date)
                        .font(.caption)
                        .bold()
                }
            }
            
            // Note: Vehix.User doesn't have phoneNumber property
            // Removed phone number display
            
            // Duration
            HStack {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(durationText)
                    .font(.caption)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var durationText: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: assignment.startDate, to: Date())
        let days = components.day ?? 0
        return "Assigned for \(days) day\(days == 1 ? "" : "s")"
    }
}

#Preview {
    ReassignVehicleView(
        vehicle: Vehix.Vehicle(),
        currentAssignment: nil,
        technicians: []
    )
    .modelContainer(for: [VehicleAssignment.self], inMemory: true)
} 