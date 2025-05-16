import SwiftUI

struct PurchaseOrderTutorial: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showTutorial: Bool
    
    // Track the current tutorial step
    @State private var currentStep = 0
    
    // Tutorial content
    let steps = [
        TutorialStep(
            title: "Create Purchase Orders",
            description: "Purchase orders help you track expenses and inventory purchases across your team.",
            imageName: "doc.text.magnifyingglass",
            tip: "All purchase orders are synced with ServiceTitan if integration is enabled."
        ),
        TutorialStep(
            title: "Step 1: Select a Job",
            description: "Choose which job this purchase is for. This helps with job costing and reporting.",
            imageName: "briefcase",
            tip: "You can filter jobs by date or technician to find what you need quickly."
        ),
        TutorialStep(
            title: "Step 2: Choose a Vendor",
            description: "Select the vendor you're purchasing from. Approved vendors are verified and have complete information.",
            imageName: "building.2",
            tip: "Can't find your vendor? Add a new one directly from the purchase flow."
        ),
        TutorialStep(
            title: "Step 3: Capture Receipt",
            description: "Take a photo of your receipt. The app will automatically scan for vendor, date, and amount.",
            imageName: "camera",
            tip: "For best results, take photos in good lighting with the receipt flat and fully visible."
        ),
        TutorialStep(
            title: "Step 4: Verify Details",
            description: "Review the extracted information and make any necessary corrections before saving.",
            imageName: "checkmark.circle",
            tip: "The system learns from your corrections to improve future scans."
        ),
        TutorialStep(
            title: "Ready to Go!",
            description: "Now you're ready to create purchase orders quickly and efficiently. Your changes sync automatically with ServiceTitan when connected.",
            imageName: "hands.sparkles",
            tip: "Access your purchase history anytime from the reports section."
        )
    ]
    
    var body: some View {
        VStack {
            // Header with progress dots
            HStack {
                Spacer()
                
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .padding(.horizontal, 4)
                }
                
                Spacer()
            }
            .padding(.top)
            
            // Content
            Spacer()
            
            let step = steps[currentStep]
            
            Image(systemName: step.imageName)
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding(.bottom, 30)
            
            Text(step.title)
                .font(.title)
                .bold()
                .padding(.bottom, 10)
            
            Text(step.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            
            if !step.tip.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    
                    Text("Tip: \(step.tip)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Navigation buttons
            HStack {
                // Skip button (only on first screen)
                if currentStep == 0 {
                    Button("Skip All") {
                        dismiss()
                        showTutorial = false
                        UserDefaults.standard.set(true, forKey: "hasSeenPOTutorial")
                    }
                    .padding()
                } else {
                    Button("Back") {
                        withAnimation {
                            currentStep = max(0, currentStep - 1)
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Next button
                Button(action: {
                    withAnimation {
                        if currentStep < steps.count - 1 {
                            currentStep += 1
                        } else {
                            // On last step, end tutorial
                            dismiss()
                            showTutorial = false
                            UserDefaults.standard.set(true, forKey: "hasSeenPOTutorial")
                        }
                    }
                }) {
                    Text(currentStep < steps.count - 1 ? "Next" : "Get Started")
                        .bold()
                        .padding()
                        .padding(.horizontal, 20)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
        .padding(.bottom)
    }
}

#Preview {
    PurchaseOrderTutorial(showTutorial: .constant(true))
} 