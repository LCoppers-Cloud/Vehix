import SwiftUI
import SwiftData
import MessageUI

struct TechnicianManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    
    @Query private var technicians: [AuthUser]
    @State private var showingInviteForm = false
    @State private var showingUpgradePrompt = false
    @State private var technicianToRemove: AuthUser?
    @State private var showingRemoveConfirmation = false
    
    var activeTechnicians: [AuthUser] {
        technicians.filter { $0.userRole == .technician }
    }
    
    var pendingInvites: [AuthUser] {
        // For now, return empty array since we don't have pending invite tracking
        []
    }
    
    var technicianSlotsUsed: Int {
        activeTechnicians.count + pendingInvites.count
    }
    
    var technicianSlotsRemaining: Int {
        max(0, storeKitManager.technicianLimit - technicianSlotsUsed)
    }
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Manage Technicians")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showingInviteForm) {
                    InviteTechnicianView()
                }
                .alert("Upgrade Required", isPresented: $showingUpgradePrompt) {
                    Button("View Plans") {
                        // Navigate to subscription management
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("You've reached your plan's technician limit (\(storeKitManager.technicianLimit)). Upgrade to invite more technicians.")
                }
                .alert("Remove Technician", isPresented: $showingRemoveConfirmation) {
                    Button("Cancel", role: .cancel) {
                        technicianToRemove = nil
                    }
                    Button("Remove", role: .destructive) {
                        if let technician = technicianToRemove {
                            removeTechnician(technician)
                            technicianToRemove = nil
                        }
                    }
                } message: {
                    if let technician = technicianToRemove {
                        Text("Are you sure you want to remove \(technician.fullName ?? technician.email)? They will lose access to the system.")
                    }
                }
        }
    }
    
    private var contentView: some View {
        List {
            subscriptionStatusSection
            
            if activeTechnicians.isEmpty && pendingInvites.isEmpty {
                emptyStateSection
            } else {
                if !activeTechnicians.isEmpty {
                    activeTechniciansSection
                }
                
                if !pendingInvites.isEmpty {
                    pendingInvitesSection
                }
            }
            
            inviteNewTechnicianSection
            helpSection
        }
    }
    
    private var emptyStateSection: some View {
        Section {
            // Use the new comprehensive empty state view
            EmptyTechnicianStateView(showingTechnicianInvite: $showingInviteForm)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        }
    }
    
    private var subscriptionStatusSection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Technician Slots")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("\(technicianSlotsUsed) of \(storeKitManager.technicianLimit) used")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(technicianSlotsRemaining)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(technicianSlotsRemaining > 0 ? .green : .red)
                        
                        Text("remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                ProgressView(value: Double(technicianSlotsUsed), total: Double(storeKitManager.technicianLimit))
                    .progressViewStyle(LinearProgressViewStyle(tint: technicianSlotsUsed < storeKitManager.technicianLimit ? .blue : .red))
                
                HStack {
                    Text("Current Plan: \(storeKitManager.currentPlanName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if technicianSlotsRemaining == 0 {
                        Button("Upgrade Plan") {
                            showingUpgradePrompt = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var activeTechniciansSection: some View {
        Section("Active Technicians (\(activeTechnicians.count))") {
            ForEach(activeTechnicians) { technician in
                TechnicianManagementRow(
                    technician: technician,
                    status: .active,
                    onRemove: {
                        technicianToRemove = technician
                        showingRemoveConfirmation = true
                    }
                )
            }
        }
    }
    
    private var pendingInvitesSection: some View {
        Section("Pending Invites (\(pendingInvites.count))") {
            ForEach(pendingInvites) { technician in
                TechnicianManagementRow(
                    technician: technician,
                    status: .pending,
                    onRemove: {
                        technicianToRemove = technician
                        showingRemoveConfirmation = true
                    }
                )
            }
        }
    }
    
    private var inviteNewTechnicianSection: some View {
        Section {
            Button(action: {
                if technicianSlotsRemaining > 0 {
                    showingInviteForm = true
                } else {
                    showingUpgradePrompt = true
                }
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(technicianSlotsRemaining > 0 ? .blue : .gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite New Technician")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(technicianSlotsRemaining > 0 ? .primary : .gray)
                        
                        if technicianSlotsRemaining > 0 {
                            Text("Send an invitation to join your team")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Upgrade your plan to invite more technicians")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(technicianSlotsRemaining == 0)
            .buttonStyle(.plain)
        }
    }
    
    private var helpSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("About Technician Management")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    HelpRow(
                        icon: "envelope.fill",
                        title: "Email Invitations",
                        description: "Technicians receive an email invitation to join your team"
                    )
                    
                    HelpRow(
                        icon: "car.fill",
                        title: "Vehicle Assignment",
                        description: "Assign technicians to specific vehicles for inventory management"
                    )
                    
                    HelpRow(
                        icon: "cube.box.fill",
                        title: "Inventory Access",
                        description: "Technicians can manage inventory on their assigned vehicles"
                    )
                    
                    HelpRow(
                        icon: "wrench.and.screwdriver.fill",
                        title: "Service Records",
                        description: "Track maintenance and service work completed by each technician"
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func removeTechnician(_ technician: AuthUser) {
        modelContext.delete(technician)
        
        do {
            try modelContext.save()
        } catch {
            print("Error removing technician: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct TechnicianManagementRow: View {
    let technician: AuthUser
    let status: TechnicianStatus
    let onRemove: () -> Void
    
    enum TechnicianStatus {
        case active
        case pending
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(technician.fullName ?? technician.email)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(technician.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: status == .active ? "checkmark.circle.fill" : "clock.fill")
                        .font(.caption)
                        .foregroundColor(status == .active ? .green : .orange)
                    
                    Text(status == .active ? "Active" : "Pending")
                        .font(.caption)
                        .foregroundColor(status == .active ? .green : .orange)
                }
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

struct HelpRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Invite Technician View

struct InviteTechnicianView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AppAuthService
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var notes = ""
    @State private var isInviting = false
    @State private var inviteError: String?
    
    var isFormValid: Bool {
        !fullName.isEmpty && !email.isEmpty && email.contains("@")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Technician Information") {
                    TextField("Full Name*", text: $fullName)
                        .autocapitalization(.words)
                    
                    TextField("Email Address*", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("Additional Information") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invitation Process")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. An email invitation will be sent to the technician")
                            Text("2. They'll receive instructions to download the Vehix app")
                            Text("3. Once they accept, they'll appear in your active technicians list")
                            Text("4. You can then assign them to vehicles and inventory")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Invite Technician")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send Invite") {
                        sendInvitation()
                    }
                    .disabled(!isFormValid || isInviting)
                }
            }
            .alert("Invitation Error", isPresented: .constant(inviteError != nil)) {
                Button("OK") {
                    inviteError = nil
                }
            } message: {
                if let error = inviteError {
                    Text(error)
                }
            }
        }
    }
    
    private func sendInvitation() {
        isInviting = true
        
        // Create pending technician record using the correct AuthUser initializer
        let newTechnician = AuthUser(
            id: UUID().uuidString,
            email: email,
            fullName: fullName,
            role: .technician,
            isVerified: false
        )
        
        // Insert into database
        modelContext.insert(newTechnician)
        
        do {
            try modelContext.save()
            
            // Send email invitation (placeholder)
            print("Invitation sent to \(email)")
            
            isInviting = false
            dismiss()
        } catch {
            inviteError = "Failed to save technician: \(error.localizedDescription)"
            isInviting = false
        }
    }
    
    private func generateInvitationText(for technician: AuthUser) -> String {
        let companyName = "Your Company"
        let inviterName = authService.currentUser?.fullName ?? authService.currentUser?.email ?? "Team"
        
        return """
        Hi \(technician.fullName ?? "there"),
        
        You've been invited to join \(companyName)'s team on Vehix!
        
        Vehix is our vehicle and inventory management system that will help you:
        • Manage inventory on your assigned vehicles
        • Track maintenance and service records
        • Communicate with the team
        
        To get started:
        1. Download the Vehix app from the App Store
        2. Use this email address (\(technician.email)) to sign up
        3. Your account will be automatically activated
        
        If you have any questions, please contact \(inviterName).
        
        Welcome to the team!
        """
    }
}

// MARK: - Empty State Feature Row

struct EmptyStateFeature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                                 .foregroundColor(Color.vehixBlue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    TechnicianManagementView()
        .environmentObject(AppAuthService())
        .environmentObject(StoreKitManager())
        .modelContainer(for: AuthUser.self, inMemory: true)
} 