import Foundation
import SwiftData

// Import centralized ServiceTitan models
// (All ServiceTitan models are now in ServiceTitanModels.swift)

// MARK: - ServiceTitan API Service

@Observable
class ServiceTitanAPIService {
    // MARK: - Properties
    var isAuthenticated: Bool = false
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiryDate: Date?
    
    // Configuration
    private let baseURL: String
    private let clientId: String
    private let clientSecret: String
    private let environment: Environment
    
    enum Environment {
        case integration
        case production
        
        var baseURL: String {
            switch self {
            case .integration:
                return "https://integration-api.servicetitan.io"
            case .production:
                return "https://api.servicetitan.io"
            }
        }
    }
    
    // MARK: - Initialization
    
    init(environment: Environment = .integration, clientId: String, clientSecret: String) {
        self.environment = environment
        self.baseURL = environment.baseURL
        self.clientId = clientId
        self.clientSecret = clientSecret
        
        // Load saved credentials
        loadCredentials()
    }
    
    // MARK: - Authentication
    
    func authenticate(code: String) async throws {
        let url = URL(string: "\(baseURL)/auth/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServiceTitanAPIError.authenticationFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        self.isAuthenticated = true
        
        saveCredentials()
    }
    
    // MARK: - API Request Helper
    
    private func makeAPIRequest<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        guard let token = accessToken else {
            throw ServiceTitanAPIError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceTitanAPIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            // Token expired, try to refresh
            try await refreshAccessToken()
            return try await makeAPIRequest(endpoint: endpoint, method: method, body: body)
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw ServiceTitanAPIError.apiError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Technician Management
    
    func fetchTechnicians() async -> [ServiceTitanAPITechnician] {
        do {
            let response: ServiceTitanResponse<ServiceTitanAPITechnician> = try await makeAPIRequest(
                endpoint: "/v2/technicians?active=true"
            )
            return response.data
        } catch {
            print("Failed to fetch technicians: \(error)")
            return []
        }
    }
    
    func fetchTechnicianJobs(technicianId: Int, from: Date = Date(), to: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()) async -> [ServiceTitanJob] {
        do {
            let dateFormatter = ISO8601DateFormatter()
            let fromString = dateFormatter.string(from: from)
            let toString = dateFormatter.string(from: to)
            
            let response: ServiceTitanResponse<ServiceTitanJob> = try await makeAPIRequest(
                endpoint: "/v2/jobs?technicianIds=\(technicianId)&scheduledStart=\(fromString)&scheduledEnd=\(toString)"
            )
            
            // Get detailed job information
            var detailedJobs: [ServiceTitanJob] = []
            for job in response.data {
                if let detailedJob = await fetchJobDetails(jobId: Int(job.id) ?? 0) {
                    detailedJobs.append(detailedJob)
                }
            }
            
            return detailedJobs
        } catch {
            print("Failed to fetch technician jobs: \(error)")
            return []
        }
    }
    
    func fetchJobDetails(jobId: Int) async -> ServiceTitanJob? {
        do {
            let job: ServiceTitanJob = try await makeAPIRequest(
                endpoint: "/v2/jobs/\(jobId)"
            )
            return job
        } catch {
            print("Failed to fetch job details for \(jobId): \(error)")
            return nil
        }
    }
    
    // MARK: - Purchase Order Management
    
    func createPurchaseOrder(
        technicianId: Int,
        jobId: Int,
        vendor: String,
        amount: Double,
        items: [PurchaseOrderItem]
    ) async -> Bool {
        do {
            let po = CreatePurchaseOrderRequest(
                technicianId: technicianId,
                jobId: jobId,
                vendor: vendor,
                total: amount,
                items: items
            )
            
            let body = try JSONEncoder().encode(po)
            let _: CreatePurchaseOrderResponse = try await makeAPIRequest(
                endpoint: "/v2/purchase-orders",
                method: "POST",
                body: body
            )
            
            return true
        } catch {
            print("Failed to create purchase order: \(error)")
            return false
        }
    }
    
    func uploadReceiptToJob(jobId: Int, imageData: Data, filename: String) async -> Bool {
        do {
            let attachment = JobAttachment(
                name: filename,
                type: "image/jpeg",
                data: imageData.base64EncodedString()
            )
            
            let body = try JSONEncoder().encode(attachment)
            let _: [String: String] = try await makeAPIRequest(
                endpoint: "/v2/jobs/\(jobId)/attachments",
                method: "POST",
                body: body
            )
            
            return true
        } catch {
            print("Failed to upload receipt to job: \(error)")
            return false
        }
    }
    
    // MARK: - Account Synchronization
    
    func syncTechniciansWithAppUsers(appUsers: [AuthUser]) async -> [TechnicianMatch] {
        let technicians = await fetchTechnicians()
        var matches: [TechnicianMatch] = []
        
        for appUser in appUsers {
            if let match = findBestMatch(appUser: appUser, technicians: technicians) {
                matches.append(match)
            } else {
                // No match found
                matches.append(TechnicianMatch(
                    appUser: appUser,
                    serviceTitanTechId: nil,
                    serviceTitanTech: nil,
                    serviceTitanTechName: nil,
                    confidence: 0.0,
                    matchMethod: TechnicianMatch.MatchMethod.none,
                    reasons: ["No matching technician found in ServiceTitan"],
                    needsManualReview: true
                ))
            }
        }
        
        return matches
    }
    
    private func findBestMatch(appUser: AuthUser, technicians: [ServiceTitanAPITechnician]) -> TechnicianMatch? {
        var bestMatch: ServiceTitanAPITechnician?
        var bestScore: Double = 0.0
        
        for tech in technicians {
            let score = calculateMatchScore(appUser: appUser, technician: tech)
            if score > bestScore && score > 0.5 { // Minimum threshold
                bestScore = score
                bestMatch = tech
            }
        }
        
        guard let match = bestMatch else { return nil }
        
        // Determine match method and confidence
        let emailMatch = match.email.lowercased() == appUser.email.lowercased()
        let _ = appUser.fullName?.lowercased().contains(match.name.lowercased()) == true ||
                       match.name.lowercased().contains(appUser.fullName?.lowercased() ?? "")
        
        return TechnicianMatch(
            appUser: appUser,
            serviceTitanTechId: match.id,
            serviceTitanTech: match,
            serviceTitanTechName: match.name,
            confidence: bestScore,
            matchMethod: emailMatch ? TechnicianMatch.MatchMethod.email : TechnicianMatch.MatchMethod.name,
            reasons: emailMatch ? ["Email exact match"] : ["Name similarity match"],
            needsManualReview: bestScore < 0.85
        )
    }
    
    private func calculateMatchScore(appUser: AuthUser, technician: ServiceTitanAPITechnician) -> Double {
        var score: Double = 0.0
        
        // Email matching (highest weight)
        if technician.email.lowercased() == appUser.email.lowercased() {
            score += 0.8
        }
        
        // Name matching
        if let userFullName = appUser.fullName {
            let techName = technician.name.lowercased()
            let userName = userFullName.lowercased()
            
            if techName == userName {
                score += 0.6
            } else if techName.contains(userName) || userName.contains(techName) {
                score += 0.4
            }
        }
        
        // Phone matching (AuthUser doesn't have phoneNumber, so skip this for now)
        // if let techPhone = technician.phone, techPhone == appUser.phoneNumber {
        //     score += 0.3
        // }
        
        return min(score, 1.0)
    }
    
    // MARK: - Token Management
    
    private func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw ServiceTitanAPIError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/auth/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
            "client_secret": clientSecret
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServiceTitanAPIError.authenticationFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        saveCredentials()
    }
    
    // MARK: - Persistence
    
    private func saveCredentials() {
        UserDefaults.standard.set(accessToken, forKey: "servicetitan_access_token")
        UserDefaults.standard.set(refreshToken, forKey: "servicetitan_refresh_token")
        UserDefaults.standard.set(tokenExpiryDate, forKey: "servicetitan_token_expiry")
    }
    
    private func loadCredentials() {
        accessToken = UserDefaults.standard.string(forKey: "servicetitan_access_token")
        refreshToken = UserDefaults.standard.string(forKey: "servicetitan_refresh_token")
        tokenExpiryDate = UserDefaults.standard.object(forKey: "servicetitan_token_expiry") as? Date
        
        // Check if token is still valid
        if let expiryDate = tokenExpiryDate, expiryDate > Date() {
            isAuthenticated = accessToken != nil
        } else {
            isAuthenticated = false
        }
    }
}