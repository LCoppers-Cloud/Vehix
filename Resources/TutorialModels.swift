import SwiftUI

// Shared model for tutorial steps used across the app
struct TutorialStep {
    var title: String
    var description: String
    var imageName: String
    var tip: String = ""
}

// View component for tutorial steps
struct TutorialStepView: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// AppWalkthroughManager - Manages the comprehensive app walkthrough experience
class AppWalkthroughManager: ObservableObject {
    @Published var currentStep = 0
    @Published var isWalkthroughActive = false
    @Published var hasCompletedWalkthrough = false
    
    // All walkthrough sections
    let sections: [WalkthroughSection] = [
        WalkthroughSection(
            id: "welcome",
            title: "Welcome to Vehix",
            steps: [
                TutorialStep(
                    title: "Inventory Management Made Easy",
                    description: "Vehix simplifies inventory tracking for vehicles, warehouses, and technicians.",
                    imageName: "car.fill",
                    tip: "Designed specifically for service businesses with multiple vehicles and technicians."
                ),
                TutorialStep(
                    title: "Track Everything",
                    description: "Monitor inventory across vehicles and warehouses, scan barcodes, and keep records of all usage.",
                    imageName: "qrcode.viewfinder",
                    tip: "Use your camera to quickly scan barcodes for inventory tracking and lookup."
                ),
                TutorialStep(
                    title: "Smart Purchases",
                    description: "Create purchase orders, scan receipts, and connect with vendors seamlessly.",
                    imageName: "doc.text.viewfinder",
                    tip: "Our AI can extract data from receipts to save you time."
                )
            ]
        ),
        WalkthroughSection(
            id: "inventory",
            title: "Inventory Management",
            steps: [
                TutorialStep(
                    title: "Add Inventory Items",
                    description: "Create inventory items with detailed information including part numbers, categories, and pricing.",
                    imageName: "square.and.pencil",
                    tip: "Import bulk inventory via Excel spreadsheets to get started quickly."
                ),
                TutorialStep(
                    title: "Set Up Warehouses",
                    description: "Create warehouse locations to organize your central inventory storage.",
                    imageName: "building.2.fill",
                    tip: "Define minimum/maximum stock levels for automatic reordering alerts."
                ),
                TutorialStep(
                    title: "Vehicle Inventory",
                    description: "Track inventory on each vehicle to know exactly what your technicians have on hand.",
                    imageName: "car.fill",
                    tip: "Optimize what each vehicle carries based on the services they provide."
                ),
                TutorialStep(
                    title: "Barcode Scanning",
                    description: "Use the camera to scan barcodes for quick lookups and inventory transfers.",
                    imageName: "barcode.viewfinder",
                    tip: "Works with standard UPC, EAN, QR codes and more."
                )
            ]
        ),
        WalkthroughSection(
            id: "usage",
            title: "Tracking Usage",
            steps: [
                TutorialStep(
                    title: "Job-Based Usage",
                    description: "Record inventory used on specific jobs for accurate job costing.",
                    imageName: "hammer.fill",
                    tip: "Connect usage to specific service records for complete tracking."
                ),
                TutorialStep(
                    title: "Technician Accountability",
                    description: "Track which technicians are using what parts to improve accountability.",
                    imageName: "person.fill",
                    tip: "Generate usage reports by technician to identify training opportunities."
                ),
                TutorialStep(
                    title: "Automatic Stock Adjustment",
                    description: "Inventory levels update automatically when usage is recorded.",
                    imageName: "arrow.triangle.2.circlepath",
                    tip: "Real-time updates ensure you always know your current stock positions."
                )
            ]
        ),
        WalkthroughSection(
            id: "purchasing",
            title: "Purchasing System",
            steps: [
                TutorialStep(
                    title: "Create Purchase Orders",
                    description: "Generate professional purchase orders for your vendors.",
                    imageName: "doc.text.fill",
                    tip: "Templates save time when ordering frequently purchased items."
                ),
                TutorialStep(
                    title: "Receipt Scanning",
                    description: "Capture receipts with your camera and automatically extract data.",
                    imageName: "camera.fill",
                    tip: "Our OCR system recognizes vendors, amounts, and line items."
                ),
                TutorialStep(
                    title: "Approval Workflows",
                    description: "Set up approval processes for purchase orders based on amount or department.",
                    imageName: "checkmark.seal.fill",
                    tip: "Managers receive notifications when orders need approval."
                ),
                TutorialStep(
                    title: "Vendor Management",
                    description: "Maintain a database of approved vendors with contact information and terms.",
                    imageName: "building.columns.fill",
                    tip: "Track performance metrics for each vendor over time."
                )
            ]
        ),
        WalkthroughSection(
            id: "reporting",
            title: "Insights & Reporting",
            steps: [
                TutorialStep(
                    title: "Inventory Reports",
                    description: "Generate detailed reports on inventory levels, usage, and costs.",
                    imageName: "chart.bar.fill",
                    tip: "Export reports to Excel or PDF for sharing with your team."
                ),
                TutorialStep(
                    title: "Usage Analysis",
                    description: "Identify trends in usage to optimize stocking levels.",
                    imageName: "chart.line.uptrend.xyaxis",
                    tip: "Historical data helps predict future inventory needs."
                ),
                TutorialStep(
                    title: "Purchase Analytics",
                    description: "Track spending by category, vendor, or time period.",
                    imageName: "dollarsign.circle.fill",
                    tip: "Identify cost-saving opportunities through data analysis."
                ),
                TutorialStep(
                    title: "Job Costing",
                    description: "See exactly how much inventory is used on each job.",
                    imageName: "function",
                    tip: "Ensure your service pricing accurately reflects inventory costs."
                )
            ]
        )
    ]
    
    // Constructor
    init() {
        // Check if user has completed walkthrough previously
        hasCompletedWalkthrough = UserDefaults.standard.bool(forKey: "hasCompletedAppWalkthrough")
    }
    
    // Get current section
    var currentSection: WalkthroughSection {
        let sectionIndex = min(currentStep / 4, sections.count - 1)
        return sections[sectionIndex]
    }
    
    // Get current step within section
    var currentStepInSection: TutorialStep {
        let sectionIndex = min(currentStep / 4, sections.count - 1)
        let stepIndex = currentStep % 4
        return sections[sectionIndex].steps[min(stepIndex, sections[sectionIndex].steps.count - 1)]
    }
    
    // Mark walkthrough as completed
    func completeWalkthrough() {
        hasCompletedWalkthrough = true
        isWalkthroughActive = false
        UserDefaults.standard.set(true, forKey: "hasCompletedAppWalkthrough")
    }
    
    // Start walkthrough
    func startWalkthrough() {
        currentStep = 0
        isWalkthroughActive = true
    }
    
    // Move to next step
    func nextStep() {
        let totalSteps = sections.reduce(0) { $0 + $1.steps.count }
        
        if currentStep < totalSteps - 1 {
            currentStep += 1
        } else {
            completeWalkthrough()
        }
    }
    
    // Move to previous step
    func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }
    
    // Skip walkthrough
    func skipWalkthrough() {
        completeWalkthrough()
    }
}

// Walkthrough section model
struct WalkthroughSection: Identifiable {
    var id: String
    var title: String
    var steps: [TutorialStep]
} 