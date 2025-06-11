import SwiftUI

// MARK: - Welcome Step View

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 32) {
            Image("Vehix Light") // Adjust based on your asset name
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
            
            VStack(spacing: 16) {
                Text("Welcome to Vehix")
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.vehixText)
                    .multilineTextAlignment(.center)
                
                Text("Let's set up your business account in just a few minutes")
                    .font(.title2)
                    .foregroundColor(Color.vehixSecondaryText)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                OnboardingFeatureRow(icon: "building.2", title: "Business Setup", description: "Configure your company structure")
                OnboardingFeatureRow(icon: "person.3", title: "Team Management", description: "Set up managers and technicians")
                OnboardingFeatureRow(icon: "crown", title: "Subscription Plans", description: "Choose the right plan for your needs")
                OnboardingFeatureRow(icon: "shield.checkered", title: "Secure Access", description: "Role-based permissions and security")
            }
            .padding(.top)
        }
        .padding()
    }
}

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color.vehixBlue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color.vehixText)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(Color.vehixSecondaryText)
            }
            
            Spacer()
        }
    }
}

// MARK: - Business Info Step View

struct BusinessInfoStepView: View {
    @Binding var businessInfo: BusinessSetupInfo
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Business Details")
                    .font(.title2.bold())
                    .foregroundColor(Color.vehixText)
                
                Text("Tell us about your business so we can customize your experience")
                    .font(.subheadline)
                    .foregroundColor(Color.vehixSecondaryText)
            }
            
            VStack(spacing: 20) {
                OnboardingTextField(
                    title: "Business Name",
                    text: $businessInfo.businessName,
                    placeholder: "Enter your business name"
                )
                
                OnboardingTextField(
                    title: "Primary Manager Email",
                    text: $businessInfo.primaryManagerEmail,
                    placeholder: "manager@company.com"
                )
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Business Type")
                        .font(.headline)
                        .foregroundColor(Color.vehixText)
                    
                    ForEach(BusinessSetupInfo.BusinessType.allCases, id: \.self) { type in
                        BusinessTypeCard(
                            type: type,
                            isSelected: businessInfo.businessType == type
                        ) {
                            businessInfo.businessType = type
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fleet Size")
                        .font(.headline)
                        .foregroundColor(Color.vehixText)
                    
                    ForEach(BusinessSetupInfo.FleetSize.allCases, id: \.self) { size in
                        FleetSizeCard(
                            size: size,
                            isSelected: businessInfo.fleetSize == size
                        ) {
                            businessInfo.fleetSize = size
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct BusinessTypeCard: View {
    let type: BusinessSetupInfo.BusinessType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.headline)
                        .foregroundColor(Color.vehixText)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(Color.vehixSecondaryText)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.vehixBlue)
                }
            }
            .padding()
            .background(isSelected ? Color.vehixUIBlue.opacity(0.1) : Color.vehixSecondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.vehixBlue : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FleetSizeCard: View {
    let size: BusinessSetupInfo.FleetSize
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(size.rawValue)
                    .font(.headline)
                    .foregroundColor(Color.vehixText)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Recommended: \(size.recommendedPlan.name)")
                        .font(.caption)
                        .foregroundColor(Color.vehixBlue)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.vehixBlue)
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.vehixUIBlue.opacity(0.1) : Color.vehixSecondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.vehixBlue : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Team Structure Step View

struct TeamStructureStepView: View {
    @Binding var businessInfo: BusinessSetupInfo
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Team Structure")
                    .font(.title2.bold())
                    .foregroundColor(Color.vehixText)
                
                Text("How do you want to organize your team?")
                    .font(.subheadline)
                    .foregroundColor(Color.vehixSecondaryText)
            }
            
            VStack(spacing: 20) {
                ForEach(BusinessSetupInfo.ManagementStructure.allCases, id: \.self) { structure in
                    ManagementStructureCard(
                        structure: structure,
                        isSelected: businessInfo.managementStructure == structure
                    ) {
                        businessInfo.managementStructure = structure
                    }
                }
                
                if businessInfo.managementStructure != .singleManager {
                    VStack(spacing: 16) {
                        Stepper(
                            "Estimated Managers: \(businessInfo.estimatedManagerCount)",
                            value: $businessInfo.estimatedManagerCount,
                            in: 1...10
                        )
                        .foregroundColor(Color.vehixText)
                        
                        Stepper(
                            "Estimated Technicians: \(businessInfo.estimatedTechnicianCount)",
                            value: $businessInfo.estimatedTechnicianCount,
                            in: 1...50
                        )
                        .foregroundColor(Color.vehixText)
                    }
                    .padding()
                    .background(Color.vehixSecondaryBackground)
                    .cornerRadius(12)
                }
                
                VStack(spacing: 16) {
                    Text("Primary Manager Account")
                        .font(.headline)
                        .foregroundColor(Color.vehixText)
                    
                                            OnboardingTextField(
                        title: "Full Name",
                        text: $businessInfo.primaryManagerName,
                        placeholder: "Your Full Name"
                    )
                    
                    CustomSecureField(
                        title: "Password",
                        text: $businessInfo.primaryManagerPassword,
                        placeholder: "Create a secure password"
                    )
                }
            }
        }
        .padding()
    }
}

