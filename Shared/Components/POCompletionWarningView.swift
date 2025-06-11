import SwiftUI

struct POCompletionWarningView: View {
    let onComplete: () -> Void
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var showConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning Icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                        .padding(.top, 20)
                    
                    // Warning Title
                    Text("Purchase Order In Progress")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Warning Message
                    VStack(alignment: .leading, spacing: 16) {
                        Text("You have an incomplete Purchase Order that needs to be finished before starting a new one.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                Text("Job address selected")
                            }
                            
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(.orange)
                                Text("Receipt scanning required")
                            }
                            
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(.orange)
                                Text("Purchase order submission pending")
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Continue Current PO Button
                        Button(action: {
                            onContinue()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Continue Current Purchase Order")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        // Complete and Start New Button
                        Button(action: {
                            showConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Complete Current & Start New")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        // Cancel Button
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Cancel")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Warning")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
        .interactiveDismissDisabled()
        .alert("Complete Current Purchase Order", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Complete", role: .destructive) {
                onComplete()
                dismiss()
            }
        } message: {
            Text("This will mark the current Purchase Order as complete and allow you to start a new one. This action cannot be undone.")
        }
    }
}



#if DEBUG
struct POCompletionWarningView_Previews: PreviewProvider {
    static var previews: some View {
        POCompletionWarningView(
            onComplete: { print("Complete") },
            onContinue: { print("Continue") }
        )
    }
}
#endif 