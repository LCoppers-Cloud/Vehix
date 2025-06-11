import SwiftUI

struct PrivacyConsentView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    @State private var shareInventory: Bool = true
    @State private var sharePrices: Bool = false
    @State private var shareUsageData: Bool = false
    @State private var shareLocations: Bool = false
    @State private var expanded = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Privacy policy header
                    Text("Privacy & Data Sharing")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    // Privacy explanation
                    Text("Vehix respects your privacy while offering powerful community features. Please review how we handle shared data:")
                        .font(.body)
                    
                    // Privacy policy text
                    VStack(alignment: .leading, spacing: 15) {
                        DisclosureGroup(
                            isExpanded: $expanded,
                            content: {
                                Text(CloudKitPrivacyManager.shared.privacyPolicyText)
                                    .font(.body)
                                    .padding(.vertical)
                            },
                            label: {
                                HStack {
                                    Text("Read Full Privacy Policy")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                }
                            }
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    
                    // Data sharing options
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Data Sharing Options")
                            .font(.headline)
                            .padding(.top)
                        
                        Toggle("Share Inventory Catalog", isOn: $shareInventory)
                            .onChange(of: shareInventory) { _, newValue in
                                if !newValue {
                                    // Disable sub-options if sharing is disabled
                                    sharePrices = false
                                    shareUsageData = false
                                    shareLocations = false
                                }
                            }
                        
                        if shareInventory {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("Include Pricing Information", isOn: $sharePrices)
                                    .padding(.leading)
                                
                                Text("Helps other users estimate costs (anonymized)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 32)
                                
                                Toggle("Include Usage Statistics", isOn: $shareUsageData)
                                    .padding(.leading)
                                
                                Text("Improves inventory recommendations (anonymized)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 32)
                                
                                Toggle("Include Service Location Data", isOn: $shareLocations)
                                    .padding(.leading)
                                
                                Text("Helps identify regional part preferences (anonymized)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 32)
                            }
                        }
                    }
                    
                    // Benefits of sharing
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Benefits of Sharing")
                            .font(.headline)
                            .padding(.top)
                        
                        benefitRow(icon: "magnifyingglass", text: "Access to thousands of pre-configured parts")
                        benefitRow(icon: "clock", text: "Save time on data entry")
                        benefitRow(icon: "chart.bar", text: "Receive better inventory recommendations")
                        benefitRow(icon: "person.3", text: "Contribute to the Vehix community")
                    }
                    
                    // Privacy assurance
                    HStack {
                        Image(systemName: "shield.fill")
                            .foregroundColor(.green)
                        
                        Text("All shared data is anonymized. No personal information is ever shared.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    
                    // Action buttons
                    HStack {
                        Button(action: {
                            // Decline all sharing
                            CloudKitPrivacyManager.shared.setUserConsent(
                                consent: false
                            )
                            // CloudKit is now automatically configured
                            dismiss()
                        }) {
                            Text("Decline")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            // Save sharing preferences
                            CloudKitPrivacyManager.shared.setUserConsent(
                                consent: shareInventory,
                                shareInventory: shareInventory,
                                sharePrices: sharePrices,
                                shareUsageData: shareUsageData,
                                shareLocations: shareLocations
                            )
                            // CloudKit is now automatically configured
                            dismiss()
                        }) {
                            Text("Accept")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Data Sharing Consent")
            .navigationBarItems(trailing: Button("Close") {
                dismiss()
            })
        }
    }
    
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .frame(width: 20, height: 20)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.body)
            
            Spacer()
        }
    }
}

#Preview {
    PrivacyConsentView()
        .environmentObject(CloudKitManager())
} 