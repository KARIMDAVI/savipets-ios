//
//  SaviPetsApp.swift
//  SaviPets
//
//  Created by K!MO on 9/21/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
	func application(_ application: UIApplication,
				   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		FirebaseApp.configure()

		// Configure Google Sign-In using the client ID from Firebase options
		if let clientID = FirebaseApp.app()?.options.clientID {
			GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
		} else {
			assertionFailure("Missing Firebase clientID. Ensure GoogleService-Info.plist is included or set GIDClientID in Info.plist.")
		}

		return true
	}

	// Provide a UIScene configuration that uses our SceneDelegate to handle URL opens.
	func application(_ application: UIApplication,
					 configurationForConnecting connectingSceneSession: UISceneSession,
					 options: UIScene.ConnectionOptions) -> UISceneConfiguration {
		let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
		config.delegateClass = SceneDelegate.self
		return config
	}
}

// Scene delegate to handle URL openings using the UIScene lifecycle.
class SceneDelegate: NSObject, UIWindowSceneDelegate {
	func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
		guard let url = URLContexts.first?.url else { return }
		_ = GIDSignIn.sharedInstance.handle(url)
	}
}

@main
struct SaviPetsApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()

	var body: some Scene {
		WindowGroup {
			SavSplash()
				.environmentObject(appState)
                .environmentObject(appState.chatService)
		}
	}
}
