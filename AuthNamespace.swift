import Foundation
import SwiftData
import SwiftUI
import AuthenticationServices

// Create a namespace for auth-related functionality
enum Auth {
    // Typealias to access the existing authentication service
    // Use a fully qualified path to avoid ambiguity
    typealias Service = AuthService
    typealias User = AuthUser
    
    // User roles stay the same
    enum UserRole: String, Codable {
        case standard
        case premium
        case admin
        case dealer
        case technician
        
        // If needed, add methods specific to roles here
    }
}

// The AppAuthService typealias provides a clear reference to avoid ambiguity
typealias AppAuthService = AppAuthServiceImpl
typealias AppAuthUser = AuthUser

/*
 HOW TO USE THIS NAMESPACE:
 
 1. In view files where you have the error "'AuthService' is ambiguous for type lookup in this context",
    change:
    
    @EnvironmentObject var authService: AuthService
    
    to:
    
    @EnvironmentObject var authService: AppAuthService
 
 2. When creating instances, use the fully qualified name:
    
    @StateObject private var authService = AppAuthService()
 
 3. For role comparisons, use the Auth namespace:
    
    if user.role == Auth.UserRole.admin.rawValue { ... }
 
 This namespace approach allows us to maintain compatibility with existing code
 while resolving the ambiguity issues. Once all references are updated, we can
 consider more comprehensive refactoring of the authentication system.
 */ 