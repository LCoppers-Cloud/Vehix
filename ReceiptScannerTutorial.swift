import SwiftUI

struct ReceiptScannerTutorial: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showTutorial: Bool
    
    @State private var currentStep = 0
    
    // Tutorial content
    let steps = [
        TutorialStep(
            title: "Receipt Scanner",
            description: "Our intelligent receipt scanner helps you quickly capture and process purchase receipts.",
            imageName: "doc.text.viewfinder",
            tip: "The scanner works best in good lighting with a clear view of the entire receipt."
        ),
        TutorialStep(
            title: "Step 1: Capture Receipt",
            description: "Take a clear photo of the receipt or select one from your photo library.",
            imageName: "camera",
            tip: "Make sure all text is clearly visible and the receipt is flat and well-lit."
        ),
        TutorialStep(
            title: "Step 2: Automatic Detection",
            description: "The system automatically detects the vendor, date, total amount, and individual line items.",
            imageName: "sparkles",
            tip: "Our ML models improve with every scan, getting more accurate over time."
        ),
        TutorialStep(
            title: "Step 3: Verify Information",
            description: "Review the extracted information and make any necessary corrections.",
            imageName: "checkmark.circle",
            tip: "You can manually adjust any data that wasn't accurately recognized."
        ),
        TutorialStep(
            title: "Step 4: Vendor Management",
            description: "When new vendors are detected, you can add them to your vendor database for future recognition.",
            imageName: "building.2",
            tip: "Approving vendors helps build a more accurate recognition model for everyone."
        ),
        TutorialStep(
            title: "Step 5: Save & Sync",
            description: "Save the receipt to create inventory transactions and expense records that sync with your accounting system.",
            imageName: "arrow.triangle.2.circlepath",
            tip: "All receipts are stored securely and can be accessed from any device."
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
                        UserDefaults.standard.set(true, forKey: "hasSeenReceiptScannerTutorial")
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
                            UserDefaults.standard.set(true, forKey: "hasSeenReceiptScannerTutorial")
                        }
                    }
                }) {
                    Text(currentStep < steps.count - 1 ? "Next" : "Start Scanning")
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
    ReceiptScannerTutorial(showTutorial: .constant(true))
} 