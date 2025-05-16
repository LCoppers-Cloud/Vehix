import SwiftUI
import AuthenticationServices
import SwiftData

// User account types
public enum UserRole: String, Codable {
    case standard
    case premium
    case admin
    case dealer
    case technician
}

// User authentication model
@Model
public final class AuthUser {
    public var id: String = UUID().uuidString
    public var email: String = ""
    public var fullName: String?
    public var appleIdentifier: String?
    public var role: String = UserRole.standard.rawValue // Store as string for SwiftData compatibility
    public var isVerified: Bool = false
    public var isTwoFactorEnabled: Bool = true
    public var lastLogin: Date = Date()
    public var createdAt: Date = Date()
    public var isDeactivated: Bool = false
    
    // Task relationships
    @Relationship(deleteRule: .cascade) var assignedTasks: [AppTask]? = []
    @Relationship(deleteRule: .cascade) var createdTasks: [AppTask]? = []
    
    // NOTE: hasCompletedSetup is implemented as a computed property in an extension
    // in InitialSetupView.swift to persist the value in UserDefaults
    
    // Computed property for role
    public var userRole: UserRole {
        get { UserRole(rawValue: role) ?? .standard }
        set { role = newValue.rawValue }
    }
    
    init(
        id: String = UUID().uuidString,
        email: String = "",
        fullName: String? = nil,
        appleIdentifier: String? = nil,
        role: UserRole = .standard,
        isVerified: Bool = false,
        isTwoFactorEnabled: Bool = true,
        lastLogin: Date = Date(),
        createdAt: Date = Date(),
        isDeactivated: Bool = false
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.appleIdentifier = appleIdentifier
        self.role = role.rawValue
        self.isVerified = isVerified
        self.isTwoFactorEnabled = isTwoFactorEnabled
        self.lastLogin = lastLogin
        self.createdAt = createdAt
        self.isDeactivated = isDeactivated
    }
}

