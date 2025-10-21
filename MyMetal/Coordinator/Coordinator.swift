//
//  MetalErrors.swift
//  MyMetal
//
//  Created by Yauheni Kozich on 21.10.25.
//

import SwiftUI

// MARK: - Coordinator
@MainActor
protocol Coordinator {
    var window: UIWindow? { get set }
    func start()
}

@MainActor
final class CubeCoordinator: Coordinator {
    
    var window: UIWindow?
    
    init(window: UIWindow?) {
        self.window = window
    }
    
    func start() {
            let contentView = CubeMetalView()
            let hostingController = UIHostingController(rootView: contentView)
            window?.rootViewController = hostingController
            window?.makeKeyAndVisible()
    }
    
    private func handleStartupError(_ error: Error) {
        let alert = UIAlertController(title: "Render Error",
                                      message: "Failed to initialize Metal: \(error.localizedDescription)",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        let fallbackView = FallbackContentView()
        let hostingController = UIHostingController(rootView: fallbackView)
        window?.rootViewController = hostingController
        window?.makeKeyAndVisible()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.window?.rootViewController?.present(alert, animated: true)
        }
    }
}

struct FallbackContentView: View {
    var body: some View {
        VStack {
            Text("❌").font(.system(size: 50))
            Text("Metal Not Available").font(.title).foregroundColor(.red)
            Text("This device doesn't support Metal rendering").foregroundColor(.secondary)
        }
    }
}

