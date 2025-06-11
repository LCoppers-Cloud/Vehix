import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AppAuthService
    
    @State private var email = ""
    @State private var resetSent = false
    @State private var showError = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 10) {
                Text("Reset Password")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Enter your email to receive a password reset link")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
            
            // Success message
            if resetSent {
                VStack(spacing: 15) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Reset Link Sent")
                        .font(.headline)
                    
                    Text("Please check your email for instructions to reset your password.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Email field
                VStack(alignment: .leading) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter your email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Error message
                if showError, let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
                
                // Send reset button
                Button(action: {
                    sendResetLink()
                }) {
                    HStack {
                        Text("Send Reset Link")
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
                .disabled(authService.isLoading || !isValidEmail)
                .opacity(isValidEmail ? 1.0 : 0.6)
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Back button
            Button(action: {
                dismiss()
            }) {
                Text("Back to Login")
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var isValidEmail: Bool {
        return !email.isEmpty && email.contains("@")
    }
    
    private func sendResetLink() {
        // Simple email validation
        guard isValidEmail else {
            showError = true
            errorMessage = "Please enter a valid email address"
            return
        }
        
        Task {
            authService.recoverPassword(email: email)
            resetSent = true
            showError = false
            errorMessage = nil
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
            .environmentObject(AppAuthService())
    }
} 