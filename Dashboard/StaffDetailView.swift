import SwiftUI
import SwiftData

struct StaffDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    @EnvironmentObject var samsaraService: SamsaraService
    
    let staffMember: AuthUser
    
    // State for managing vehicle assignment sheet
    @State private var showingAssignVehicleSheet = false
    
    // State to hold the current vehicle assignment for this staff member
    @State private var currentAssignment: VehicleAssignment? = nil
    
    // States for tracking settings
    @State private var showingTrackingInfoSheet = false
    @State private var showingSamsaraSetupSheet = false
    @State private var showingAirTagSheet = false
    @State private var enableLocationTracking = false
    @State private var showTrackingLiabilityAlert = false
    
    @Query(sort: [SortDescriptor(\Vehix.Vehicle.createdAt, order: .reverse)]) var vehicles: [Vehix.Vehicle]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Staff member profile section
                StaffMemberProfileSection(staffMember: staffMember)
                
                // Vehicle assignment section
                VehicleAssignmentSection(
                    staffMember: staffMember,
                    currentAssignment: $currentAssignment,
                    showingAssignVehicleSheet: $showingAssignVehicleSheet
                )
                
                // Tracking options section
                TrackingOptionsSection(
                    staffMember: staffMember,
                    enableLocationTracking: $enableLocationTracking,
                    showTrackingLiabilityAlert: $showTrackingLiabilityAlert,
                    showingTrackingInfoSheet: $showingTrackingInfoSheet,
                    showingSamsaraSetupSheet: $showingSamsaraSetupSheet,
                    showingAirTagSheet: $showingAirTagSheet
                )
                
                // Password reset section
                PasswordResetSection(staffMember: staffMember)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(staffMember.fullName ?? "Staff Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAssignVehicleSheet) {
            VehicleAssignmentSheetView(
                staffMember: staffMember,
                currentAssignment: currentAssignment
            )
        }
        .sheet(isPresented: $showingTrackingInfoSheet) {
            TrackingInfoView()
        }
        .sheet(isPresented: $showingSamsaraSetupSheet) {
            SamsaraSetupView()
        }
        .sheet(isPresented: $showingAirTagSheet) {
            AirTagInfoView()
        }
        .alert("Liability Notice", isPresented: $showTrackingLiabilityAlert) {
            Button("Understand and Accept", role: .destructive) {
                enableLocationTracking = true
                
                // Update tracking preference in database
                if let assignment = currentAssignment {
                    // Save tracking preference to a related model or UserDefaults
                    // Since VehicleAssignment doesn't have requiresGPSTracking directly
                    UserDefaults.standard.set(true, forKey: "tracking_\(assignment.id)")
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {
                enableLocationTracking = false
            }
        } message: {
            Text("By enabling employee location tracking, you certify that:\n\n1. This is a company-owned device assigned to the employee\n2. The employee has been notified of tracking\n3. You have appropriate tracking policies in place\n4. You accept legal responsibility for compliance with local laws\n\nConsult legal counsel for guidance on location tracking regulations.")
        }
        .onAppear {
            loadVehicleAssignment()
        }
    }
    
    private func loadVehicleAssignment() {
        // Fetch the current vehicle assignment for this staff member
        let descriptor = FetchDescriptor<VehicleAssignment>()
        
        do {
            let assignments = try modelContext.fetch(descriptor)
            self.currentAssignment = assignments.first(where: { $0.userId == staffMember.id })
            
            // Initialize tracking toggle based on saved preference
            if let assignment = self.currentAssignment {
                self.enableLocationTracking = UserDefaults.standard.bool(forKey: "tracking_\(assignment.id)")
            }
        } catch {
            print("Error fetching vehicle assignment: \(error)")
        }
    }
}

