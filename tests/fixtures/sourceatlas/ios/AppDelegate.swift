import UIKit
import Combine

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    private var cancellables = Set<AnyCancellable>()
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize app
        setupDependencies()
        configureAppearance()
        return true
    }
    
    private func setupDependencies() {
        // Setup DI container
        print("Setting up dependencies")
    }
    
    internal func configureAppearance() {
        // Configure global appearance
        UINavigationBar.appearance().tintColor = .systemBlue
    }
    
    public func applicationDidBecomeActive(_ application: UIApplication) {
        // Handle app becoming active
    }
}