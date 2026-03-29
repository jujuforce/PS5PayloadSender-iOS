import SwiftUI

struct SplashScreenView: View {
    @State private var opacity = 0.0
    @State private var scale = 0.8

    var body: some View {
        AppBackground()
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1.0
                scale = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
