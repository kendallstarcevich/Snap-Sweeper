//
//  AuthManager.swift
//  Snap Sweeper
//
//  Created by Kendall Starcevich on 4/7/26.
//

import LocalAuthentication
import Combine

class AuthManager: ObservableObject {
    @Published var isUnlocked = false
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is even available (FaceID, TouchID, or Passcode)
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Unlock your Protected Vault"

            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                    } else {
                        // Handle failure (e.g., user cancelled)
                        print("Authentication failed")
                    }
                }
            }
        } else {
            // No biometrics available (Device has no passcode or hardware is broken)
            print("Biometrics not available: \(error?.localizedDescription ?? "Unknown error")")
            // Optional: Fallback to allowing access or showing an alert
        }
    }
    
    func lock() {
        isUnlocked = false
    }
}
