import SwiftUI

struct AppWalkthroughView: View {
    @StateObject var walkthroughManager = AppWalkthroughManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background color
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with progress dots
                VStack {
                    // Section title
                    Text(walkthroughManager.currentSection.title)
                        .font(.headline)
                        .padding(.vertical, 10)
                    
                    // Progress indicator dots
                    let totalSteps = walkthroughManager.sections.reduce(0) { $0 + $1.steps.count }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(0..<totalSteps, id: \.self) { index in
                                Circle()
                                    .fill(index == walkthroughManager.currentStep ? Color.blue : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 20)
                }
                .padding(.top)
                
                // Content area
                ScrollView {
                    VStack(spacing: 30) {
                        Spacer(minLength: 30)
                        
                        // Current step content
                        let step = walkthroughManager.currentStepInSection
                        
                        Image(systemName: step.imageName)
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                            .padding(.bottom, 20)
                        
                        Text(step.title)
                            .font(.title2)
                            .bold()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text(step.description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 30)
                        
                        if !step.tip.isEmpty {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 20))
                                
                                Text(step.tip)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 30)
                    }
                    .padding()
                }
                
                // Navigation buttons
                VStack(spacing: 16) {
                    // Skip or "Get Started" button
                    if walkthroughManager.currentStep == 0 {
                        Button(action: {
                            walkthroughManager.skipWalkthrough()
                            dismiss()
                        }) {
                            Text("Skip Tutorial")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Navigation buttons (Back/Next or Continue)
                    HStack {
                        // Back button (hidden on first step)
                        if walkthroughManager.currentStep > 0 {
                            Button(action: {
                                withAnimation {
                                    walkthroughManager.previousStep()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .padding()
                                .foregroundColor(.blue)
                            }
                        } else {
                            Spacer()
                                .frame(width: 80)
                        }
                        
                        Spacer()
                        
                        // Next/Finish button
                        let totalSteps = walkthroughManager.sections.reduce(0) { $0 + $1.steps.count }
                        let isLastStep = walkthroughManager.currentStep == totalSteps - 1
                        
                        Button(action: {
                            withAnimation {
                                if isLastStep {
                                    walkthroughManager.completeWalkthrough()
                                    dismiss()
                                } else {
                                    walkthroughManager.nextStep()
                                }
                            }
                        }) {
                            HStack {
                                Text(isLastStep ? "Get Started" : "Next")
                                
                                if !isLastStep {
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            walkthroughManager.startWalkthrough()
        }
    }
}

struct WalkthroughSectionHeader: View {
    let section: WalkthroughSection
    
    var body: some View {
        VStack(spacing: 8) {
            Text(section.title)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

// Preview provider
#Preview {
    AppWalkthroughView()
} 