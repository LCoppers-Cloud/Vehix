import SwiftUI

struct VehixUserProfileView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("User Profile")
                    .font(.largeTitle)
                    .padding()
                // TODO: Add user profile details and editing options
                Spacer()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    VehixUserProfileView()
} 