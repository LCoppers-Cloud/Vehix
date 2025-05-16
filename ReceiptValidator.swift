import Foundation
import StoreKit

/// Receipt validation service for App Store purchases
class ReceiptValidator {
    
    /// Shared instance of the validator
    static let shared = ReceiptValidator()
    
    /// Production App Store verification URL
    private let verificationURLProduction = URL(string: "https://buy.itunes.apple.com/verifyReceipt")!
    
    /// Sandbox App Store verification URL
    private let verificationURLSandbox = URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")!
    
    /// Your server's receipt validation endpoint (replace with your actual server URL)
    private let serverValidationURL = URL(string: "https://api.yourserver.com/validate-receipt")!
    
    /// App's shared secret (should be stored on server in production)
    private var sharedSecret: String {
        // In production, this should not be in the app but only on your server
        // This is just a placeholder to show the structure of the receipt validation
        return KeychainServices.get(key: "appstore.shared.secret") ?? ""
    }
    
    private init() {}
    
    /// Validate the App Store receipt with Apple's servers
    /// - Parameters:
    ///   - completion: Callback with validation result
    func validateReceipt(completion: @escaping (Bool, String?) -> Void) {
        // For iOS 18 and above: use the new StoreKit APIs
        if #available(iOS 18.0, *) {
            Task {
                do {
                    // Get the current app transaction and its verification
                    let verificationResult = try await AppTransaction.shared
                    
                    // Switch directly on the verification result
                    switch verificationResult {
                    case .verified(_):
                        // Receipt is valid
                        completion(true, nil)
                    case .unverified(_, let error):
                        // Receipt verification failed
                        completion(false, "Receipt verification failed: \(error.localizedDescription)")
                    }
                } catch {
                    completion(false, "Failed to get app transaction: \(error.localizedDescription)")
                }
            }
        } else {
            // For older iOS versions, use the legacy approach
            // Load the receipt from the app bundle
            guard let receiptURL = Bundle.main.appStoreReceiptURL,
                  let receiptData = try? Data(contentsOf: receiptURL) else {
                completion(false, "Receipt not found")
                return
            }
            
            // Base64 encode the receipt data
            let receipt = receiptData.base64EncodedString()
            
            // Process the receipt
            if shouldUseServerValidation() {
                validateWithServer(receipt: receipt, completion: completion)
            } else {
                validateWithAppStore(receipt: receipt, completion: completion)
            }
        }
    }
    
    /// Validate a receipt directly with the App Store
    /// Note: In production apps, this should be done server-side
    /// - Parameters:
    ///   - receipt: Base64 encoded receipt data
    ///   - completion: Callback with validation result
    private func validateWithAppStore(receipt: String, completion: @escaping (Bool, String?) -> Void) {
        // Prepare the receipt validation payload
        let requestData: [String: Any] = [
            "receipt-data": receipt,
            "password": sharedSecret, // Your app's shared secret
            "exclude-old-transactions": true
        ]
        
        guard let requestDataJSON = try? JSONSerialization.data(withJSONObject: requestData) else {
            completion(false, "Failed to create receipt validation payload")
            return
        }
        
        // Start with production URL
        var request = URLRequest(url: verificationURLProduction)
        request.httpMethod = "POST"
        request.httpBody = requestDataJSON
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the validation task
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                completion(false, "Receipt validation failed: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                completion(false, "No data received from App Store")
                return
            }
            
            // Parse the response
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = jsonResponse["status"] as? Int {
                    
                    if status == 0 {
                        // Receipt is valid for production
                        self.handleValidReceipt(jsonResponse, completion: completion)
                    } else if status == 21007 {
                        // Receipt is from sandbox, retry with sandbox URL
                        self.validateWithSandbox(receipt: receipt, completion: completion)
                    } else {
                        // Receipt is invalid or has another issue
                        completion(false, "Receipt validation failed: status code \(status)")
                    }
                } else {
                    completion(false, "Invalid response from App Store")
                }
            } catch {
                completion(false, "Failed to parse receipt validation response: \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }
    
    /// Validate with the sandbox environment (for test receipts)
    private func validateWithSandbox(receipt: String, completion: @escaping (Bool, String?) -> Void) {
        // Prepare the receipt validation payload
        let requestData: [String: Any] = [
            "receipt-data": receipt,
            "password": sharedSecret,
            "exclude-old-transactions": true
        ]
        
        guard let requestDataJSON = try? JSONSerialization.data(withJSONObject: requestData) else {
            completion(false, "Failed to create receipt validation payload")
            return
        }
        
        // Use sandbox URL
        var request = URLRequest(url: verificationURLSandbox)
        request.httpMethod = "POST"
        request.httpBody = requestDataJSON
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the validation task
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                completion(false, "Sandbox receipt validation failed: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                completion(false, "No data received from App Store sandbox")
                return
            }
            
            // Parse the response
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = jsonResponse["status"] as? Int {
                    
                    if status == 0 {
                        // Receipt is valid for sandbox
                        self.handleValidReceipt(jsonResponse, completion: completion)
                    } else {
                        // Receipt is invalid
                        completion(false, "Sandbox receipt validation failed: status code \(status)")
                    }
                } else {
                    completion(false, "Invalid response from App Store sandbox")
                }
            } catch {
                completion(false, "Failed to parse sandbox receipt validation response: \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }
    
    /// Validate the receipt with your own server (recommended for production)
    private func validateWithServer(receipt: String, completion: @escaping (Bool, String?) -> Void) {
        // Prepare the receipt validation payload
        let requestData: [String: Any] = [
            "receipt-data": receipt,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "device_id": UIDevice.current.identifierForVendor?.uuidString ?? ""
        ]
        
        guard let requestDataJSON = try? JSONSerialization.data(withJSONObject: requestData) else {
            completion(false, "Failed to create server validation payload")
            return
        }
        
        // Create server request
        var request = URLRequest(url: serverValidationURL)
        request.httpMethod = "POST"
        request.httpBody = requestDataJSON
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication for your server if required
        let apiKey = KeychainServices.get(key: "server.api.key") ?? ""
        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Create the validation task
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(false, "Server validation failed: \(error.localizedDescription)")
                return
            }
            
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(false, "Invalid response from server")
                return
            }
            
            // Parse the response from your server
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let isValid = jsonResponse["is_valid"] as? Bool {
                    completion(isValid, isValid ? nil : "Receipt rejected by server")
                } else {
                    completion(false, "Invalid response format from server")
                }
            } catch {
                completion(false, "Failed to parse server response: \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }
    
    /// Process a valid receipt response
    private func handleValidReceipt(_ receiptInfo: [String: Any], completion: @escaping (Bool, String?) -> Void) {
        // Check if there are valid subscriptions
        if let latestReceiptInfo = receiptInfo["latest_receipt_info"] as? [[String: Any]] {
            // Find the latest subscription receipt
            let validSubscriptions = latestReceiptInfo.filter { receipt in
                // Check if the subscription is still active
                if let expiresDateMs = receipt["expires_date_ms"] as? String,
                   let expiresDateTimestamp = Double(expiresDateMs) {
                    let expirationDate = Date(timeIntervalSince1970: expiresDateTimestamp / 1000)
                    return expirationDate > Date()
                }
                return false
            }
            
            if !validSubscriptions.isEmpty {
                completion(true, nil)
                return
            }
        }
        
        // Check in-app purchases if no valid subscriptions found
        if let receiptDict = receiptInfo["receipt"] as? [String: Any],
           let inAppPurchases = receiptDict["in_app"] as? [[String: Any]] {
            let validPurchases = inAppPurchases.filter { receipt in
                // Check if the purchase has not been canceled
                let cancellationDate = receipt["cancellation_date"] as? String
                return cancellationDate == nil
            }
            
            if !validPurchases.isEmpty {
                completion(true, nil)
                return
            }
        }
        
        // No valid subscriptions or purchases found
        completion(false, "No active subscriptions found")
    }
    
    /// Determine if we should use server-side validation
    private func shouldUseServerValidation() -> Bool {
        // In production, you should always use server validation
        // For development, you might use direct validation for testing
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
} 