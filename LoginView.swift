import SwiftUI
import AuthenticationServices
import LocalAuthentication

public struct LoginView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authService: AppAuthService
    
    @State private var isAnimating = false
    @State private var email = "lorenjohn21@yahoo.com" // Pre-filled for presentations
    @State private var password = ""
    @State private var showingForgotPassword = false
    @State private var showingCreateAccount = false
    @State private var biometricType: BiometricType = .none
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Content
                ScrollView {
                    VStack(spacing: 30) {
                        // Logo and title
                        VStack(spacing: 10) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            
                            Text("Vehix")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Inventory Management")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 50)
                        
                        // Login form
                        VStack(spacing: 20) {
                            // Login fields
                            VStack(spacing: 15) {
                                TextField("Email", text: $email)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .padding()
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(10)
                                
                                SecureField("Password", text: $password)
                                    .padding()
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(10)
                            }
                            
                            // Forgot password
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    showingForgotPassword = true
                                }) {
                                    Text("Forgot Password?")
                                        .font(.footnote)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Login button
                            Button(action: {
                                // Use the correct method for iOS 18+ compatibility
                                Task {
                                    authService.signInWithEmail(email: email, password: password)
                                }
                            }) {
                                HStack {
                                    Text("Sign In")
                                        .fontWeight(.bold)
                                    
                                    if authService.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.leading, 5)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(authService.isLoading || !isValidInput)
                            .opacity(isValidInput ? 1.0 : 0.6)
                            
                            // Biometric Authentication Button
                            if biometricType != .none {
                                Button(action: {
                                    authenticateWithBiometrics()
                                }) {
                                    HStack {
                                        Image(systemName: biometricType == .faceID ? "faceid" : "touchid")
                                            .font(.system(size: 20))
                                        Text("Sign in with \(biometricType == .faceID ? "Face ID" : "Touch ID")")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .foregroundColor(.blue)
                                    .cornerRadius(10)
                                }
                            }
                            
                            // Sign in with Apple
                            SignInWithAppleButton(
                                .signIn,
                                onRequest: configureAppleSignIn,
                                onCompletion: handleAppleSignInResult
                            )
                            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                            .frame(height: 50)
                            .cornerRadius(10)
                            
                            // Error message
                            if let errorMessage = authService.authError {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.callout)
                                    .padding(.top, 5)
                                    .padding(.horizontal, 10)
                                    .background(Color.white.opacity(0.7))
                                    .cornerRadius(5)
                            }
                            
                            // Development mode indicator for debugging
                            #if DEBUG
                            Text("DEV MODE: Use any email & password (6+ chars)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 5)
                            #endif
                            
                            // Create account
                            VStack(spacing: 10) {
                                Text("Don't have an account?")
                                    .font(.footnote)
                                    .foregroundColor(.white)
                                
                                Button(action: {
                                    showingCreateAccount = true
                                }) {
                                    Text("Create Account")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 30)
                                        .background(Color.white.opacity(0.3))
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.top, 10)
                        }
                        .padding(.horizontal, 30)
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationDestination(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
            }
            .navigationDestination(isPresented: $showingCreateAccount) {
                CreateAccountView()
            }
            .onAppear {
                checkBiometricType()
            }
        }
    }
    
    private var isValidInput: Bool {
        return !email.isEmpty && !password.isEmpty
    }
    
    // MARK: - Biometric Authentication
    
    enum BiometricType {
        case none
        case touchID
        case faceID
    }
    
    private func checkBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if context.biometryType == .faceID {
                biometricType = .faceID
            } else if context.biometryType == .touchID {
                biometricType = .touchID
            } else {
                biometricType = .none
            }
        } else {
            biometricType = .none
            print("Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    private func authenticateWithBiometrics() {
        let context = LAContext()
        let reason = "Sign in to your Vehix account"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Successfully authenticated, sign in with saved credentials or automate login
                    authService.signInWithEmail(email: email, password: password)
                } else if let error = error {
                    // Handle authentication error
                    print("Authentication failed: \(error.localizedDescription)")
                    authService.authError = "Biometric authentication failed. Please try again or use email and password."
                }
            }
        }
    }
    
    private func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        // Add a nonce for security if needed in production
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Handle successful authentication
                let userId = appleIDCredential.user
                let email = appleIDCredential.email
                let fullName = appleIDCredential.fullName
                
                // Process name components
                let firstName = fullName?.givenName ?? ""
                let lastName = fullName?.familyName ?? ""
                let displayName = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
                
                print("Successfully authenticated with Apple ID: \(userId)")
                print("Email: \(email ?? "Not provided")")
                print("Name: \(displayName)")
                
                // Use your auth service to sign in or register
                Task {
                    authService.signInWithApple(userId: userId, email: email, fullName: displayName)
                }
            }
        case .failure(let error):
            print("Apple Sign In failed: \(error.localizedDescription)")
            authService.authError = "Apple Sign In failed: \(error.localizedDescription)"
        }
    }
}

// Placeholder extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// Simple, single preview
#Preview {
    LoginView()
        .environmentObject(AppAuthService())
} 