// Authentication service
public class AuthService: ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var authError: String?
    @Published var needsTwoFactor: Bool = false
    @Published var verificationCode: String = ""
    @Published var isRegistrationComplete: Bool = false
    
    // Make modelContext accessible from outside
    var modelContext: ModelContext?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }
    
    // Check if a user has an account with the provided Apple ID
    func checkAppleIdAccount(with appleID: String, completion: @escaping (AuthUser?) -> Void) {
        guard let modelContext = modelContext else {
            completion(nil)
            return
        }
        
        do {
            // Get all users and filter in memory instead of using predicate
            let descriptor = FetchDescriptor<AuthUser>()
            let allUsers = try modelContext.fetch(descriptor)
            let matchingUser = allUsers.first { user in
                user.appleIdentifier == appleID
            }
            
            if let user = matchingUser {
                // User found - auto login
                DispatchQueue.main.async {
                    self.currentUser = user
                    self.isLoggedIn = true
                    self.updateLastLogin(user: user)
                }
                completion(user)
            } else {
                // No user found with this Apple ID
                completion(nil)
            }
        } catch {
            print("Error fetching user with Apple ID: \(error)")
            completion(nil)
        }
    }
    
    // Handle Apple Sign In
    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) {
        isLoading = true
        
        // Extract user information from the credential
        let userId = credential.user
        let email = credential.email ?? ""
        var fullName: String?
        
        if let firstName = credential.fullName?.givenName,
           let lastName = credential.fullName?.familyName {
            fullName = "\(firstName) \(lastName)"
        }
        
        // Check if this Apple ID is already associated with an account
        checkAppleIdAccount(with: userId) { [weak self] existingUser in
            guard let self = self else { return }
            
            // If user exists, we've already logged them in in the checkAppleIdAccount method
            if existingUser != nil {
                self.isLoading = false
                return
            }
            
            // No existing user, create a new one
            if !email.isEmpty {
                let newUser = AuthUser(
                    email: email,
                    fullName: fullName,
                    appleIdentifier: userId,
                    isVerified: true, // Apple accounts are pre-verified
                    isTwoFactorEnabled: false // No need for 2FA with Apple Sign In
                )
                
                if let modelContext = self.modelContext {
                    modelContext.insert(newUser)
                    do {
                        try modelContext.save()
                        
                        self.currentUser = newUser
                        self.isLoggedIn = true
                    } catch {
                        self.authError = "Failed to create account: \(error.localizedDescription)"
                    }
                }
            } else {
                self.authError = "Could not access email from Apple ID"
            }
            
            self.isLoading = false
        }
    }
    
    // Sign in with Apple - direct method for use from LoginView
    func signInWithApple(userId: String, email: String?, fullName: String?) {
        isLoading = true
        authError = nil
        
        // Check if this Apple ID is already associated with an account
        checkAppleIdAccount(with: userId) { [weak self] existingUser in
            guard let self = self else { return }
            
            // If user exists, we've already logged them in in the checkAppleIdAccount method
            if existingUser != nil {
                self.isLoading = false
                return
            }
            
            // No existing user, create a new one if we have an email
            if let email = email, !email.isEmpty {
                let newUser = AuthUser(
                    email: email,
                    fullName: fullName,
                    appleIdentifier: userId,
                    role: .standard,
                    isVerified: true, // Apple accounts are pre-verified
                    isTwoFactorEnabled: false // No need for 2FA with Apple Sign In
                )
                
                if let modelContext = self.modelContext {
                    modelContext.insert(newUser)
                    do {
                        try modelContext.save()
                        
                        self.currentUser = newUser
                        self.isLoggedIn = true
                    } catch {
                        self.authError = "Failed to create account: \(error.localizedDescription)"
                    }
                }
            } else {
                // For returning users, Apple might not provide email again
                // Create account with just the Apple ID and a placeholder email
                let placeholderEmail = "apple_user_\(userId.prefix(8))@example.com"
                let newUser = AuthUser(
                    email: placeholderEmail,
                    fullName: fullName,
                    appleIdentifier: userId,
                    role: .standard,
                    isVerified: true,
                    isTwoFactorEnabled: false
                )
                
                if let modelContext = self.modelContext {
                    modelContext.insert(newUser)
                    do {
                        try modelContext.save()
                        
                        self.currentUser = newUser
                        self.isLoggedIn = true
                    } catch {
                        self.authError = "Failed to create account: \(error.localizedDescription)"
                    }
                }
            }
            
            self.isLoading = false
        }
    }
    
    // Email sign in
    func signInWithEmail(email: String, password: String) {
        isLoading = true
        authError = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // In a real app, you would validate the credentials against a backend
            // For now, we'll just simulate finding a user
            if let modelContext = self.modelContext {
                do {
                    // Get all users and filter in memory
                    let descriptor = FetchDescriptor<AuthUser>()
                    let allUsers = try modelContext.fetch(descriptor)
                    let matchingUser = allUsers.first { user in
                        user.email == email
                    }
                    
                    if let user = matchingUser {
                        // Check if 2FA is enabled
                        if user.isTwoFactorEnabled {
                            self.needsTwoFactor = true
                            self.sendTwoFactorCode(to: email)
                        } else {
                            // Login successful
                            self.currentUser = user
                            self.isLoggedIn = true
                            self.updateLastLogin(user: user)
                        }
                    } else {
                        self.authError = "No account found with this email"
                    }
                } catch {
                    self.authError = "Error during sign in: \(error.localizedDescription)"
                }
            } else {
                self.authError = "Database error"
            }
            
            self.isLoading = false
        }
    }
    
    // Verify two-factor code
    func verifyTwoFactorCode() {
        isLoading = true
        
        // Simulate verification
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // In a real app, validate the code against what was sent
            // For demo, accept any 6-digit code
            if self.verificationCode.count == 6 && Int(self.verificationCode) != nil {
                guard let modelContext = self.modelContext,
                      let userEmail = self.currentUser?.email else {
                    self.authError = "Session expired"
                    self.isLoading = false
                    return
                }
                
                do {
                    // Get all users and filter in memory
                    let descriptor = FetchDescriptor<AuthUser>()
                    let allUsers = try modelContext.fetch(descriptor)
                    let matchingUser = allUsers.first { user in
                        user.email == userEmail
                    }
                    
                    if let user = matchingUser {
                        self.currentUser = user
                        self.isLoggedIn = true
                        self.needsTwoFactor = false
                        self.verificationCode = ""
                        self.updateLastLogin(user: user)
                    }
                } catch {
                    self.authError = "Error during verification: \(error.localizedDescription)"
                }
            } else {
                self.authError = "Invalid verification code"
            }
            
            self.isLoading = false
        }
    }
    
    // Sign up with email
    func signUpWithEmail(email: String, password: String, fullName: String) {
        isLoading = true
        authError = nil
        
        // Check if email is already in use
        if let modelContext = modelContext {
            do {
                // Get all users and filter in memory
                let descriptor = FetchDescriptor<AuthUser>()
                let allUsers = try modelContext.fetch(descriptor)
                let emailExists = allUsers.contains { user in
                    user.email == email
                }
                
                if emailExists {
                    authError = "Email already in use"
                    isLoading = false
                    return
                }
                
                // Create new user
                let newUser = AuthUser(
                    email: email,
                    fullName: fullName,
                    isTwoFactorEnabled: true
                )
                
                modelContext.insert(newUser)
                try modelContext.save()
                
                // In a real app, you would also store the password securely
                // and send a verification email
                
                // Simulate sending verification email
                sendVerificationEmail(to: email)
                
                // Set current user but don't log in until verified
                currentUser = newUser
                authError = nil
                
                // Success UI update
                isLoading = false
                isRegistrationComplete = true
            } catch {
                authError = "Error during sign up: \(error.localizedDescription)"
                isLoading = false
            }
        } else {
            authError = "Database error"
            isLoading = false
        }
    }
    
    // Password recovery
    func recoverPassword(email: String) {
        isLoading = true
        authError = nil
        
        // Simulate sending recovery email
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // In a real app, you would check if the email exists and send a recovery link
            self.authError = nil
            
            self.isLoading = false
        }
    }
    
    // Sign out
    func signOut() {
        currentUser = nil
        isLoggedIn = false
        needsTwoFactor = false
        verificationCode = ""
        
        // Clear any potentially saved legacy credentials
        KeychainServices.delete(key: "user.data")
    }
    
    // MARK: - Helper methods
    
    // Send 2FA code (simulated)
    private func sendTwoFactorCode(to email: String) {
        // In a real app, generate and send a code via SMS/email
        print("Sending 2FA code to \(email)")
    }
    
    // Send verification email (simulated)
    private func sendVerificationEmail(to email: String) {
        // In a real app, send verification link
        print("Sending verification email to \(email)")
    }
    
    // Update last login time
    private func updateLastLogin(user: AuthUser) {
        user.lastLogin = Date()
        
        if let modelContext = modelContext {
            do {
                try modelContext.save()
            } catch {
                print("Error updating last login: \(error)")
            }
        }
    }
}

