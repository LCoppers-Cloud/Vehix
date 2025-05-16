import SwiftUI
import StoreKit

@available(iOS 18.0, *)
struct SubscriptionView: View {
    @EnvironmentObject var storeKit: StoreKitManager
    @State private var showTerms = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text("Unlock Full Access")
                    .font(.largeTitle.bold())
                    .padding(.top, 40)
                
                // Product information
                VStack(spacing: 12) {
                    Text("7-Day Free Trial")
                        .font(.title2.bold())
                        .foregroundColor(.accentColor)
                    
                    if let product = storeKit.products.first {
                        Text("Then \(product.displayPrice) per month")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        // Show localized price
                        HStack {
                            Text("Subscription: ")
                            Text(product.displayName)
                                .bold()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    
                    // Clearer billing information
                    if let billingDate = storeKit.trialBillingDate {
                        Text("First billing date: \(billingDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    
                    // Explicit cancellation instructions
                    Text("Cancel anytime before trial ends to avoid charges. Subscription auto-renews until cancelled.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .padding(.horizontal)
                
                // Trial status or subscription button
                if storeKit.trialActive {
                    VStack(spacing: 8) {
                        Text("Trial Active")
                            .font(.headline)
                            .foregroundColor(.green)
                        Text("Days remaining: \(storeKit.trialDaysRemaining)")
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    Button(action: {
                        Task { await storeKit.startTrialAndSubscribe() }
                    }) {
                        if storeKit.purchaseInProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Start 7-Day Free Trial")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .disabled(storeKit.purchaseInProgress)
                    .padding(.horizontal)
                }
                
                // Features included list
                VStack(alignment: .leading, spacing: 16) {
                    Text("Subscription Includes:")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    featureRow(icon: "checkmark.circle.fill", text: "Access to all vehicles and inventory features")
                    featureRow(icon: "checkmark.circle.fill", text: "Unlimited service records and maintenance tracking")
                    featureRow(icon: "checkmark.circle.fill", text: "Cloud synchronization across all your devices")
                    featureRow(icon: "checkmark.circle.fill", text: "Regular feature updates")
                    featureRow(icon: "checkmark.circle.fill", text: "Premium support")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Error message
                if let error = storeKit.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer(minLength: 20)
                
                // Terms and conditions disclaimer
                VStack(spacing: 12) {
                    Button(action: {
                        showTerms = true
                    }) {
                        Text("Subscription Terms & Conditions")
                            .font(.footnote)
                            .underline()
                    }
                    
                    Text("Payment will be charged to your Apple ID account at the confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your account settings on the App Store after purchase.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Restore purchases button - required by App Store
                    Button("Restore Purchases") {
                        Task { await storeKit.restorePurchases() }
                    }
                    .font(.footnote)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            storeKit.updateTrialStatus()
        }
        .sheet(isPresented: $showTerms) {
            subscriptionTermsView
        }
    }
    
    // Helper for feature rows
    private func featureRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
    
    // Subscription terms sheet
    private var subscriptionTermsView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Subscription Terms & Conditions")
                            .font(.title2.bold())
                        
                        Text("By subscribing to Vehix, you agree to the following terms:")
                            .font(.subheadline)
                            .padding(.bottom, 8)
                        
                        termsSection(title: "Billing", content: "Your subscription will automatically renew at the end of each period. Payment will be charged to your Apple ID account at the confirmation of purchase or at the end of the free trial period, if applicable.")
                        
                        termsSection(title: "Free Trial", content: "The 7-day free trial provides full access to all subscription features. You will not be charged during the trial period. If you do not cancel at least 24 hours before the end of the trial, you will be automatically charged for the subscription.")
                        
                        termsSection(title: "Cancellation", content: "You can cancel your subscription at any time through your Apple ID account settings. Cancellation will take effect at the end of the current billing period.")
                        
                        termsSection(title: "Price Changes", content: "If the subscription price changes, you will be notified and have the opportunity to agree to the new price before being charged.")
                        
                        termsSection(title: "Privacy", content: "Your subscription data is processed according to our Privacy Policy. We do not store your payment information, which is handled securely by Apple.")
                    }
                }
                .padding()
            }
            .navigationTitle("Subscription Terms")
            .navigationBarItems(trailing: Button("Close") {
                showTerms = false
            })
        }
    }
    
    // Helper for terms sections
    private func termsSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
                .padding(.top, 8)
        }
    }
}

// Preview for iOS 18+
#Preview("SubscriptionView") {
    SubscriptionView()
        .environmentObject(StoreKitManager())
} 