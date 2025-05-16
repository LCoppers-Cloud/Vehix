import SwiftUI

struct CreateAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AppAuthService
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Header
                VStack(spacing: 10) {
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Sign up for Vehix Inventory Management")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 30)
                
                // Form fields
                VStack(spacing: 20) {
                    // Name fields
                    HStack {
                        VStack(alignment: .leading) {
                            Text("First Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("First Name", text: $firstName)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Last Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("Last Name", text: $lastName)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                    }
                    
                    // Email field
                    VStack(alignment: .leading) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // Password fields
                    VStack(alignment: .leading) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Confirm Password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Confirm Password", text: $confirmPassword)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // Error message
                    if let errorMessage = authService.authError {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.top, 5)
                    }
                    
                    // Terms text
                    Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                    
                    // Create account button
                    Button(action: {
                        createAccount()
                    }) {
                        HStack {
                            Text("Create Account")
                                .fontWeight(.bold)
                            
                            if authService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding(.leading, 5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(authService.isLoading || !isValidForm)
                    .opacity(isValidForm ? 1.0 : 0.6)
                    
                    // Back to login
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Already have an account? Sign In")
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var isValidForm: Bool {
        return !firstName.isEmpty &&
               !lastName.isEmpty &&
               !email.isEmpty &&
               email.contains("@") &&
               !password.isEmpty &&
               password == confirmPassword &&
               password.count >= 6
    }
    
    private func createAccount() {
        let fullName = "\(firstName) \(lastName)"
        authService.signUpWithEmail(email: email, password: password, fullName: fullName)
    }
}

#Preview {
    NavigationStack {
        CreateAccountView()
            .environmentObject(AppAuthService())
    }
} 