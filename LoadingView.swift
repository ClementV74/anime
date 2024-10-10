import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.blue, .purple]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2.5)
                    .shadow(radius: 10)
                    .rotationEffect(Angle(degrees: 360))
                    .animation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false), value: UUID())
                
                Text("Chargement...")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Veuillez patienter")
                    .foregroundColor(.white)
                    .opacity(0.8)
            }
            .padding()
        }
    }
}