struct ManagementStructureCard: View {
    let structure: BusinessSetupInfo.ManagementStructure
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(structure.rawValue)
                        .font(.headline)
                        .foregroundColor(Color.vehixText)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.vehixBlue)
                    }
                }
                
                Text(structure.description)
                    .font(.subheadline)
                    .foregroundColor(Color.vehixSecondaryText)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(structure.limitations, id: \.self) { limitation in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(Color.vehixBlue)
                            Text(limitation)
                                .font(.caption)
                                .foregroundColor(Color.vehixSecondaryText)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.vehixUIBlue.opacity(0.1) : Color.vehixSecondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.vehixBlue : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Subscription Planning Step View

struct SubscriptionPlanningStepView: View {
    @Binding var businessInfo: BusinessSetupInfo
    @EnvironmentObject var storeKit: StoreKitManager
    
    var recommendedPlan: BusinessPlan {
        return businessInfo.fleetSize.recommendedPlan
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose Your Plan")
                    .font(.title2.bold())
                    .foregroundColor(Color.vehixText)
                
                Text("Based on your business size, we recommend the \(recommendedPlan.name) plan")
                    .font(.subheadline)
                    .foregroundColor(Color.vehixSecondaryText)
            }
            
            VStack(spacing: 16) {
                ForEach(BusinessPlan.allPlans, id: \.name) { plan in
                    SubscriptionPlanCard(
                        plan: plan,
                        isSelected: businessInfo.selectedPlan?.name == plan.name,
                        isRecommended: plan.name == recommendedPlan.name,
                        billingPeriod: businessInfo.billingPreference
                    ) {
                        businessInfo.selectedPlan = plan
                    }
                }
                
                Toggle("Yearly Billing (Save 10%)", isOn: .constant(businessInfo.billingPreference == .yearly))
                    .onChange(of: businessInfo.billingPreference) { oldValue, newValue in
                        businessInfo.billingPreference = newValue == .yearly ? .yearly : .monthly
                    }
                    .foregroundColor(Color.vehixText)
                    .padding()
                    .background(Color.vehixSecondaryBackground)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct SubscriptionPlanCard: View {
    let plan: BusinessPlan
    let isSelected: Bool
    let isRecommended: Bool
    let billingPeriod: BusinessSetupInfo.BillingPeriod
    let onTap: () -> Void
    
    private var displayPrice: String {
        if plan.name == "Enterprise" {
            return "$\(Int(plan.monthlyPrice))/vehicle/month"
        } else {
            let price = billingPeriod == .yearly ? plan.monthlyPrice * 12 * 0.9 : plan.monthlyPrice
            let period = billingPeriod == .yearly ? "year" : "month"
            return "$\(Int(price))/\(period)"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(plan.name)
                                .font(.title3.bold())
                                .foregroundColor(Color.vehixText)
                            
                            if isRecommended {
                                Text("RECOMMENDED")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.vehixBlue)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(displayPrice)
                            .font(.title2.bold())
                            .foregroundColor(Color.vehixBlue)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.vehixBlue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.features, id: \.self) { feature in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(Color.vehixGreen)
                            Text(feature)
                                .font(.caption)
                                .foregroundColor(Color.vehixSecondaryText)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.vehixUIBlue.opacity(0.1) : Color.vehixSecondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.vehixBlue : (isRecommended ? Color.vehixBlue.opacity(0.3) : .clear), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Account Creation Step View

struct AccountCreationStepView: View {
    @Binding var businessInfo: BusinessSetupInfo
    @Binding var isCreating: Bool
    @EnvironmentObject var authService: AppAuthService
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Review & Create Account")
                    .font(.title2.bold())
                    .foregroundColor(Color.vehixText)
                
                Text("Please review your setup before creating your account")
                    .font(.subheadline)
                    .foregroundColor(Color.vehixSecondaryText)
            }
            
            VStack(spacing: 20) {
                InfoSection(title: "Business Information") {
                    OnboardingInfoRow(label: "Name", value: businessInfo.businessName)
                    OnboardingInfoRow(label: "Type", value: businessInfo.businessType.rawValue)
                    OnboardingInfoRow(label: "Fleet Size", value: businessInfo.fleetSize.rawValue)
                }
                
                InfoSection(title: "Team Structure") {
                    OnboardingInfoRow(label: "Structure", value: businessInfo.managementStructure.rawValue)
                    OnboardingInfoRow(label: "Primary Manager", value: businessInfo.primaryManagerName)
                    OnboardingInfoRow(label: "Email", value: businessInfo.primaryManagerEmail)
                }
                
                if let plan = businessInfo.selectedPlan {
                    InfoSection(title: "Subscription Plan") {
                        OnboardingInfoRow(label: "Plan", value: plan.name)
                        OnboardingInfoRow(label: "Price", value: plan.name == "Enterprise" ? "$\(Int(plan.monthlyPrice))/vehicle/month" : "$\(Int(plan.monthlyPrice))/month")
                        OnboardingInfoRow(label: "Billing", value: businessInfo.billingPreference.rawValue)
                    }
                }
            }
            
            if isCreating {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Creating your business account...")
                        .font(.headline)
                        .foregroundColor(Color.vehixText)
                    
                    Text("This may take a few moments")
                        .font(.subheadline)
                        .foregroundColor(Color.vehixSecondaryText)
                }
                .padding()
                .background(Color.vehixSecondaryBackground)
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - Complete Step View

struct CompleteStepView: View {
    @Binding var businessInfo: BusinessSetupInfo
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color.vehixGreen)
            
            VStack(spacing: 16) {
                Text("Account Created Successfully!")
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.vehixText)
                    .multilineTextAlignment(.center)
                
                Text("Welcome to Vehix, \(businessInfo.primaryManagerName)!")
                    .font(.title2)
                    .foregroundColor(Color.vehixSecondaryText)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                NextStepCard(
                    icon: "graduationcap",
                    title: "Quick Walkthrough",
                    description: "Learn the basics of managing your fleet"
                )
                
                NextStepCard(
                    icon: "car",
                    title: "Add Your First Vehicle",
                    description: "Start tracking your fleet inventory"
                )
                
                NextStepCard(
                    icon: "person.badge.plus",
                    title: "Invite Technicians",
                    description: "Set up your team members"
                )
            }
            
            Text("You can always modify these settings later in the Settings tab")
                .font(.caption)
                .foregroundColor(Color.vehixSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.top)
        }
        .padding()
    }
}

struct NextStepCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color.vehixBlue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color.vehixText)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(Color.vehixSecondaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color.vehixSecondaryText)
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - Helper Views

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color.vehixText)
            
            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(Color.vehixSecondaryBackground)
            .cornerRadius(12)
        }
    }
}

struct OnboardingInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color.vehixSecondaryText)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(Color.vehixText)
        }
    }
}

struct OnboardingTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color.vehixText)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

struct CustomSecureField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color.vehixText)
            
            SecureField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
} 