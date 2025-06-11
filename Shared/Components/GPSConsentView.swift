import SwiftUI
import SwiftData

struct GPSConsentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var gpsManager = AppleGPSTrackingManager.shared
    
    let userId: String
    let userName: String
    
    @State private var showingConsentDialog = false
    @State private var businessPurpose = ""
    @State private var selectedTrackingType = "Vehicle Safety"
    @State private var workHoursOnly = true
    @State private var hasConsent = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @Query private var consentRecords: [GPSConsentRecord]
    @Query private var workHoursConfig: [WorkHoursConfiguration]
    
    private let trackingTypes = [
        "Vehicle Safety",
        "Route Optimization", 
        "Time & Attendance Verification",
        "Emergency Response",
        "Company Asset Protection",
        "Compliance Requirements"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "location.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("GPS Tracking Setup")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Employee: \(userName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Legal Notice
                VStack(alignment: .leading, spacing: 12) {
                    Label("Legal Compliance Notice", systemImage: "exclamationmark.shield")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• GPS tracking requires explicit employee consent")
                        Text("• Tracking is limited to work hours only")
                        Text("• Must have legitimate business purpose")
                        Text("• Employee can revoke consent at any time")
                        Text("• Data is protected and secure")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                // Current Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Status")
                        .font(.headline)
                    
                    StatusRow(
                        title: "GPS Consent",
                        status: hasConsent,
                        detail: hasConsent ? "Consent granted" : "Consent required"
                    )
                    
                    StatusRow(
                        title: "Work Hours Only",
                        status: workHoursOnly,
                        detail: "6 AM - 8 PM, Monday-Friday"
                    )
                    
                    StatusRow(
                        title: "Business Purpose",
                        status: !businessPurpose.isEmpty,
                        detail: businessPurpose.isEmpty ? "Not specified" : businessPurpose
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Action Buttons
                VStack(spacing: 16) {
                    if !hasConsent {
                        Button("Request GPS Consent") {
                            showingConsentDialog = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading)
                    } else {
                        VStack(spacing: 12) {
                            Button("Modify Tracking Settings") {
                                showingConsentDialog = true
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            
                            Button("Revoke GPS Consent") {
                                revokeConsent()
                            }
                            .buttonStyle(DestructiveButtonStyle())
                        }
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("GPS Setup")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingConsentDialog) {
                ConsentRequestView(
                    businessPurpose: $businessPurpose,
                    selectedTrackingType: $selectedTrackingType,
                    workHoursOnly: $workHoursOnly,
                    trackingTypes: trackingTypes,
                    onConsent: { grantConsent() },
                    onCancel: { showingConsentDialog = false }
                )
            }
            .onAppear {
                loadConsentStatus()
            }
        }
    }
    
    private func loadConsentStatus() {
        let userConsents = consentRecords.filter { $0.userId == userId && $0.isActive }
        hasConsent = userConsents.contains { $0.hasValidConsent }
        
        if let consent = userConsents.first {
            businessPurpose = consent.businessPurpose
        }
    }
    
    private func grantConsent() {
        isLoading = true
        errorMessage = nil
        
        Task {
            let success = await gpsManager.requestGPSConsent(
                userId: userId,
                businessPurpose: businessPurpose
            )
            
            await MainActor.run {
                isLoading = false
                if success {
                    hasConsent = true
                    showingConsentDialog = false
                } else {
                    errorMessage = "Failed to grant GPS consent. Please try again."
                }
            }
        }
    }
    
    private func revokeConsent() {
        gpsManager.revokeGPSConsent()
        hasConsent = false
        businessPurpose = ""
    }
}

struct ConsentRequestView: View {
    @Binding var businessPurpose: String
    @Binding var selectedTrackingType: String
    @Binding var workHoursOnly: Bool
    
    let trackingTypes: [String]
    let onConsent: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Legal Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("GPS Tracking Consent")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Please review and confirm your consent for GPS tracking during work hours.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Tracking Purpose
                VStack(alignment: .leading, spacing: 8) {
                    Text("Business Purpose")
                        .font(.headline)
                    
                    Picker("Tracking Type", selection: $selectedTrackingType) {
                        ForEach(trackingTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedTrackingType) { _, newValue in
                        businessPurpose = newValue
                    }
                }
                
                // Work Hours Restriction
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tracking Schedule")
                        .font(.headline)
                    
                    Toggle("Work Hours Only (6 AM - 8 PM)", isOn: $workHoursOnly)
                        .disabled(true) // Always required for legal compliance
                }
                
                // Legal Agreement
                VStack(alignment: .leading, spacing: 12) {
                    Text("Employee Rights")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("✓ You can revoke consent at any time")
                        Text("✓ Tracking is limited to work hours only")
                        Text("✓ Your data is secure and protected")
                        Text("✓ Used only for stated business purpose")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    Button("I Consent to GPS Tracking") {
                        onConsent()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding()
            .navigationTitle("GPS Consent")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct StatusRow: View {
    let title: String
    let status: Bool
    let detail: String
    
    var body: some View {
        HStack {
            Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(status ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.blue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    GPSConsentView(userId: UUID().uuidString, userName: "Preview User")
} 