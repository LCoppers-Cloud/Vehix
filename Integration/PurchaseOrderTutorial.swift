import SwiftUI

struct PurchaseOrderTutorial: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showTutorial: Bool
    
    // Track the current tutorial step
    @State private var currentStep = 0
    
    // Enhanced tutorial content
    let steps = [
        TutorialStep(
            title: "Smart Purchase Orders",
            description: "Create purchase orders seamlessly with automatic receipt scanning, vendor verification, and ServiceTitan integration.",
            imageName: "doc.text.viewfinder",
            tip: "All purchase orders sync automatically with ServiceTitan and require manager approval for better financial control."
        ),
        TutorialStep(
            title: "Step 1: Select Your Job",
            description: "Choose which ServiceTitan job this purchase is for. Your current active job will be highlighted in RED for quick selection.",
            imageName: "briefcase.fill",
            tip: "The app automatically identifies your current job based on ServiceTitan status. Other jobs for the day are also available to select."
        ),
        TutorialStep(
            title: "Step 2: Smart Receipt Capture",
            description: "Take a photo of your receipt. The app automatically scans and extracts vendor name, amount, and other details using AI.",
            imageName: "camera.viewfinder",
            tip: "Ensure good lighting and keep the receipt flat. The app works best when the vendor name and total amount are clearly visible."
        ),
        TutorialStep(
            title: "Step 3: Vendor Verification",
            description: "The app verifies the scanned vendor against your approved vendor list. Unknown vendors can be added instantly for future use.",
            imageName: "building.2.crop.circle.badge.plus",
            tip: "Approved vendors have complete contact information. New vendors are automatically added to your database for next time."
        ),
        TutorialStep(
            title: "Step 4: Amount Confirmation",
            description: "Verify or manually enter the purchase amount. The app shows the scanned amount for confirmation or allows manual entry.",
            imageName: "dollarsign.circle.fill",
            tip: "Always double-check the amount matches your receipt. This ensures accurate job costing and financial tracking."
        ),
        TutorialStep(
            title: "Step 5: Manager Approval",
            description: "Your purchase order is sent to your manager for approval. You and your manager receive notifications about the status.",
            imageName: "person.badge.clock",
            tip: "Managers receive notifications when orders need approval. You'll be notified when orders are approved or rejected."
        ),
        TutorialStep(
            title: "Step 6: ServiceTitan Sync",
            description: "Once approved, the purchase order automatically syncs with ServiceTitan, attaching to the correct job with all details.",
            imageName: "arrow.triangle.2.circlepath.circle.fill",
            tip: "The sync includes vendor information, amounts, receipt photos, and links directly to the ServiceTitan job for complete tracking."
        ),
        TutorialStep(
            title: "Smart Notifications",
            description: "The app prevents incomplete orders and sends notifications if you leave a purchase order unfinished.",
            imageName: "bell.badge.fill",
            tip: "You'll receive reminders to complete unfinished orders and notifications about approval status from your manager."
        ),
        TutorialStep(
            title: "Ready to Create POs!",
            description: "You're now ready to create purchase orders efficiently. The streamlined process saves time and ensures accuracy.",
            imageName: "checkmark.seal.fill",
            tip: "Remember: select your current job (highlighted in red), scan receipt, verify details, and submit for approval. That's it!"
        )
    ]
    
    var body: some View {
        VStack {
            // Header with enhanced progress indicators
            HStack {
                Spacer()
                
                ForEach(0..<steps.count, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                        
                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.white)
                        } else if index == currentStep {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .scaleEffect(index == currentStep ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                    
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 20, height: 2)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 20)
            
            // Content with enhanced animations
            Spacer()
            
            let step = steps[currentStep]
            
            // Icon with animation
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: step.imageName)
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.blue)
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStep)
            .padding(.bottom, 30)
            
            Text(step.title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)
            
            Text(step.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
                .lineLimit(nil)
            
            if !step.tip.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.headline)
                        
                        Text("Pro Tip")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text(step.tip)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Enhanced navigation buttons
            HStack(spacing: 16) {
                // Back/Skip button
                if currentStep == 0 {
                    Button(action: {
                        dismiss()
                        showTutorial = false
                        UserDefaults.standard.set(true, forKey: "hasSeenPOTutorial")
                    }) {
                        HStack {
                            Text("Skip Tutorial")
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                    }
                } else {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = max(0, currentStep - 1)
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                                .font(.subheadline)
                            Text("Back")
                                .font(.subheadline)
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                }
                
                Spacer()
                
                // Progress indicator
                Text("\(currentStep + 1) of \(steps.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Next/Get Started button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
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
                    HStack {
                        Text(currentStep < steps.count - 1 ? "Next" : "Get Started")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if currentStep < steps.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.subheadline)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Reset to first step when tutorial appears
            currentStep = 0
        }
    }
}

#Preview {
    PurchaseOrderTutorial(showTutorial: .constant(true))
} 