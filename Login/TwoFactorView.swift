import SwiftUI

struct TwoFactorView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authService: AppAuthService
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            // Background color
            Color(colorScheme == .dark ? .black : UIColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 0.8))
                .ignoresSafeArea()
            
            // Floating background logo
            Image(colorScheme == .dark ? "Vehix Dark" : "Vehix Light")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 400, height: 400)
                .opacity(0.1)
                .blur(radius: 5)
            
            // Content
            VStack(spacing: 30) {
                // Header
                Text("Two-Factor Authentication")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Description
                Text("We've sent a verification code to your email. Please enter it below to continue.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                VStack(spacing: 20) {
                    // Verification code
                    TextField("Enter 6-digit code", text: $authService.verificationCode)
                        .font(.title2)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .foregroundColor(.primary)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($isFocused)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isFocused = true
                            }
                        }
                        .onChange(of: authService.verificationCode) { oldValue, newValue in
                            // Limit to 6 digits
                            if newValue.count > 6 {
                                authService.verificationCode = String(newValue.prefix(6))
                            }
                            
                            // Auto-submit when 6 digits entered
                            if newValue.count == 6 {
                                verifyCode()
                            }
                        }
                    
                    // Error message
                    if let error = authService.authError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                            .padding(.top, 5)
                    }
                    
                    // Verify Button
                    Button(action: verifyCode) {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.2, green: 0.5, blue: 0.9).opacity(0.7))
                                )
                        } else {
                            Text("Verify Code")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.2, green: 0.5, blue: 0.9))
                                )
                        }
                    }
                    .disabled(authService.isLoading || authService.verificationCode.count < 6)
                    .opacity(authService.verificationCode.count == 6 ? 1.0 : 0.6)
                    
                    // Resend code
                    Button(action: {
                        // In a real app, this would resend the code
                        authService.verificationCode = ""
                    }) {
                        Text("Didn't receive the code? Resend")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
        }
    }
    
    private func verifyCode() {
        guard authService.verificationCode.count == 6 else { return }
        authService.verifyTwoFactorCode()
    }
}

#Preview {
    TwoFactorView()
        .environmentObject(AuthService())
} 