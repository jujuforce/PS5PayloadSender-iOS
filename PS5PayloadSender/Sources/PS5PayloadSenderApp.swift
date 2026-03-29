import SwiftUI

@main
struct PS5PayloadSenderApp: App {
    @State private var showSplash = true
    @State private var store = PayloadStore()

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showSplash = false
                            }
                        }
                    }
            } else {
                ContentView()
                    .environment(store)
                    .transition(.opacity)
            }
        }
    }
}
