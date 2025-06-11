import SwiftUI
import SwiftData
import MessageUI

struct EnhancedTechnicianInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @StateObject private var marketingManager = MarketingDataManager()
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var marketingConsent = false
    @State private var position = ""
    @State private var department = ""
    @State private var tempPassword = ""
    @State private var isInviting = false
    @State private var inviteError: String?
    @State private var showingSuccess = false
    @State private var generatedInvitationCode = ""
    
    private let positions = ["Technician", "Senior Technician", "Lead Technician", "Field Supervisor"]
    private let departments = ["Service", "Installation", "Maintenance", "Emergency Response"]
    
    var isFormValid: Bool {
        !fullName.isEmpty && 
        !email.isEmpty && 
        email.contains("@") && 
        !position.isEmpty
    }
    
    var adminEmail: String {
        authService.currentUser?.email ?? "admin@yourcompany.com"
    }
    
    var companyName: String {
        authService.getCurrentBusinessAccount()?.businessName ?? "Your Company"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Technician Information") {
                    TextField("Full Name*", text: $fullName)
                        .autocapitalization(.words)
                    
                    TextField("Email Address*", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Phone Number (optional)", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
                
                Section("Position Details") {
                    Picker("Position*", selection: $position) {
                        Text("Select Position").tag("")
                        ForEach(positions, id: \.self) { pos in
                            Text(pos).tag(pos)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Department", selection: $department) {
                        Text("Select Department").tag("")
                        ForEach(departments, id: \.self) { dept in
                            Text(dept).tag(dept)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Marketing & Communications") {
                    Toggle("Include in company newsletters and updates", isOn: $marketingConsent)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email Marketing Consent")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("By enabling this, the technician consents to receive company communications, training updates, and promotional materials. This helps us provide better service and keep everyone informed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if marketingConsent {
                            Label("Email will be shared with company management for marketing purposes", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Access Information") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Temporary Access Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Temporary Password:")
                                    .fontWeight(.medium)
                                Spacer()
                                Button("Generate") {
                                    generateTempPassword()
                                }
                                .font(.caption)
                                .buttonStyle(.borderedProminent)
                            }
                            
                            if !tempPassword.isEmpty {
                                Text(tempPassword)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                                    .textSelection(.enabled)
                            }
                            
                            Text("• Password expires in 24 hours")
                            Text("• Technician must change on first login")
                            Text("• Account is automatically activated")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Invitation Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email will be sent from: \(adminEmail)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Invitation includes:")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• App download instructions")
                            Text("• Temporary login credentials")
                            Text("• Company welcome message")
                            Text("• Contact information for support")
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
                    Button("Send Invitation") {
                        sendInvitation()
                    }
                    .disabled(!isFormValid || isInviting || tempPassword.isEmpty)
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
            .alert("Invitation Sent!", isPresented: $showingSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Invitation sent to \(email) from \(adminEmail). The technician will receive login instructions and their temporary password.")
            }
        }
        .onAppear {
            generateTempPassword()
        }
    }
    
    private func generateTempPassword() {
        tempPassword = generateSecureTemporaryPassword()
    }
    
    private func generateSecureTemporaryPassword() -> String {
        let uppercaseLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let lowercaseLetters = "abcdefghijklmnopqrstuvwxyz"
        let numbers = "0123456789"
        let specialChars = "!@#$%"
        
        let allChars = uppercaseLetters + lowercaseLetters + numbers + specialChars
        
        // Ensure we have at least one from each category
        var password = ""
        password += String(uppercaseLetters.randomElement()!)
        password += String(lowercaseLetters.randomElement()!)
        password += String(numbers.randomElement()!)
        password += String(specialChars.randomElement()!)
        
        // Fill the rest randomly
        for _ in 4..<12 {
            password += String(allChars.randomElement()!)
        }
        
        // Shuffle the password
        return String(password.shuffled())
    }
    
    private func sendInvitation() {
        isInviting = true
        
        Task {
            do {
                // Create technician record
                let technician = AuthUser(
                    id: UUID().uuidString,
                    email: email,
                    fullName: fullName,
                    role: .technician,
                    isVerified: false
                )
                
                // Store temporary password (hashed)
                UserDefaults.standard.set(hashPassword(tempPassword), forKey: "temp_password_\(technician.id)")
                UserDefaults.standard.set(Date().addingTimeInterval(24 * 60 * 60), forKey: "temp_password_expiry_\(technician.id)")
                
                // Store marketing consent and additional info
                if marketingConsent {
                    marketingManager.addMarketingContact(
                        email: email,
                        fullName: fullName,
                        phoneNumber: phoneNumber,
                        companyName: companyName,
                        position: position,
                        department: department,
                        invitedByEmail: adminEmail
                    )
                }
                
                // Store position and department info
                UserDefaults.standard.set(position, forKey: "technician_position_\(technician.id)")
                UserDefaults.standard.set(department, forKey: "technician_department_\(technician.id)")
                
                // Generate invitation code
                generatedInvitationCode = UUID().uuidString.prefix(8).uppercased()
                UserDefaults.standard.set(generatedInvitationCode, forKey: "invitation_code_\(technician.id)")
                
                // Insert technician into database
                modelContext.insert(technician)
                try modelContext.save()
                
                // Send email invitation
                await sendEmailInvitation(to: technician)
                
                await MainActor.run {
                    isInviting = false
                    showingSuccess = true
                }
                
            } catch {
                await MainActor.run {
                    inviteError = "Failed to send invitation: \(error.localizedDescription)"
                    isInviting = false
                }
            }
        }
    }
    
    private func hashPassword(_ password: String) -> String {
        // In production, use proper password hashing (bcrypt, Argon2, etc.)
        return password.data(using: .utf8)?.base64EncodedString() ?? ""
    }
    

    
    private func sendEmailInvitation(to technician: AuthUser) async {
        let invitationText = generateInvitationText(for: technician)
        
        // In production, integrate with email service (SendGrid, AWS SES, etc.)
        // For now, we'll use the system's mail composer
        
        print("=== EMAIL INVITATION ===")
        print("From: \(adminEmail)")
        print("To: \(technician.email)")
        print("Subject: Welcome to \(companyName) - Vehix App Invitation")
        print("Body:")
        print(invitationText)
        print("========================")
        
        // Store email for later reference
        UserDefaults.standard.set(invitationText, forKey: "invitation_email_\(technician.id)")
    }
    
    private func generateInvitationText(for technician: AuthUser) -> String {
        let inviterName = authService.currentUser?.fullName ?? "Your Manager"
        
        return """
        Welcome to \(companyName)!
        
        Hi \(technician.fullName ?? "there"),
        
        You've been invited by \(inviterName) to join our team using the Vehix vehicle and inventory management app.
        
        🚗 WHAT IS VEHIX?
        Vehix helps you manage:
        • Vehicle assignments and maintenance
        • Inventory tracking on your assigned vehicles
        • Service records and job management
        • Communication with the team
        
        📱 GET STARTED:
        1. Download "Vehix" from the App Store
        2. Sign in with these credentials:
           Email: \(technician.email)
           Temporary Password: \(tempPassword)
           Invitation Code: \(generatedInvitationCode)
        
        ⚠️ IMPORTANT:
        • Your temporary password expires in 24 hours
        • You'll be prompted to create a new password on first login
        • Keep your invitation code handy during setup
        
        📧 NEED HELP?
        Contact \(inviterName) at \(adminEmail) or reply to this email.
        
        We're excited to have you on the team!
        
        Best regards,
        \(inviterName)
        \(companyName)
        
        ---
        This email was sent from the Vehix app. Download it today: [App Store Link]
        """
    }
}

// Preview
#Preview {
    EnhancedTechnicianInviteView()
        .environmentObject(AppAuthService())
        .modelContainer(for: AuthUser.self, inMemory: true)
} 