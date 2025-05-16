import SwiftUI

struct VendorTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showTutorial: Bool
    
    @State private var currentStep = 0
    
    // Tutorial content
    let steps = [
        TutorialStep(
            title: "Vendor Management",
            description: "Vendor management is essential for tracking your purchases and expenses efficiently.",
            imageName: "building.2.fill",
            tip: "Well-organized vendor data helps with purchasing decisions and expense tracking."
        ),
        TutorialStep(
            title: "Add Vendors Manually",
            description: "You can add vendors manually with complete details like contact information and payment terms.",
            imageName: "plus.circle",
            tip: "Add all relevant details for better organization and reporting."
        ),
        TutorialStep(
            title: "Scan Receipts",
            description: "When you scan receipts, the system identifies vendors automatically using machine learning.",
            imageName: "doc.text.viewfinder",
            tip: "The system gets smarter with each receipt you scan."
        ),
        TutorialStep(
            title: "Verify New Vendors",
            description: "When a new vendor is detected, you can verify and add it to your approved vendors list.",
            imageName: "checkmark.seal",
            tip: "Verification helps maintain data quality and prevents duplicates."
        ),
        TutorialStep(
            title: "Vendor Intelligence",
            description: "Our system learns from all users, sharing vendor recognition data securely via CloudKit.",
            imageName: "arrow.triangle.2.circlepath.circle",
            tip: "The more receipts scanned across all users, the smarter the system becomes."
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
                if currentStep == 0 {
                    Button("Skip") {
                        dismiss()
                        showTutorial = false
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
                
                Button(action: {
                    withAnimation {
                        if currentStep < steps.count - 1 {
                            currentStep += 1
                        } else {
                            dismiss()
                            showTutorial = false
                        }
                    }
                }) {
                    Text(currentStep < steps.count - 1 ? "Next" : "Got It")
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
    VendorTutorialView(showTutorial: .constant(true))
} 