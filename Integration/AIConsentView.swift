import SwiftUI
import SwiftData

/// AI Consent and Privacy Disclosure View for Legal Compliance
struct AIConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var aiDataManager: AISharedDataManager
    
    @State private var hasReadPrivacyPolicy = false
    @State private var consentToProcessing = false
    @State private var consentToLearning = false
    @State private var showingPrivacyPolicy = false
    @State private var showingDataDetails = false
    @State private var currentStep = 1
    
    private let totalSteps = 3
    
    var isConsentComplete: Bool {
        hasReadPrivacyPolicy && consentToProcessing
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        switch currentStep {
                        case 1:
                            aiOverviewStep
                        case 2:
                            privacyDetailsStep
                        case 3:
                            consentSelectionStep
                        default:
                            aiOverviewStep
                        }
                    }
                    .padding()
                }
                
                // Navigation buttons
                VStack(spacing: 12) {
                    if currentStep < totalSteps {
                        Button("Continue") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canProceedFromCurrentStep)
                    } else {
                        Button("Accept & Continue") {
                            saveConsentAndDismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isConsentComplete)
                    }
                    
                    if currentStep > 1 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Button("Not Now") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                    .font(.caption)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("AI Features")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            ExistingPrivacyPolicyView()
        }
        .sheet(isPresented: $showingDataDetails) {
            AIDataUsageDetailsView()
        }
    }
    
    // MARK: - Step 1: AI Overview
    
    private var aiOverviewStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("AI-Powered Features")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Vehix uses artificial intelligence to make your work faster and more accurate.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                AIFeatureRow(
                    icon: "doc.text.viewfinder",
                    title: "Smart Receipt Processing",
                    description: "Automatically extract vendor info and amounts from photos"
                )
                
                AIFeatureRow(
                    icon: "cube.box",
                    title: "Inventory Recognition",
                    description: "Count and identify inventory items from photos"
                )
                
                AIFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Predictive Insights",
                    description: "Get smart recommendations based on usage patterns"
                )
            }
        }
    }
    
    // MARK: - Step 2: Privacy Details
    
    private var privacyDetailsStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 16) {
                Text("Your Privacy is Protected")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("We process data securely and never share sensitive information.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                PrivacyProtectionRow(
                    icon: "checkmark.shield.fill",
                    title: "Local Processing First",
                    description: "Images analyzed on your device using Apple Vision",
                    isProtected: true
                )
                
                PrivacyProtectionRow(
                    icon: "text.viewfinder",
                    title: "Text-Only to AI",
                    description: "Only OCR text sent to OpenAI API, never images",
                    isProtected: true
                )
                
                PrivacyProtectionRow(
                    icon: "xmark.shield.fill",
                    title: "Never Shared",
                    description: "Customer info, prices, business names stay private",
                    isProtected: true
                )
            }
            
            Button("View Full Privacy Policy") {
                showingPrivacyPolicy = true
            }
            .foregroundColor(.blue)
            
            Toggle("I have read and understand the privacy policy", isOn: $hasReadPrivacyPolicy)
                .padding(.top)
        }
    }
    
    // MARK: - Step 3: Consent Selection
    
    private var consentSelectionStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            VStack(spacing: 16) {
                Text("Your Choices")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Choose what AI features you'd like to enable.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                ConsentOptionCard(
                    title: "AI Processing (Required)",
                    description: "Enable receipt scanning and inventory recognition",
                    isRequired: true,
                    isEnabled: $consentToProcessing,
                    details: "Processes your receipt photos and inventory images to extract useful information. Required for core AI features."
                )
                
                ConsentOptionCard(
                    title: "Learning Improvements (Optional)",
                    description: "Help improve AI accuracy for all users",
                    isRequired: false,
                    isEnabled: $consentToLearning,
                    details: "Shares anonymized patterns (like common vendor name variations) to improve AI for everyone. No personal data shared."
                )
            }
            
            Button("What exactly is shared?") {
                showingDataDetails = true
            }
            .foregroundColor(.blue)
            .font(.caption)
        }
    }
    
    // MARK: - Helper Views
    
    private var canProceedFromCurrentStep: Bool {
        switch currentStep {
        case 1:
            return true
        case 2:
            return hasReadPrivacyPolicy
        case 3:
            return consentToProcessing
        default:
            return false
        }
    }
    
    private func saveConsentAndDismiss() {
        // Save consent preferences
        UserDefaults.standard.set(consentToProcessing, forKey: "ai_processing_consent")
        UserDefaults.standard.set(consentToLearning, forKey: "ai_learning_consent")
        UserDefaults.standard.set(Date(), forKey: "ai_consent_date")
        
        // Update AI data manager
        aiDataManager.isContributing = consentToLearning
        
        dismiss()
    }
}

// MARK: - Supporting Views

struct AIFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PrivacyProtectionRow: View {
    let icon: String
    let title: String
    let description: String
    let isProtected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isProtected ? .green : .red)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ConsentOptionCard: View {
    let title: String
    let description: String
    let isRequired: Bool
    @Binding var isEnabled: Bool
    let details: String
    
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        
                        if isRequired {
                            Text("Required")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isEnabled)
                    .disabled(isRequired && !isEnabled)
            }
            
            if showingDetails {
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            
            Button(showingDetails ? "Hide Details" : "Show Details") {
                withAnimation {
                    showingDetails.toggle()
                }
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            if isRequired {
                isEnabled = true
            }
        }
    }
}

// MARK: - Existing Privacy Policy Reference

struct ExistingPrivacyPolicyView: View {
    var body: some View {
        PrivacyPolicyView()
    }
}

// MARK: - AI Data Usage Details View

struct AIDataUsageDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("What Data is Shared for AI Learning")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    sharedDataExample(
                        title: "Vendor Recognition Patterns",
                        original: "Home Depot Receipt with address",
                        anonymized: "Hardware Store Chain - Common Layout",
                        explanation: "Helps AI recognize receipts from similar stores without sharing your specific location or purchase details."
                    )
                    
                    sharedDataExample(
                        title: "Inventory Item Patterns",
                        original: "PVC Pipe 3/4 inch - $15.99",
                        anonymized: "Plumbing Supply - Pipe Category",
                        explanation: "Improves item categorization without sharing prices or quantities from your inventory."
                    )
                    
                    sharedDataExample(
                        title: "Receipt Layout Patterns",
                        original: "Total: $123.45 Tax: $9.88",
                        anonymized: "Standard retail format - amount patterns",
                        explanation: "Helps OCR accuracy for receipt scanning without sharing your actual amounts."
                    )
                    
                    Text("Data Usage Transparency")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("All shared data is anonymized and contributes to improving AI accuracy for the entire Vehix community. You can opt out of sharing while still using AI features, and you can see exactly what patterns have been contributed from your usage in Settings > AI & Privacy.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Data Sharing Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sharedDataExample(title: String, original: String, anonymized: String, explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Original:")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(original)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                HStack {
                    Text("Anonymized:")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(anonymized)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            Text(explanation)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: SharedVendorData.self, SharedInventoryPattern.self, SharedReceiptPattern.self,
        configurations: config
    )
    
    AIConsentView()
        .environmentObject(AISharedDataManager(modelContext: container.mainContext))
} 