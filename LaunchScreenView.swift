import SwiftUI

public struct LaunchScreenView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0.0
    
    public var body: some View {
        ZStack {
            Color(red: 35/255, green: 35/255, blue: 36/255).ignoresSafeArea()
            VStack {
                Spacer()
                Image(colorScheme == .dark ? "Vehix Dark" : "Vehix Light")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 220, height: 220)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.0)) {
                            logoScale = 1.0
                            logoOpacity = 1.0
                        }
                    }
                Spacer()
                Text("© L.Coppers 2025")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 32)
            }
        }
    }
}

#Preview {
    LaunchScreenView()
} 