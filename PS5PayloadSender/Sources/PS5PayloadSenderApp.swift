import UIKit
import SwiftUI

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    // `@main` on a class requires this entry-point method.
    static func main() {
        UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(Self.self))
    }

    var window: UIWindow?
    private let store = PayloadStore()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let rootView = AppRootView().environmentObject(store)
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIHostingController(rootView: rootView)
        window?.makeKeyAndVisible()
        return true
    }
}

// MARK: - Root view (handles splash → content transition)

private struct AppRootView: View {
    @State private var showSplash = true

    var body: some View {
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
                .transition(.opacity)
        }
    }
}
