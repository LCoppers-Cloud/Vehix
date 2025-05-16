import SwiftUI

struct VendorEmailTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    
    let vendor: AppVendor
    let items: [AppInventoryItem]
    
    @State private var selectedTemplate = 0
    @State private var customMessage = ""
    @State private var showingPreview = false
    @State private var showingSendConfirmation = false
    
    let templates = [
        "Order Request",
        "Price Quote Request",
        "Account Update",
        "Custom Message"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Email Template")) {
                    Picker("Template", selection: $selectedTemplate) {
                        ForEach(0..<templates.count, id: \.self) { index in
                            Text(templates[index])
                                .tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                if selectedTemplate == templates.count - 1 {
                    Section(header: Text("Custom Message")) {
                        TextEditor(text: $customMessage)
                            .frame(height: 150)
                    }
                }
                
                Section(header: Text("Preview")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("To: \(vendor.name)")
                            .font(.headline)
                        
                        Text(generateEmailBody())
                            .font(.body)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button(action: {
                        showingSendConfirmation = true
                    }) {
                        Label("Send Email", systemImage: "envelope")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Email Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Send Email", isPresented: $showingSendConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Send") {
                    sendEmail()
                }
            } message: {
                Text("Send this email to \(vendor.name)?")
            }
        }
    }
    
    private func generateEmailBody() -> String {
        switch selectedTemplate {
        case 0: // Order Request
            return """
            Dear \(vendor.name),
            
            We would like to place an order for the following items:
            
            \(items.map { item in 
                let totalQty = item.totalQuantity
                return "• \(item.name) - Quantity: \(totalQty)"
            }.joined(separator: "\n"))
            
            Please provide availability and pricing at your earliest convenience.
            
            Best regards,
            [Your Company Name]
            """
            
        case 1: // Price Quote Request
            return """
            Dear \(vendor.name),
            
            We are requesting current pricing for the following items:
            
            \(items.map { "• \($0.name)" }.joined(separator: "\n"))
            
            Please include any available volume discounts and current lead times.
            
            Thank you,
            [Your Company Name]
            """
            
        case 2: // Account Update
            return """
            Dear \(vendor.name),
            
            We are updating our vendor records and would appreciate if you could confirm or update the following information:
            
            • Contact Email: \(vendor.email)
            \(vendor.phone != nil ? "• Phone: \(vendor.phone!)" : "")
            \(vendor.address != nil ? "• Address: \(vendor.address!)" : "")
            
            Please let us know if any changes are needed.
            
            Best regards,
            [Your Company Name]
            """
            
        case 3: // Custom Message
            return customMessage
            
        default:
            return ""
        }
    }
    
    private func sendEmail() {
        // In a real app, this would send the email
        // For now, we'll just simulate it
        print("Sending email to \(vendor.name):")
        print(generateEmailBody())
        
        // Show success and dismiss
        dismiss()
    }
} 