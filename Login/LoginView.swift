import SwiftUI
import AuthenticationServices
import LocalAuthentication
import StoreKit

public struct LoginView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    
    // Sheet management
    enum SheetType: String, Identifiable {
        case forgotPassword, createAccount, subscriptionOffer, trialOffer
        var id: String { rawValue }
    }
    
    // UI State
    @State private var activeSheet: SheetType?
    @State private var isAnimating = false
    @State private var email = ""
    @State private var password = ""
    @State private var showingForgotPassword = false
    @State private var showingCreateAccount = false
    @State private var showingSubscriptionOffer = false
    @State private var showingTrialOffer = false
    
    // Authentication State
    @State private var biometricType: BiometricType = .none
    @State private var hasStoredCredentials = false
    @State private var storedAppleUserID: String?
    @State private var isCheckingStoredAuth = true
    @State private var showingBiometricPrompt = false
    
    // Subscription State
    @State private var userAccountType: AccountType = .none
    @State private var needsSubscription = false
    
    enum BiometricType {
        case none
        case touchID
        case faceID
        
        var displayName: String {
            switch self {
            case .none: return ""
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            }
        }
        
        var iconName: String {
            switch self {
            case .none: return ""
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            }
        }
    }
    
    enum AccountType {
        case none
        case existing
        case newUser
        case expiredTrial
        case activeSubscription
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Professional background
                backgroundView
                
                // Main content
                ScrollView {
                    VStack(spacing: 0) {
                        // App branding section
                        appBrandingSection
                            .padding(.top, 60)
                        
                        // Authentication section
                        authenticationSection
                            .padding(.horizontal, 32)
                            .padding(.top, 40)
                        
                        // Footer
                        footerSection
                            .padding(.top, 40)
                            .padding(.bottom, 50)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupLoginView()
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .forgotPassword:
                    ForgotPasswordView()
                case .createAccount:
                    CreateAccountView()
                case .subscriptionOffer:
                    SubscriptionOfferView()
                        .environmentObject(storeKitManager)
                case .trialOffer:
                    TrialOfferView()
                        .environmentObject(storeKitManager)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var backgroundView: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color("vehix-ui-blue").opacity(0.1),
                    Color("vehix-ui-green").opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle pattern overlay
            Color.clear
                .background(
                    Image(systemName: "car.fill")
                        .font(.system(size: 200))
                        .foregroundColor(Color.primary.opacity(0.02))
                        .rotationEffect(.degrees(-15))
                        .offset(x: 100, y: -100)
                )
        }
    }
    
    private var appBrandingSection: some View {
        VStack(spacing: 16) {
            // App icon
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                Image("Vehix Light")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            }
            .scaleEffect(isAnimating ? 1.0 : 0.8)
            .animation(.easeInOut(duration: 1.0), value: isAnimating)
            
            // App name and tagline
            VStack(spacing: 8) {
                Text("Vehix")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Professional Vehicle Inventory Management")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }
    
    private var authenticationSection: some View {
        VStack(spacing: 24) {
            // Always show manual login as primary option
            manualLoginSection
            
            // Quick sign-in option (if available)
            if hasStoredCredentials || storedAppleUserID != nil {
                VStack(spacing: 8) {
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    automaticAuthSection
                }
            }
            
            // Apple Sign In (always available)
            appleSignInSection
            
            // Error display
            if let errorMessage = authService.authError {
                errorMessageView(errorMessage)
            }
        }
    }
    
    private var automaticAuthSection: some View {
        VStack(spacing: 20) {
            // Quick sign in section
            VStack(spacing: 8) {
                Text("Quick Sign In")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                if let email = getStoredEmail() {
                    Text(email)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Biometric authentication button
            if biometricType != .none {
                Button(action: authenticateWithBiometrics) {
                    HStack(spacing: 12) {
                        Image(systemName: biometricType.iconName)
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sign in with \(biometricType.displayName)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                            Text("Quick and secure access")
                                .font(.system(size: 12))
                                .foregroundColor(.black.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        if authService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .disabled(authService.isLoading)
            }
            
            // Alternative login options
            Button(action: { showAlternativeLogin() }) {
                Text("Use different account")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var manualLoginSection: some View {
        VStack(spacing: 20) {
            // Login form
            VStack(spacing: 16) {
                // Email field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("Enter your email", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .foregroundColor(.black)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                
                // Password field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    SecureField("Enter your password", text: $password)
                        .textContentType(.password)
                        .foregroundColor(.black)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
            }
            
            // Forgot password
            HStack {
                Spacer()
                Button(action: { showingForgotPassword = true }) {
                    Text("Forgot Password?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            // Sign in button
            Button(action: signInWithEmail) {
                HStack {
                    Text("Sign In")
                        .font(.system(size: 16, weight: .semibold))
                    
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                                    .background(isValidInput ? Color.vehixBlue : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .disabled(!isValidInput || authService.isLoading)
        }
    }
    
    private var appleSignInSection: some View {
        VStack(spacing: 16) {
            // Divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
                
                Text("or")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
            }
            
            // Apple Sign In button
            SignInWithAppleButton(
                .signIn,
                onRequest: configureAppleSignIn,
                onCompletion: handleAppleSignInResult
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Free trial button for new users
            if needsSubscription {
                Button(action: { showingTrialOffer = true }) {
                    VStack(spacing: 4) {
                        Text("Start Free Trial")
                            .font(.system(size: 16, weight: .semibold))
                        Text("7 days free, then $125/month")
                            .font(.system(size: 12))
                            .opacity(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 32)
            }
            
            // Create account option
            VStack(spacing: 12) {
                Text("Don't have an account?")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                Button(action: { showingCreateAccount = true }) {
                    Text("Create Account")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            
            // Terms and privacy
            VStack(spacing: 8) {
                Text("By continuing, you agree to our")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(spacing: 16) {
                    Button("Terms of Service") {
                        // Open terms
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                    
                    Button("Privacy Policy") {
                        // Open privacy policy
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func errorMessageView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(16)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Properties
    
    private var isValidInput: Bool {
        return !email.isEmpty && !password.isEmpty && password.count >= 6
    }
    
    // MARK: - Setup and Authentication Methods
    
    private func setupLoginView() {
        isAnimating = true
        checkBiometricType()
        checkStoredCredentials()
        checkAppleIDStatus()
        determineUserAccountType()
    }
    
    private func checkBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            default:
                biometricType = .none
            }
        } else {
            biometricType = .none
        }
    }
    
    private func checkStoredCredentials() {
        // Check for stored email/password credentials
        if let storedEmail = UserDefaults.standard.string(forKey: "stored_email"),
           UserDefaults.standard.bool(forKey: "biometric_enabled") {
            email = storedEmail
            hasStoredCredentials = true
        }
        isCheckingStoredAuth = false
    }
    
    private func checkAppleIDStatus() {
        // Check for stored Apple ID
        if let appleUserID = UserDefaults.standard.string(forKey: "apple_user_id") {
            storedAppleUserID = appleUserID
            
            // Check Apple ID credential state
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: appleUserID) { credentialState, error in
                DispatchQueue.main.async {
                    switch credentialState {
                    case .authorized:
                        // User is still authorized, can auto-sign in
                        self.hasStoredCredentials = true
                    case .revoked, .notFound:
                        // Clear stored Apple ID
                        UserDefaults.standard.removeObject(forKey: "apple_user_id")
                        self.storedAppleUserID = nil
                    case .transferred:
                        // Handle transferred state if needed
                        break
                    @unknown default:
                        break
                    }
                }
            }
        }
    }
    
    private func determineUserAccountType() {
        // Check subscription status and determine what to show
        DispatchQueue.main.async {
            if self.storeKitManager.isSubscribed {
                self.userAccountType = .activeSubscription
            } else if UserDefaults.standard.bool(forKey: "trial_used") {
                self.userAccountType = .expiredTrial
                self.needsSubscription = true
            } else {
                self.userAccountType = .newUser
                self.needsSubscription = true
            }
        }
    }
    
    private func getStoredEmail() -> String? {
        return UserDefaults.standard.string(forKey: "stored_email")
    }
    
    private func showAlternativeLogin() {
        hasStoredCredentials = false
        storedAppleUserID = nil
        email = ""
        password = ""
    }
    
    // MARK: - Authentication Actions
    
    private func signInWithEmail() {
        Task {
            authService.signInWithEmail(email: email, password: password)
            
            // Store credentials for biometric auth if successful
            if authService.isLoggedIn {
                UserDefaults.standard.set(email, forKey: "stored_email")
                UserDefaults.standard.set(true, forKey: "biometric_enabled")
            }
        }
    }
    
    private func authenticateWithBiometrics() {
        let context = LAContext()
        let reason = "Sign in to your Vehix account securely"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    if let appleUserID = self.storedAppleUserID {
                        // Auto sign in with Apple ID
                        self.autoSignInWithApple(userID: appleUserID)
                    } else if self.hasStoredCredentials {
                        // Auto sign in with stored email
                        if let storedPassword = self.getStoredPassword() {
                            self.password = storedPassword
                            self.signInWithEmail()
                        }
                    }
                } else {
                    self.authService.authError = "Biometric authentication failed. Please try again."
                }
            }
        }
    }
    
    private func getStoredPassword() -> String? {
        // In a real app, you'd use Keychain for secure password storage
        // This is a simplified implementation
        return UserDefaults.standard.string(forKey: "stored_password")
    }
    
    private func autoSignInWithApple(userID: String) {
        // Attempt automatic Apple ID sign in
        Task {
            authService.signInWithApple(userId: userID, email: nil, fullName: nil)
        }
    }
    
    private func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        // Add nonce for security in production
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userId = appleIDCredential.user
                let email = appleIDCredential.email
                let fullName = appleIDCredential.fullName
                
                let displayName = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                // Store Apple ID for future automatic sign in
                UserDefaults.standard.set(userId, forKey: "apple_user_id")
                
                Task {
                    authService.signInWithApple(
                        userId: userId,
                        email: email,
                        fullName: displayName.isEmpty ? nil : displayName
                    )
                }
            }
        case .failure(let error):
            authService.authError = "Apple Sign In failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Views

struct SubscriptionOfferView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storeKitManager: StoreKitManager
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Choose Your Plan")
                    .font(.largeTitle)
                    .bold()
                    .padding()
                
                // Subscription plans would go here
                Text("Subscription plans coming soon...")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Subscription")
            .navigationBarItems(trailing: Button("Close") { dismiss() })
        }
    }
}

struct TrialOfferView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storeKitManager: StoreKitManager
    @State private var isStartingTrial = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Start Your Free Trial")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Get full access to all professional features")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Trial benefits
                VStack(spacing: 20) {
                    FeatureRow(icon: "checkmark.circle.fill", text: "Unlimited vehicles and inventory")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Advanced reporting and analytics")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Team collaboration tools")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Priority customer support")
                    FeatureRow(icon: "checkmark.circle.fill", text: "CloudKit data sync")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Export to Excel, PDF, QuickBooks")
                }
                
                // Pricing information
                VStack(spacing: 12) {
                    if storeKitManager.canStartTrial {
                        Button(action: startTrial) {
                            HStack {
                                if isStartingTrial {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    VStack(spacing: 4) {
                                        Text("Start 7-Day Free Trial")
                                            .font(.headline)
                                        
                                        if let pricing = storeKitManager.getSubscriptionPricing()[.basic] {
                                            Text("Then \(pricing)/month, cancel anytime")
                                                .font(.caption)
                                                .opacity(0.8)
                                        } else {
                                            Text("Then $125/month, cancel anytime")
                                                .font(.caption)
                                                .opacity(0.8)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(storeKitManager.canStartTrial ? Color.vehixBlue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!storeKitManager.canStartTrial || isStartingTrial)
                        
                        // Apple Store compliant disclaimer
                        VStack(spacing: 8) {
                            Text("• Free trial automatically converts to paid subscription")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("• Cancel anytime in Settings > Subscriptions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("• Full refund if cancelled within trial period")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(spacing: 12) {
                            Text("Trial Already Used")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("You've already used your free trial. Choose a subscription plan to continue.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: { 
                                // Show subscription options
                                dismiss()
                            }) {
                                Text("View Subscription Plans")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.vehixBlue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Restore purchases button (Apple Store requirement)
                    Button(action: restorePurchases) {
                        Text("Restore Purchases")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .disabled(storeKitManager.isLoading)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Free Trial")
            .navigationBarItems(trailing: Button("Close") { dismiss() })
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: storeKitManager.errorMessage) { _, newValue in
                if let error = newValue {
                    errorMessage = error
                    showingError = true
                }
            }
        }
    }
    
    private func startTrial() {
        isStartingTrial = true
        
        Task {
            await storeKitManager.startFreeTrial()
            
            DispatchQueue.main.async {
                self.isStartingTrial = false
                
                // If trial started successfully, dismiss the view
                if storeKitManager.isInTrial {
                    dismiss()
                }
            }
        }
    }
    
    private func restorePurchases() {
        Task {
            await storeKitManager.restorePurchases()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.title3)
            
            Text(text)
                .font(.body)
            
            Spacer()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppAuthService())
        .environmentObject(StoreKitManager(isSimulatorEnvironment: true))
} 
