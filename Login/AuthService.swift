import Foundation
import SwiftUI

// This is a legacy implementation kept for reference and compatibility
// New code should use the AuthUser and AppAuthService from AuthModel.swift
class LegacyAuthService: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var showError = false
    
    // User roles
    enum UserRole: String, Codable {
        case admin
        case manager
        case technician
        case viewer
    }
    
    // User model
    struct User: Identifiable, Codable {
        var id: String
        var email: String
        var firstName: String
        var lastName: String
        var role: UserRole
        var companyId: String?
        var companyName: String?
        var profileImageUrl: String?
        var createdAt: Date
        var updatedAt: Date
        
        var fullName: String {
            "\(firstName) \(lastName)"
        }
    }
    
    init() {
        // Check if user is already logged in
        checkSavedCredentials()
    }
    
    func checkSavedCredentials() {
        if let userData = KeychainServices.get(key: "user.data") {
            do {
                let decoder = JSONDecoder()
                let user = try decoder.decode(User.self, from: Data(userData.utf8))
                self.currentUser = user
                self.isLoggedIn = true
            } catch {
                print("Failed to decode user data: \(error)")
                self.currentUser = nil
                self.isLoggedIn = false
            }
        }
    }
    
    func login(email: String, password: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.showError = false
        }
        
        do {
            // In a real app, this would be a network request to your authentication service
            // Simulate network delay
            try await Task.sleep(for: .seconds(1))
            
            // For demo purposes, we'll accept any valid-looking email and password
            if !email.contains("@") || password.count < 6 {
                throw AuthError.invalidCredentials
            }
            
            // Create a user account
            let emailComponents = email.components(separatedBy: "@")
            let username = emailComponents.first ?? "User"
            let domain = emailComponents.count > 1 ? emailComponents[1] : "company"
            
            let user = User(
                id: UUID().uuidString,
                email: email,
                firstName: username.capitalized,
                lastName: "Account",
                role: .admin,
                companyId: UUID().uuidString,
                companyName: "\(domain.capitalized) Company",
                profileImageUrl: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // Save user data to Keychain
            do {
                let encoder = JSONEncoder()
                let userData = try encoder.encode(user)
                if let userString = String(data: userData, encoding: .utf8) {
                    KeychainServices.save(key: "user.data", value: userString)
                }
            } catch {
                print("Failed to encode user data: \(error)")
            }
            
            // Update UI state
            await MainActor.run {
                self.currentUser = user
                self.isLoggedIn = true
                self.isLoading = false
            }
        } catch AuthError.invalidCredentials {
            await MainActor.run {
                self.errorMessage = "Invalid email or password."
                self.showError = true
                self.isLoading = false
            }
        } catch AuthError.networkError {
            await MainActor.run {
                self.errorMessage = "Network error. Please check your connection."
                self.showError = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "An unexpected error occurred."
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    func logout() {
        // Clear saved credentials
        KeychainServices.delete(key: "user.data")
        
        // Update state
        self.currentUser = nil
        self.isLoggedIn = false
    }
    
    func register(email: String, password: String, firstName: String, lastName: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.showError = false
        }
        
        // In a real app, this would be a network request to your registration service
        // For now, we'll simulate a delay and then succeed
        do {
            try await Task.sleep(for: .seconds(1.5))
            
            // Validate input
            if !email.contains("@") || password.count < 6 {
                throw AuthError.invalidCredentials
            }
            
            // Create a new user
            let user = User(
                id: UUID().uuidString,
                email: email,
                firstName: firstName,
                lastName: lastName,
                role: .admin,
                companyId: nil,
                companyName: nil,
                profileImageUrl: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // Save user data to Keychain
            do {
                let encoder = JSONEncoder()
                let userData = try encoder.encode(user)
                if let userString = String(data: userData, encoding: .utf8) {
                    KeychainServices.save(key: "user.data", value: userString)
                }
            } catch {
                print("Failed to encode user data: \(error)")
            }
            
            // Update UI state
            await MainActor.run {
                self.currentUser = user
                self.isLoggedIn = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Registration failed: \(error.localizedDescription)"
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    func resetPassword(email: String) async -> Bool {
        await MainActor.run {
            self.isLoading = true
        }
        
        // Simulate network request
        do {
            try await Task.sleep(for: .seconds(1))
            
            await MainActor.run {
                self.isLoading = false
            }
            
            // In a real app, this would check if the email exists and send a reset link
            return true
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Password reset failed: \(error.localizedDescription)"
                self.showError = true
            }
            return false
        }
    }
    
    // Error types for authentication
    enum AuthError: Error {
        case invalidCredentials
        case networkError
        case serverError
        case accountNotFound
        case accountAlreadyExists
    }
} 