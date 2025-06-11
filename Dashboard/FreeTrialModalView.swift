import SwiftUI
import StoreKit

struct FreeTrialModalView: View {
    @EnvironmentObject var storeKit: StoreKitManager
    @Environment(\.dismiss) var dismiss
    @State private var showingPlanComparison = false
    @State private var isStartingTrial = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background similar to the image
                Color.black.opacity(0.9)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header with star icon
                    VStack(spacing: 16) {
                                                 Image(systemName: "star.circle.fill")
                             .font(.system(size: 80))
                             .foregroundColor(Color.vehixYellow)
                        
                        Text("Free Trial")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Start Your Free Trial")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Get full access to all professional features")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Features list
                    VStack(spacing: 20) {
                        FeatureRowWhite(text: "Unlimited vehicles and inventory")
                        FeatureRowWhite(text: "Advanced reporting and analytics")
                        FeatureRowWhite(text: "Team collaboration tools")
                        FeatureRowWhite(text: "Priority customer support")
                        FeatureRowWhite(text: "CloudKit data sync")
                        FeatureRowWhite(text: "Export to Excel, PDF, QuickBooks")
                    }
                    .padding(.horizontal, 32)
                    
                    // Action button
                    VStack(spacing: 16) {
                        Button(action: {
                            if storeKit.canStartTrial {
                                startTrial()
                            } else {
                                showingPlanComparison = true
                            }
                        }) {
                            VStack(spacing: 4) {
                                if isStartingTrial {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Start 7-Day Free Trial")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                                                         .background(Color.vehixBlue)
                            .cornerRadius(12)
                        }
                        .disabled(isStartingTrial)
                        .padding(.horizontal, 32)
                        
                        VStack(spacing: 8) {
                            Text("Then $125/month, cancel anytime")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            Button("View All Plans") {
                                showingPlanComparison = true
                            }
                            .font(.system(size: 14))
                            .foregroundColor(Color.vehixBlue)
                        }
                    }
                    
                    // Fine print
                    VStack(spacing: 8) {
                        Text("• Free trial automatically converts to paid subscription")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text("• Cancel anytime in Settings > Subscriptions")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text("• Full refund if cancelled within trial period")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 32)
                    
                    // Restore purchases
                    Button("Restore Purchases") {
                        Task {
                            await storeKit.restorePurchases()
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(Color.vehixBlue)
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color.vehixBlue)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingPlanComparison) {
            if #available(iOS 15.0, *) {
                SubscriptionManagementView()
                    .environmentObject(storeKit)
            } else {
                Text("Subscription management requires iOS 15+")
                    .padding()
            }
        }
    }
    
    private func startTrial() {
        isStartingTrial = true
        
        Task {
            await storeKit.startFreeTrial()
            
            DispatchQueue.main.async {
                self.isStartingTrial = false
                
                // If trial started successfully, dismiss the view
                if storeKit.isInTrial {
                    dismiss()
                }
            }
        }
    }
}

struct FeatureRowWhite: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
                         Image(systemName: "checkmark.circle.fill")
                 .foregroundColor(Color.vehixGreen)
                .font(.system(size: 20))
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

#Preview {
    FreeTrialModalView()
        .environmentObject(StoreKitManager())
} 