// MARK: - Staff Member Profile Section
struct StaffMemberProfileSection: View {
    let staffMember: AuthUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(staffMember.fullName ?? "No Name")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(staffMember.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Role: \(staffMember.role.capitalized)")
                        .font(.subheadline)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(roleColor(staffMember.role).opacity(0.2))
                        .foregroundColor(roleColor(staffMember.role))
                        .cornerRadius(4)
                }
            }
            
            Divider()
        }
    }
    
    private func roleColor(_ role: String) -> Color {
        switch role.lowercased() {
        case "admin":
            return .red
        case "manager":
            return .blue
        case "technician":
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Vehicle Assignment Section
struct VehicleAssignmentSection: View {
    let staffMember: AuthUser
    @Binding var currentAssignment: VehicleAssignment?
    @Binding var showingAssignVehicleSheet: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Query var vehicles: [Vehix.Vehicle]
    
    var assignedVehicleDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let assignment = currentAssignment, 
               let vehicle = assignment.vehicle {
                HStack(spacing: 12) {
                    if let photoData = vehicle.photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "car.fill")
                            .font(.system(size: 30))
                            .frame(width: 50, height: 50)
                            .foregroundColor(.blue)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                            .font(.headline)
                        
                        Text(vehicle.licensePlate ?? "No plate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        // Unassign vehicle
                        if let assignment = currentAssignment {
                            modelContext.delete(assignment)
                            try? modelContext.save()
                            self.currentAssignment = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            } else {
                Text("No vehicle assigned")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Vehicle Assignment", systemImage: "car.fill")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingAssignVehicleSheet = true
                } label: {
                    Text("Assign Vehicle")
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            assignedVehicleDetails
            
            Divider()
        }
    }
}

// MARK: - Tracking Options Section
struct TrackingOptionsSection: View {
    let staffMember: AuthUser
    @Binding var enableLocationTracking: Bool
    @Binding var showTrackingLiabilityAlert: Bool
    @Binding var showingTrackingInfoSheet: Bool
    @Binding var showingSamsaraSetupSheet: Bool
    @Binding var showingAirTagSheet: Bool
    
    @EnvironmentObject var samsaraService: SamsaraService
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Vehicle Tracking", systemImage: "location.fill")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingTrackingInfoSheet = true
                } label: {
                    Text("Learn More")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: Binding(
                    get: { enableLocationTracking },
                    set: { newValue in
                        if newValue == true {
                            // Show liability warning before enabling
                            showTrackingLiabilityAlert = true
                        } else {
                            enableLocationTracking = false
                            // Save to database
                            if let assignment = getCurrentAssignment() {
                                UserDefaults.standard.set(false, forKey: "tracking_\(assignment.id)")
                                try? modelContext.save()
                            }
                        }
                    }
                )) {
                    Text("Require location tracking")
                        .font(.subheadline)
                }
                
                if enableLocationTracking {
                    Text("Tracking options:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 10) {
                        // Samsara GPS option
                        HStack {
                            Image(systemName: "location.circle.fill")
                                .foregroundColor(.green)
                            
                            Text("Samsara GPS Integration")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Button {
                                showingSamsaraSetupSheet = true
                            } label: {
                                Text(samsaraService.isConnected ? "Configure" : "Set Up")
                                    .font(.footnote)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        
                        // AirTag option
                        HStack {
                            Image(systemName: "airtag")
                                .foregroundColor(.blue)
                            
                            Text("Use Apple AirTag")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Button {
                                showingAirTagSheet = true
                            } label: {
                                Text("How to Setup")
                                    .font(.footnote)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.vertical, 4)
            
            Divider()
        }
    }
    
    private func getCurrentAssignment() -> VehicleAssignment? {
        let descriptor = FetchDescriptor<VehicleAssignment>()
        
        do {
            let assignments = try modelContext.fetch(descriptor)
            return assignments.first(where: { $0.userId == staffMember.id })
        } catch {
            print("Error fetching vehicle assignment: \(error)")
            return nil
        }
    }
}

// MARK: - Password Reset Section
struct PasswordResetSection: View {
    let staffMember: AuthUser
    @State private var showingPasswordResetConfirmation = false
    @State private var isResettingPassword = false
    @State private var resetSuccessful = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Account Security", systemImage: "lock.fill")
                .font(.headline)
            
            Button {
                showingPasswordResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.orange)
                    
                    Text("Send Password Reset Link")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .alert("Reset Password", isPresented: $showingPasswordResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset Password") {
                    resetPassword()
                }
            } message: {
                Text("Send a password reset link to \(staffMember.email)?")
            }
            .alert("Password Reset", isPresented: $resetSuccessful) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A password reset link has been sent to \(staffMember.email).")
            }
        }
    }
    
    private func resetPassword() {
        isResettingPassword = true
        
        // Simulate sending reset link
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            resetSuccessful = true
            isResettingPassword = false
        }
    }
}

