import SwiftUI

// MARK: - Security & Privacy Step View

struct SecurityStepView: View {
    @Binding var securityInfo: SecuritySetupInfo
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading) {
                        Text("Your Data is Secure")
                            .font(.title2.bold())
                            .foregroundColor(Color.vehixText)
                        
                        Text("Enterprise-grade security for your business")
                            .font(.subheadline)
                            .foregroundColor(Color.vehixSecondaryText)
                    }
                }
            }
            
            VStack(spacing: 20) {
                SecurityFeatureCard(
                    icon: "icloud.fill",
                    title: "Private iCloud Sync",
                    description: "Your data syncs securely through your personal iCloud account. Only you and your team can access it.",
                    accentColor: .blue
                )
                
                SecurityFeatureCard(
                    icon: "lock.rotation",
                    title: "End-to-End Encryption",
                    description: "All data is encrypted on your device and in transit. We can't read your business information.",
                    accentColor: .green
                )
                
                SecurityFeatureCard(
                    icon: "person.3.sequence.fill",
                    title: "Role-Based Access",
                    description: "Control what each team member can see and do. Admins, managers, and technicians have different permissions.",
                    accentColor: .orange
                )
                
                SecurityFeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "AI Privacy",
                    description: "Optional anonymous patterns help improve AI for everyone while keeping your data completely private.",
                    accentColor: .purple
                )
            }
            
            VStack(spacing: 16) {
                Toggle("Enable AI Learning (Recommended)", isOn: $securityInfo.enableAILearning)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                if securityInfo.enableAILearning {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's Shared:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Anonymized vendor patterns")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Item categories (no prices)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("NO personal or business data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("100% Private Business Data")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Text("Your customer information, pricing, locations, and all business-sensitive data stays completely private and secure on your devices.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.green.opacity(0.08))
            .cornerRadius(12)
        }
        .padding()
    }
}

struct SecurityFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color.vehixText)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color.vehixSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(accentColor.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Security Setup Info Model

struct SecuritySetupInfo {
    var enableAILearning: Bool = true
    var enableCloudSync: Bool = true
    var enableTwoFactor: Bool = false
    
    var isValid: Bool {
        return true // Always valid since all are optional
    }
}

#Preview {
    SecurityStepView(securityInfo: .constant(SecuritySetupInfo()))
} 