// Authentication service for the entire app
public class AppAuthServiceImpl: ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var authError: String?
    @Published var needsTwoFactor: Bool = false
    @Published var verificationCode: String = ""
    @Published var isRegistrationComplete: Bool = false
    
    // Make modelContext accessible from outside
    var modelContext: ModelContext?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }
    
    // Password recovery method - added to match AuthService implementation
    func recoverPassword(email: String) {
        isLoading = true
        authError = nil
        
        // Simulate sending recovery email
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // In a real app, you would check if the email exists and send a recovery link
            self.authError = nil
            
            self.isLoading = false
        }
    }
    
    // Email sign in method - added to match AuthService implementation
    func signInWithEmail(email: String, password: String) {
        isLoading = true
        authError = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // In a real app, you would validate the credentials against a backend
            // For now, we'll just simulate finding a user
            if let modelContext = self.modelContext {
                do {
                    // Get all users and filter in memory
                    let descriptor = FetchDescriptor<AuthUser>()
                    let allUsers = try modelContext.fetch(descriptor)
                    let matchingUser = allUsers.first { user in
                        user.email == email
                    }
                    
                    if let user = matchingUser {
                        // Check if 2FA is enabled
                        if user.isTwoFactorEnabled {
                            self.needsTwoFactor = true
                            self.sendTwoFactorCode(to: email)
                        } else {
                            // Login successful
                            self.currentUser = user
                            self.isLoggedIn = true
                            self.updateLastLogin(user: user)
                        }
                    } else {
                        self.authError = "No account found with this email"
                    }
                } catch {
                    self.authError = "Error during sign in: \(error.localizedDescription)"
                }
            } else {
                self.authError = "Database error"
            }
            
            self.isLoading = false
        }
    }
    
    // Sign in with Apple method - added to match AuthService implementation
    func signInWithApple(userId: String, email: String?, fullName: String?) {
        isLoading = true
        authError = nil
        
        // Check if this Apple ID is already associated with an account
        checkAppleIdAccount(with: userId) { [weak self] existingUser in
            guard let self = self else { return }
            
            // If user exists, we've already logged them in in the checkAppleIdAccount method
            if existingUser != nil {
                self.isLoading = false
                return
            }
            
            // No existing user, create a new one if we have an email
            if let email = email, !email.isEmpty {
                let newUser = AuthUser(
                    email: email,
                    fullName: fullName,
                    appleIdentifier: userId,
                    role: .standard,
                    isVerified: true, // Apple accounts are pre-verified
                    isTwoFactorEnabled: false // No need for 2FA with Apple Sign In
                )
                
                if let modelContext = self.modelContext {
                    modelContext.insert(newUser)
                    do {
                        try modelContext.save()
                        
                        self.currentUser = newUser
                        self.isLoggedIn = true
                    } catch {
                        self.authError = "Failed to create account: \(error.localizedDescription)"
                    }
                }
            } else {
                // For returning users, Apple might not provide email again
                // Create account with just the Apple ID and a placeholder email
                let placeholderEmail = "apple_user_\(userId.prefix(8))@example.com"
                let newUser = AuthUser(
                    email: placeholderEmail,
                    fullName: fullName,
                    appleIdentifier: userId,
                    role: .standard,
                    isVerified: true,
                    isTwoFactorEnabled: false
                )
                
                if let modelContext = self.modelContext {
                    modelContext.insert(newUser)
                    do {
                        try modelContext.save()
                        
                        self.currentUser = newUser
                        self.isLoggedIn = true
                    } catch {
                        self.authError = "Failed to create account: \(error.localizedDescription)"
                    }
                }
            }
            
            self.isLoading = false
        }
    }
    
    // Verify two-factor code method - added to match AuthService implementation
    func verifyTwoFactorCode() {
        isLoading = true
        
        // Simulate verification delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // In a real app, you would validate the verification code against a saved value
            // or backend service
            
            // For now, we'll simulate a successful verification if the code is "123456"
            if self.verificationCode == "123456" {
                if let modelContext = self.modelContext {
                    do {
                        // Fetch all users instead of using a predicate
                        let descriptor = FetchDescriptor<AuthUser>()
                        let allUsers = try modelContext.fetch(descriptor)
                        
                        // Get the email from the currentUser if available
                        var userToVerify: AuthUser? = nil
                        if let currentUserEmail = self.currentUser?.email {
                            // Find the user with this email
                            userToVerify = allUsers.first { $0.email == currentUserEmail }
                        } else {
                            // Fallback to just taking the first user if we don't have a current user
                            userToVerify = allUsers.first
                        }
                        
                        if let user = userToVerify {
                            // Mark as verified
                            user.isVerified = true
                            
                            // Login successful
                            self.currentUser = user
                            self.isLoggedIn = true
                            self.needsTwoFactor = false
                            self.updateLastLogin(user: user)
                            
                            // Save changes
                            try modelContext.save()
                        } else {
                            self.authError = "User not found"
                        }
                    } catch {
                        self.authError = "Error during verification: \(error.localizedDescription)"
                    }
                }
            } else {
                self.authError = "Invalid verification code"
            }
            
            self.isLoading = false
        }
    }
    
    // Email signup method - added to match AuthService implementation
    func signUpWithEmail(email: String, password: String, fullName: String) {
        isLoading = true
        authError = nil
        
        // Check if email is already in use
        if let modelContext = modelContext {
            do {
                // Get all users and filter in memory
                let descriptor = FetchDescriptor<AuthUser>()
                let allUsers = try modelContext.fetch(descriptor)
                let emailExists = allUsers.contains { user in
                    user.email == email
                }
                
                if emailExists {
                    authError = "Email already in use"
                    isLoading = false
                    return
                }
                
                // Create new user
                let newUser = AuthUser(
                    email: email,
                    fullName: fullName,
                    isTwoFactorEnabled: true
                )
                
                modelContext.insert(newUser)
                try modelContext.save()
                
                // In a real app, you would also store the password securely
                // and send a verification email
                
                // Simulate sending verification email
                sendVerificationEmail(to: email)
                
                // Set current user but don't log in until verified
                currentUser = newUser
                authError = nil
                
                // Success UI update
                isLoading = false
                isRegistrationComplete = true
            } catch {
                authError = "Error during sign up: \(error.localizedDescription)"
                isLoading = false
            }
        } else {
            authError = "Database error"
            isLoading = false
        }
    }
    
    // Sign out method - added to match AuthService implementation
    func signOut() {
        currentUser = nil
        isLoggedIn = false
        needsTwoFactor = false
        verificationCode = ""
        
        // Clear any potentially saved legacy credentials
        KeychainServices.delete(key: "user.data")
    }
    
    // Check Apple ID account - helper for signInWithApple
    private func checkAppleIdAccount(with appleID: String, completion: @escaping (AuthUser?) -> Void) {
        guard let modelContext = modelContext else {
            completion(nil)
            return
        }
        
        do {
            // Get all users and filter in memory instead of using predicate
            let descriptor = FetchDescriptor<AuthUser>()
            let allUsers = try modelContext.fetch(descriptor)
            let matchingUser = allUsers.first { user in
                user.appleIdentifier == appleID
            }
            
            if let user = matchingUser {
                // User found - auto login
                DispatchQueue.main.async {
                    self.currentUser = user
                    self.isLoggedIn = true
                    self.updateLastLogin(user: user)
                }
                completion(user)
            } else {
                // No user found with this Apple ID
                completion(nil)
            }
        } catch {
            print("Error fetching user with Apple ID: \(error)")
            completion(nil)
        }
    }
    
    // Reset app data to factory settings
    func resetAppData() {
        guard let modelContext = modelContext else { return }
        
        // Clear all UserDefaults values
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Reset Keychain items
        KeychainServices.deleteAll()
        
        // Delete all entities from SwiftData
        do {
            // Delete all AuthUsers
            let userDescriptor = FetchDescriptor<AuthUser>()
            let users = try modelContext.fetch(userDescriptor)
            for user in users {
                modelContext.delete(user)
            }
            
            // Delete all vehicles
            let vehicleDescriptor = FetchDescriptor<AppVehicle>()
            let vehicles = try modelContext.fetch(vehicleDescriptor)
            for vehicle in vehicles {
                modelContext.delete(vehicle)
            }
            
            // Delete all inventory items
            let inventoryDescriptor = FetchDescriptor<AppInventoryItem>()
            let inventoryItems = try modelContext.fetch(inventoryDescriptor)
            for item in inventoryItems {
                modelContext.delete(item)
            }
            
            // Delete all warehouses
            let warehouseDescriptor = FetchDescriptor<AppWarehouse>()
            let warehouses = try modelContext.fetch(warehouseDescriptor)
            for warehouse in warehouses {
                modelContext.delete(warehouse)
            }
            
            // Delete all stock location items
            let stockDescriptor = FetchDescriptor<StockLocationItem>()
            let stockItems = try modelContext.fetch(stockDescriptor)
            for item in stockItems {
                modelContext.delete(item)
            }
            
            // Delete all purchase orders
            let poDescriptor = FetchDescriptor<PurchaseOrder>()
            let purchaseOrders = try modelContext.fetch(poDescriptor)
            for po in purchaseOrders {
                modelContext.delete(po)
            }
            
            // Delete all receipts
            let receiptDescriptor = FetchDescriptor<Receipt>()
            let receipts = try modelContext.fetch(receiptDescriptor)
            for receipt in receipts {
                modelContext.delete(receipt)
            }
            
            // Delete all tasks
            let taskDescriptor = FetchDescriptor<AppTask>()
            let tasks = try modelContext.fetch(taskDescriptor)
            for task in tasks {
                modelContext.delete(task)
            }
            
            // Save changes
            try modelContext.save()
            
            // Reset user state
            DispatchQueue.main.async {
                self.currentUser = nil
                self.isLoggedIn = false
                self.authError = nil
                self.isLoading = false
                self.needsTwoFactor = false
            }
            
        } catch {
            print("Error resetting app data: \(error)")
        }
    }
    
    // MARK: - Helper methods
    
    // Send 2FA code (simulated)
    private func sendTwoFactorCode(to email: String) {
        // In a real app, generate and send a code via SMS/email
        print("Sending 2FA code to \(email)")
    }
    
    // Send verification email (simulated)
    private func sendVerificationEmail(to email: String) {
        // In a real app, send verification link
        print("Sending verification email to \(email)")
    }
    
    // Update last login time
    private func updateLastLogin(user: AuthUser) {
        user.lastLogin = Date()
        
        if let modelContext = modelContext {
            do {
                try modelContext.save()
            } catch {
                print("Error updating last login: \(error)")
            }
        }
    }
    
    func clearUserData() {
        guard let modelContext = modelContext else { return }
        
        // Delete all vehicles
        do {
            let vehicleDescriptor = FetchDescriptor<AppVehicle>()
            let vehicles = try modelContext.fetch(vehicleDescriptor)
            for vehicle in vehicles {
                modelContext.delete(vehicle)
            }
            
            // Delete all tasks
            let taskDescriptor = FetchDescriptor<AppTask>()
            let tasks = try modelContext.fetch(taskDescriptor)
            for task in tasks {
                modelContext.delete(task)
            }
            
            // Delete all subtasks
            let subtaskDescriptor = FetchDescriptor<AppSubtask>()
            let subtasks = try modelContext.fetch(subtaskDescriptor)
            for subtask in subtasks {
                modelContext.delete(subtask)
            }
            
            // Delete all staff except current user
            if let currentUser = currentUser {
                // Fetch all users and then filter in memory
                let userDescriptor = FetchDescriptor<AuthUser>()
                let allUsers = try modelContext.fetch(userDescriptor)
                
                // Filter out current user and delete the rest
                for user in allUsers {
                    if user.id != currentUser.id {
                        modelContext.delete(user)
                    }
                }
            }
            
            // Save changes
            try modelContext.save()
        } catch {
            print("Error clearing user data: \(error)")
        }
    }
    
    func clearInventoryData() {
        guard let modelContext = modelContext else { return }
        
        do {
            // Delete all inventory items
            let inventoryDescriptor = FetchDescriptor<AppInventoryItem>()
            let inventoryItems = try modelContext.fetch(inventoryDescriptor)
            for item in inventoryItems {
                modelContext.delete(item)
            }
            
            // Delete all warehouses
            let warehouseDescriptor = FetchDescriptor<AppWarehouse>()
            let warehouses = try modelContext.fetch(warehouseDescriptor)
            for warehouse in warehouses {
                modelContext.delete(warehouse)
            }
            
            // Delete all stock location items
            let stockDescriptor = FetchDescriptor<StockLocationItem>()
            let stockItems = try modelContext.fetch(stockDescriptor)
            for item in stockItems {
                modelContext.delete(item)
            }
            
            // Save changes
            try modelContext.save()
        } catch {
            print("Error clearing inventory data: \(error)")
        }
    }
} 