// MARK: - Tracking Info View
struct TrackingInfoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Benefits Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Benefits of Vehicle Tracking", systemImage: "star.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        TrackingBenefitRow(
                            icon: "speedometer",
                            title: "Accurate Mileage Tracking",
                            description: "Automatically logs vehicle mileage to schedule maintenance at optimal intervals, avoiding costly repairs and downtime."
                        )
                        
                        TrackingBenefitRow(
                            icon: "wrench.and.screwdriver.fill",
                            title: "Timely Maintenance",
                            description: "Receive automatic alerts for oil changes and scheduled service based on actual vehicle usage."
                        )
                        
                        TrackingBenefitRow(
                            icon: "dollarsign.circle.fill",
                            title: "Reduced Operational Costs",
                            description: "Improve fuel efficiency by 5-15% by monitoring idle time, harsh braking and acceleration patterns."
                        )
                        
                        TrackingBenefitRow(
                            icon: "clock.fill",
                            title: "Increased Productivity",
                            description: "Optimize route planning and verify service calls to enhance team efficiency and accountability."
                        )
                        
                        TrackingBenefitRow(
                            icon: "lock.shield.fill",
                            title: "Enhanced Security",
                            description: "Recover stolen vehicles more quickly and deter theft with visible tracking systems."
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Tracking Options Comparison
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Tracking Options Compared", systemImage: "arrow.left.arrow.right")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 0) {
                            // Header Row
                            HStack {
                                Text("Feature")
                                    .font(.subheadline)
                                    .frame(width: 120, alignment: .leading)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text("Samsara")
                                    .font(.subheadline)
                                    .frame(width: 80)
                                    .fontWeight(.medium)
                                
                                Text("AirTag")
                                    .font(.subheadline)
                                    .frame(width: 80)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            
                            // Feature rows
                            ComparisonRow(feature: "Real-time tracking", samsara: true, airtag: false)
                            ComparisonRow(feature: "Location history", samsara: true, airtag: false)
                            ComparisonRow(feature: "Mileage tracking", samsara: true, airtag: false)
                            ComparisonRow(feature: "Engine diagnostics", samsara: true, airtag: false)
                            ComparisonRow(feature: "Driver behavior", samsara: true, airtag: false)
                            ComparisonRow(feature: "No monthly fee", samsara: false, airtag: true)
                            ComparisonRow(feature: "Easy setup", samsara: false, airtag: true)
                            ComparisonRow(feature: "No install required", samsara: false, airtag: true)
                        }
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Legal Considerations
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Legal Considerations", systemImage: "exclamationmark.shield.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("Before implementing any tracking solution, ensure you:")
                            .font(.subheadline)
                            .padding(.bottom, 4)
                        
                        Text("• Have written policies in place regarding vehicle tracking")
                            .font(.subheadline)
                        
                        Text("• Provide clear notification to employees about tracking")
                            .font(.subheadline)
                        
                        Text("• Only track company-owned vehicles")
                            .font(.subheadline)
                        
                        Text("• Follow local laws regarding employee monitoring")
                            .font(.subheadline)
                        
                        Text("• Consult with legal counsel to ensure compliance")
                            .font(.subheadline)
                        
                        Text("Legal requirements vary by state and jurisdiction. It's your responsibility to ensure compliance with all applicable laws and regulations.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Vehicle Tracking Benefits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // This will dismiss the sheet
                    }
                }
            }
        }
    }
}

