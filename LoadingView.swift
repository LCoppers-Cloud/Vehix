import SwiftUI

public struct LoadingView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authService: AppAuthService
    @Binding var isFinishedLoading: Bool
    
    @State private var rotationAngle: Double = 0
    @State private var progress: Double = 0
    
    public var body: some View {
        ZStack {
            // Background color matches app icon (adjust if you have a specific color code)
            Color(red: 35/255, green: 35/255, blue: 36/255).ignoresSafeArea()
            
            // Subtle background logo (optional, can be removed if you want only the button look)
            Image(colorScheme == .dark ? "Vehix Dark" : "Vehix Light")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 400, height: 400)
                .opacity(0.06)
                .blur(radius: 4)
                .offset(y: 60)
            
            VStack(spacing: 32) {
                // Crisp, button-style logo
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.10))
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 8)
                    Image(colorScheme == .dark ? "Vehix Dark" : "Vehix Light")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .white.opacity(0.10), radius: 4, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 2)
                        )
                }
                .padding(.top, 32)
                
                // App name
                Text("VEHIX")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                // Loading spinner
                ZStack {
                    Circle()
                        .stroke(lineWidth: 4)
                        .opacity(0.3)
                        .foregroundColor(Color(red: 0.2, green: 0.5, blue: 0.9))
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(Color(red: 0.2, green: 0.5, blue: 0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(Angle(degrees: rotationAngle))
                    ForEach(0..<3) { index in
                        let indexAngle = 2 * .pi * Double(index) / 3
                        let rotationInRadians = rotationAngle / 180 * .pi
                        let combinedAngle = indexAngle + rotationInRadians
                        let xPosition = 22 * cos(combinedAngle)
                        let yPosition = 22 * sin(combinedAngle)
                        Circle()
                            .fill(Color(red: 0.2, green: 0.5, blue: 0.9))
                            .frame(width: 10, height: 10)
                            .offset(x: xPosition, y: yPosition)
                    }
                }
                .padding(.top, 8)
                
                // Progress bar and percentage
                VStack(spacing: 8) {
                    ProgressView(value: min(max(progress, 0), 1))
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.blue))
                        .frame(width: 180)
                    Text("Loading... \(Int(progress * 100))%")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.top, 8)
                
                Spacer()
            }
        }
        .onAppear {
            // Start rotation animation
            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            // Simulate loading process
            Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { timer in
                progress += 0.01
                if progress >= 1.0 {
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            print("Loading complete - transitioning to main app")
                            isFinishedLoading = true
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var isFinishedLoading = false
        var body: some View {
            LoadingView(isFinishedLoading: $isFinishedLoading)
                .environmentObject(AppAuthService())
        }
    }
    return PreviewWrapper()
} 