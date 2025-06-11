import SwiftUI

struct BusinessOnboardingFlow: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKit: StoreKitManager
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var businessInfo = BusinessSetupInfo()
    @State private var isCreatingAccount = false
    @State private var showingWalkthrough = false
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case businessInfo = 1
        case teamStructure = 2
        case subscriptionPlanning = 3
        case accountCreation = 4
        case complete = 5
        
        var title: String {
            switch self {
            case .welcome: return "Welcome to Vehix"
            case .businessInfo: return "Tell Us About Your Business"
            case .teamStructure: return "Team Structure"
            case .subscriptionPlanning: return "Choose Your Plan"
            case .accountCreation: return "Create Your Account"
            case .complete: return "Setup Complete"
            }
        }
        
        var progress: Double {
            return Double(self.rawValue) / Double(OnboardingStep.allCases.count - 1)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Main content
                ScrollView {
                    VStack(spacing: 24) {
                        stepContent
                    }
                    .padding()
                }
                
                // Navigation buttons
                navigationButtons
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingWalkthrough) {
            AppWalkthroughView()
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 12) {
            HStack {
                Text(currentStep.title)
                    .font(.title2.bold())
                    .foregroundColor(Color.vehixText)
                
                Spacer()
                
                Text("Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.caption)
                    .foregroundColor(Color.vehixSecondaryText)
            }
            
            ProgressView(value: currentStep.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.vehixBlue))
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            WelcomeStepView()
        case .businessInfo:
            BusinessInfoStepView(businessInfo: $businessInfo)
        case .teamStructure:
            TeamStructureStepView(businessInfo: $businessInfo)
        case .subscriptionPlanning:
            SubscriptionPlanningStepView(businessInfo: $businessInfo)
                .environmentObject(storeKit)
        case .accountCreation:
            AccountCreationStepView(businessInfo: $businessInfo, isCreating: $isCreatingAccount)
                .environmentObject(authService)
        case .complete:
            CompleteStepView(businessInfo: $businessInfo)
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            if currentStep != .welcome {
                Button("Back") {
                    withAnimation {
                        currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .welcome
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            Button(nextButtonTitle) {
                handleNextButton()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCurrentStepComplete ? false : true)
            .opacity(isCurrentStepComplete ? 1.0 : 0.6)
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
    }
    
    private var nextButtonTitle: String {
        switch currentStep {
        case .welcome: return "Get Started"
        case .businessInfo: return "Continue"
        case .teamStructure: return "Continue"
        case .subscriptionPlanning: return "Create Account"
        case .accountCreation: return isCreatingAccount ? "Creating..." : "Finish Setup"
        case .complete: return "Start Using Vehix"
        }
    }
    
    private var isCurrentStepComplete: Bool {
        switch currentStep {
        case .welcome: return true
        case .businessInfo: return businessInfo.isBusinessInfoComplete
        case .teamStructure: return businessInfo.isTeamStructureComplete
        case .subscriptionPlanning: return businessInfo.selectedPlan != nil
        case .accountCreation: return !isCreatingAccount
        case .complete: return true
        }
    }
    
    private func handleNextButton() {
        switch currentStep {
        case .welcome, .businessInfo, .teamStructure:
            withAnimation {
                currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .complete
            }
        case .subscriptionPlanning:
            withAnimation {
                currentStep = .accountCreation
            }
        case .accountCreation:
            createBusinessAccount()
        case .complete:
            showingWalkthrough = true
        }
    }
    
    private func createBusinessAccount() {
        isCreatingAccount = true
        
        Task {
            do {
                // Create the primary account
                try await authService.createBusinessAccount(businessInfo: businessInfo)
                
                // Update StoreKit plan
                storeKit.currentPlan = businessInfo.selectedPlan?.storeKitPlan ?? .basic
                
                await MainActor.run {
                    isCreatingAccount = false
                    withAnimation {
                        currentStep = .complete
                    }
                }
            } catch {
                await MainActor.run {
                    isCreatingAccount = false
                    // Handle error
                    print("Error creating business account: \(error)")
                }
            }
        }
    }
}

// MARK: - Business Setup Info Model

class BusinessSetupInfo: ObservableObject {
    // Business Information
    @Published var businessName: String = ""
    @Published var businessType: BusinessType = .serviceCompany
    @Published var fleetSize: FleetSize = .small
    @Published var industryType: IndustryType = .automotive
    
    // Team Structure
    @Published var managementStructure: ManagementStructure = .singleManager
    @Published var estimatedManagerCount: Int = 1
    @Published var estimatedTechnicianCount: Int = 1
    @Published var needsMultipleLocations: Bool = false
    
    // Account Setup
    @Published var primaryManagerName: String = ""
    @Published var primaryManagerEmail: String = ""
    @Published var primaryManagerPassword: String = ""
    
    // Subscription Planning
    @Published var selectedPlan: BusinessPlan? = nil
    @Published var billingPreference: BillingPeriod = .monthly
    
    var isBusinessInfoComplete: Bool {
        !businessName.isEmpty && !primaryManagerEmail.isEmpty
    }
    
    var isTeamStructureComplete: Bool {
        !primaryManagerName.isEmpty && !primaryManagerPassword.isEmpty
    }
    
    enum BusinessType: String, CaseIterable {
        case serviceCompany = "Service Company"
        case dealership = "Auto Dealership"
        case fleet = "Fleet Management"
        case rental = "Rental Company"
        case other = "Other"
        
        var description: String {
            switch self {
            case .serviceCompany: return "Mobile service, repairs, maintenance"
            case .dealership: return "New & used car sales, service"
            case .fleet: return "Company vehicle management"
            case .rental: return "Vehicle rental business"
            case .other: return "Other vehicle-related business"
            }
        }
    }
    
    enum FleetSize: String, CaseIterable {
        case small = "1-5 vehicles"
        case medium = "6-15 vehicles"
        case large = "16-50 vehicles"
        case enterprise = "50+ vehicles"
        
        var recommendedPlan: BusinessPlan {
            switch self {
            case .small: return .basic
            case .medium: return .pro
            case .large, .enterprise: return .enterprise
            }
        }
    }
    
    enum IndustryType: String, CaseIterable {
        case automotive = "Automotive"
        case hvac = "HVAC"
        case plumbing = "Plumbing"
        case electrical = "Electrical"
        case delivery = "Delivery"
        case maintenance = "Maintenance"
        case other = "Other"
    }
    
    enum ManagementStructure: String, CaseIterable {
        case singleManager = "Single Manager"
        case multipleManagers = "Multiple Managers"
        case hierarchical = "Owner + Managers"
        
        var description: String {
            switch self {
            case .singleManager: return "One person manages everything"
            case .multipleManagers: return "Multiple people with management access"
            case .hierarchical: return "Owner oversees managers"
            }
        }
        
        var limitations: [String] {
            switch self {
            case .singleManager:
                return [
                    "Single admin account controls all settings",
                    "Technicians have limited access",
                    "Can upgrade to add managers later"
                ]
            case .multipleManagers:
                return [
                    "Multiple admin accounts",
                    "Shared management responsibilities",
                    "Higher subscription tier required"
                ]
            case .hierarchical:
                return [
                    "Owner has full control",
                    "Managers have department access",
                    "Most flexible structure"
                ]
            }
        }
    }
    
    enum BillingPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly (Save 10%)"
    }
}

// MARK: - Business Plan Model

struct BusinessPlan {
    let name: String
    let monthlyPrice: Double
    let maxVehicles: Int
    let maxManagers: Int
    let maxTechnicians: Int
    let features: [String]
    let storeKitPlan: SubscriptionPlan
    
    static let basic = BusinessPlan(
        name: "Basic",
        monthlyPrice: 125,
        maxVehicles: 5,
        maxManagers: 1,
        maxTechnicians: 5,
        features: [
            "Up to 5 vehicles",
            "1 manager account",
            "5 technician accounts",
            "Basic inventory tracking",
            "Email support"
        ],
        storeKitPlan: .basic
    )
    
    static let pro = BusinessPlan(
        name: "Pro",
        monthlyPrice: 385,
        maxVehicles: 15,
        maxManagers: 4,
        maxTechnicians: 15,
        features: [
            "Up to 15 vehicles",
            "4 manager accounts + 1 owner",
            "15 technician accounts",
            "Advanced reporting",
            "Priority support",
            "Multi-location support"
        ],
        storeKitPlan: .pro
    )
    
    static let enterprise = BusinessPlan(
        name: "Enterprise",
        monthlyPrice: 50, // Per vehicle
        maxVehicles: 999,
        maxManagers: 999,
        maxTechnicians: 999,
        features: [
            "Unlimited vehicles ($50/vehicle)",
            "Unlimited managers",
            "Unlimited technicians",
            "Custom integrations",
            "Dedicated support",
            "Direct developer access"
        ],
        storeKitPlan: .enterprise
    )
    
    static let allPlans = [basic, pro, enterprise]
}

#Preview {
    BusinessOnboardingFlow()
        .environmentObject(AppAuthService())
        .environmentObject(StoreKitManager())
} 