// MARK: - Samsara Setup View
struct SamsaraSetupView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var samsaraService: SamsaraService
    
    @State private var apiKey = ""
    @State private var orgId = ""
    @State private var isEnabled = false
    @State private var syncInterval = 30
    @State private var showSuccessAlert = false
    @State private var isLoading = false
    
    let syncIntervalOptions = [5, 15, 30, 60, 120, 360, 720]
    
    func loadExistingConfig() {
        apiKey = UserDefaults.standard.string(forKey: "samsara.apiKey") ?? ""
        orgId = UserDefaults.standard.string(forKey: "samsara.orgId") ?? ""
        isEnabled = UserDefaults.standard.bool(forKey: "samsara.enabled")
        syncInterval = UserDefaults.standard.integer(forKey: "samsara.syncInterval")
        if syncInterval == 0 { syncInterval = 30 } // Default
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Samsara API Configuration")) {
                    TextField("API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    TextField("Organization ID", text: $orgId)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                Section(header: Text("Sync Settings")) {
                    Toggle("Enable Samsara Integration", isOn: $isEnabled)
                    
                    Picker("Sync Interval", selection: $syncInterval) {
                        ForEach(syncIntervalOptions, id: \.self) { minutes in
                            if minutes == 60 {
                                Text("Every Hour").tag(minutes)
                            } else if minutes > 60 {
                                Text("Every \(minutes / 60) Hours").tag(minutes)
                            } else {
                                Text("Every \(minutes) Minutes").tag(minutes)
                            }
                        }
                    }
                }
                
                Section(header: Text("Status")) {
                    HStack {
                        Text("Connection Status")
                        Spacer()
                        if samsaraService.isConnected {
                            Text("Connected")
                                .foregroundColor(.green)
                        } else {
                            Text("Disconnected")
                                .foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        if let date = samsaraService.lastSyncDate {
                            Text(date, style: .relative)
                        } else {
                            Text("Never")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button {
                        // Test the connection
                        isLoading = true
                        samsaraService.testConnection { success, error in
                            isLoading = false
                            if success {
                                saveSettings()
                                showSuccessAlert = true
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Test and Save")
                            }
                            Spacer()
                        }
                    }
                    .disabled(apiKey.isEmpty || orgId.isEmpty || isLoading)
                }
                
                Section(header: Text("Information"), footer: Text("Samsara is a third-party service that provides comprehensive vehicle tracking and fleet management solutions. A Samsara account is required for integration. Visit samsara.com for more information.")) {
                    Link("Visit Samsara Website", destination: URL(string: "https://samsara.com")!)
                }
            }
            .navigationTitle("Samsara Configuration")
            .onAppear {
                loadExistingConfig()
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Samsara configuration saved successfully.")
            }
        }
    }
    
    private func saveSettings() {
        // Save settings to UserDefaults since we don't have direct access to the SamsaraConfig
        UserDefaults.standard.set(apiKey, forKey: "samsara.apiKey") 
        UserDefaults.standard.set(orgId, forKey: "samsara.orgId")
        UserDefaults.standard.set(isEnabled, forKey: "samsara.enabled")
        UserDefaults.standard.set(syncInterval, forKey: "samsara.syncInterval")
        UserDefaults.standard.set(Date(), forKey: "samsara.updatedAt")
        
        // Reload the configuration using SamsaraService
        samsaraService.loadConfiguration()
    }
}

