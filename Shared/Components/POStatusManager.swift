import Foundation
import SwiftUI

// MARK: - Purchase Order Status Manager
@MainActor
class POStatusManager: ObservableObject {
    @Published var hasIncompletePO: Bool = false
    @Published var currentPONumber: String?
    @Published var currentJobAddress: String?
    @Published var receiptsCount: Int = 0
    
    private let userDefaults = UserDefaults.standard
    private let currentPOKey = "current_po_number"
    private let currentJobKey = "current_job_address"
    private let receiptsCountKey = "current_po_receipts_count"
    private let draftDirKey = "po_draft_directory"
    
    init() {
        loadCurrentPOStatus()
    }
    
    private func loadCurrentPOStatus() {
        currentPONumber = userDefaults.string(forKey: currentPOKey)
        currentJobAddress = userDefaults.string(forKey: currentJobKey)
        receiptsCount = userDefaults.integer(forKey: receiptsCountKey)
        hasIncompletePO = currentPONumber != nil
    }
    
    func startNewPO(poNumber: String, jobAddress: String) {
        currentPONumber = poNumber
        currentJobAddress = jobAddress
        receiptsCount = 0
        hasIncompletePO = true
        
        userDefaults.set(poNumber, forKey: currentPOKey)
        userDefaults.set(jobAddress, forKey: currentJobKey)
        userDefaults.set(0, forKey: receiptsCountKey)
        
        // Create draft directory
        createDraftDirectory()
        
        print("📝 Started new PO: \(poNumber) for \(jobAddress)")
    }
    
    func addReceipt() {
        receiptsCount += 1
        userDefaults.set(receiptsCount, forKey: receiptsCountKey)
        print("📄 Added receipt #\(receiptsCount) to PO: \(currentPONumber ?? "Unknown")")
    }
    
    func completePO() {
        print("✅ Completed PO: \(currentPONumber ?? "Unknown")")
        
        // Clear all PO tracking data
        currentPONumber = nil
        currentJobAddress = nil
        receiptsCount = 0
        hasIncompletePO = false
        
        userDefaults.removeObject(forKey: currentPOKey)
        userDefaults.removeObject(forKey: currentJobKey)
        userDefaults.removeObject(forKey: receiptsCountKey)
        
        // Clean up draft directory
        cleanupDraftDirectory()
    }
    
    private func createDraftDirectory() {
        guard let poNumber = currentPONumber else { return }
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let draftURL = documentsURL.appendingPathComponent("PO_Drafts/\(poNumber)")
        
        do {
            try fileManager.createDirectory(at: draftURL, withIntermediateDirectories: true, attributes: nil)
            userDefaults.set(draftURL.path, forKey: draftDirKey)
            print("📁 Created draft directory: \(draftURL.path)")
        } catch {
            print("❌ Failed to create draft directory: \(error)")
        }
    }
    
    private func cleanupDraftDirectory() {
        guard let draftPath = userDefaults.string(forKey: draftDirKey) else { return }
        
        let fileManager = FileManager.default
        let draftURL = URL(fileURLWithPath: draftPath)
        
        do {
            try fileManager.removeItem(at: draftURL)
            userDefaults.removeObject(forKey: draftDirKey)
            print("🗑️ Cleaned up draft directory: \(draftPath)")
        } catch {
            print("⚠️ Failed to cleanup draft directory: \(error)")
        }
    }
    
    func getDraftDirectory() -> URL? {
        guard let draftPath = userDefaults.string(forKey: draftDirKey) else { return nil }
        return URL(fileURLWithPath: draftPath)
    }
    
    func saveReceiptImage(_ image: UIImage, receiptNumber: Int) -> URL? {
        guard let draftDir = getDraftDirectory() else { return nil }
        
        let receiptURL = draftDir.appendingPathComponent("receipt_\(receiptNumber).jpg")
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            do {
                try imageData.write(to: receiptURL)
                print("💾 Saved receipt image: \(receiptURL.lastPathComponent)")
                return receiptURL
            } catch {
                print("❌ Failed to save receipt image: \(error)")
            }
        }
        
        return nil
    }
    
    func getReceiptImages() -> [URL] {
        guard let draftDir = getDraftDirectory() else { return [] }
        
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(at: draftDir, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension.lowercased() == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            print("❌ Failed to get receipt images: \(error)")
            return []
        }
    }
}

// MARK: - Enhanced PO Number Display
struct EnhancedPONumberDisplay: View {
    let poNumber: String
    let jobAddress: String?
    let receiptsCount: Int
    
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 12) {
            // PO Number Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PURCHASE ORDER")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text(poNumber)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                }
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    Text("IN PROGRESS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Job Information
            if let address = jobAddress {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .frame(width: 16)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("JOB LOCATION")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
            }
            
            // Receipt Count
            HStack {
                Image(systemName: receiptsCount > 0 ? "doc.text.fill" : "doc.text")
                    .foregroundColor(receiptsCount > 0 ? .green : .secondary)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("RECEIPTS CAPTURED")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("\(receiptsCount) receipt\(receiptsCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(receiptsCount > 0 ? .green : .secondary)
                        .fontWeight(receiptsCount > 0 ? .medium : .regular)
                }
                
                Spacer()
                
                if receiptsCount > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            pulseAnimation = true
        }
    }
}

// MARK: - PO Progress Indicator
struct POProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let stepTitles: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(currentStep)/\(totalSteps)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * (Double(currentStep) / Double(totalSteps)), height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 4)
            
            // Current Step
            if currentStep <= stepTitles.count {
                Text(stepTitles[currentStep - 1])
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal)
    }
} 