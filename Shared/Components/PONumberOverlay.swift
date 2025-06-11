import SwiftUI

struct PONumberOverlay: View {
    let poNumber: String
    let jobAddress: String?
    @State private var isVisible = true
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // PO Number Badge
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PO NUMBER")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text(poNumber)
                                .font(.system(.callout, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    // Job Address (if available)
                    if let address = jobAddress {
                        Text(address)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.6))
                            )
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Spacer()
                    .frame(width: 16)
            }
            
            Spacer()
                .frame(height: 16)
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onAppear {
            pulseAnimation = true
        }
        .onTapGesture {
            withAnimation {
                isVisible.toggle()
            }
            
            // Auto-show after 3 seconds if hidden
            if !isVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isVisible = true
                    }
                }
            }
        }
    }
}



// MARK: - Camera Instructions with PO Number
struct CameraInstructionsOverlay: View {
    let poNumber: String
    @State private var showInstructions = true
    
    var body: some View {
        VStack {
            Spacer()
            
            if showInstructions {
                VStack(spacing: 16) {
                    // PO Number Reminder
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scanning for PO:")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text(poNumber)
                                .font(.system(.callout, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.9))
                    )
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("📸 Receipt Scanning Tips:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Keep receipt flat and well-lit")
                            Text("• Ensure all text is visible")
                            Text("• Tap anywhere to capture")
                            Text("• Multiple receipts OK")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.7))
                    )
                    
                    // Dismiss Button
                    Button("Got it!") {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showInstructions = false
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
                .padding(.horizontal, 20)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .bottom))
                ))
            }
            
            Spacer()
                .frame(height: 40)
        }
    }
}

#if DEBUG
struct PONumberOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                PONumberOverlay(
                    poNumber: "JOB123-20240115-001",
                    jobAddress: "123 Main St, Anytown USA"
                )
                
                Spacer()
                
                EnhancedPONumberDisplay(
                    poNumber: "JOB123-20240115-001",
                    jobAddress: "123 Main St, Anytown USA",
                    receiptsCount: 3
                )
                .padding()
                
                Spacer()
            }
        }
    }
}
#endif 