// MARK: - AirTag Info View
struct AirTagInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Introduction
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "airtag")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                        
                        Text("Using Apple AirTags for Vehicle Tracking")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .padding(.bottom)
                        
                        Text("AirTags provide a simple, cost-effective way to track vehicle location without monthly fees or complex installation. While they don't offer all features of dedicated GPS systems, they can be a great solution for basic fleet tracking needs.")
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Step by step guide
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Setup Instructions")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        SetupStepView(
                            number: "1",
                            title: "Purchase AirTags",
                            description: "Buy an Apple AirTag for each vehicle you want to track. They're available from Apple, Best Buy, Amazon, and other retailers for about $29 each."
                        )
                        
                        SetupStepView(
                            number: "2",
                            title: "Setup with Manager's iPhone",
                            description: "Use a manager's iPhone to set up each AirTag. This ensures all tags can be tracked from the management team's devices."
                        )
                        
                        SetupStepView(
                            number: "3",
                            title: "Name Each AirTag",
                            description: "During setup, name each AirTag with the corresponding vehicle info (e.g., '2022 Ford F-150 #103')."
                        )
                        
                        SetupStepView(
                            number: "4",
                            title: "Place in Vehicle",
                            description: "Place the AirTag in a secure, hidden location in each vehicle. Good spots include the glove compartment, center console, or under a seat."
                        )
                        
                        SetupStepView(
                            number: "5",
                            title: "Share with Authorized Staff",
                            description: "Use Apple's Family Sharing to share AirTag access with other managers who need tracking capabilities."
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Limitations
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Important Limitations")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        LimitationRow(text: "AirTags update location when near any iPhone on the Find My network, not continuously")
                        LimitationRow(text: "No real-time tracking in remote areas with few iPhone users nearby")
                        LimitationRow(text: "No speed, mileage or driving behavior tracking")
                        LimitationRow(text: "No geofencing or automated alerts")
                        LimitationRow(text: "Battery needs replacement approximately once per year")
                        LimitationRow(text: "Anti-stalking features may trigger alerts if the same driver doesn't use the vehicle regularly")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // For advanced needs
                    VStack(alignment: .leading, spacing: 12) {
                        Text("For Advanced Tracking Needs")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("If your fleet management requires more advanced features like:")
                            .font(.subheadline)
                        
                        AdvancedNeedRow(text: "Real-time continuous location updates")
                        AdvancedNeedRow(text: "Automatic mileage tracking")
                        AdvancedNeedRow(text: "Engine diagnostics and maintenance alerts")
                        AdvancedNeedRow(text: "Driver behavior monitoring")
                        AdvancedNeedRow(text: "Geofencing and route optimization")
                        
                        Text("Consider using the Samsara integration option, which provides these advanced capabilities with a monthly subscription.")
                            .font(.subheadline)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("AirTag Setup Guide")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Helper Components

struct TrackingBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ComparisonRow: View {
    let feature: String
    let samsara: Bool
    let airtag: Bool
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.caption)
                .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            Image(systemName: samsara ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(samsara ? .green : .red)
                .frame(width: 80)
            
            Image(systemName: airtag ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(airtag ? .green : .red)
                .frame(width: 80)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.white)
    }
}

struct SetupStepView: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 30, height: 30)
                
                Text(number)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct LimitationRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
            
            Text(text)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

struct AdvancedNeedRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chevron.right")
                .foregroundColor(.blue)
                .font(.caption)
            
            Text(text)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}

struct StaffDetailView_Previews: PreviewProvider {
    static var previews: some View {
        StaffDetailView(staffMember: previewUser)
            .environmentObject(AppAuthService())
            .environmentObject(StoreKitManager())
            .environmentObject(SamsaraService())
    }
    
    static var previewUser: AuthUser {
        let user = AuthUser(id: UUID().uuidString, email: "preview@icloud.com", fullName: "Preview User")
        user.userRole = .technician
        return user
    }
} 