import FirebaseAuth
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import UIKit
import Observation

@Observable
final class AuthRepository: NSObject {
    private(set) var currentUser: FirebaseAuth.User? = Auth.auth().currentUser

    @ObservationIgnored private var authHandle: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private var currentNonce: String?

    override init() {
        super.init()
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
        }
    }

    deinit {
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
    }

    // MARK: - Sign in with Apple

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func handleAppleSignIn(_ authorization: ASAuthorization) async throws -> FirebaseAuth.User {
        guard
            let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = appleCredential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else {
            throw AuthError.missingToken
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )
        let result = try await Auth.auth().signIn(with: credential)
        // Apple only sends the name on first sign-in — persist it to Firebase profile
        if let fullName = appleCredential.fullName {
            let displayName = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }.joined(separator: " ")
            if !displayName.isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try? await changeRequest.commitChanges()
            }
        }
        return result.user
    }

    // MARK: - Sign in with Google

    @MainActor
    func signInWithGoogle() async throws -> FirebaseAuth.User {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = windowScene.windows.first?.rootViewController
        else {
            throw AuthError.noRootViewController
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Delete Account (re-auths if needed)

    @MainActor
    func deleteAccount(provider: AuthProviderID) async throws {
        guard let user = Auth.auth().currentUser else { throw AuthError.notSignedIn }
        switch provider {
        case .apple:
            let (credential, authCode) = try await reAuthWithApple()
            try await Auth.auth().signIn(with: credential)
            // Revoke Apple token — required by App Store guidelines and resets
            // Apple's authorization so the name is shown again on next sign-in
            try await Auth.auth().revokeToken(withAuthorizationCode: authCode)
            try await Auth.auth().currentUser?.delete()
        case .google:
            _ = try await signInWithGoogle()
            try await Auth.auth().currentUser?.delete()
        default:
            try await user.delete()
        }
    }

    private func reAuthWithApple() async throws -> (AuthCredential, String) {
        return try await withCheckedThrowingContinuation { continuation in
            let nonce = randomNonceString()
            currentNonce = nonce
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let handler = AppleReAuthHandler(nonce: nonce) { result in
                continuation.resume(with: result)
            }
            controller.delegate = handler
            controller.presentationContextProvider = self
            controller.performRequests()
            objc_setAssociatedObject(controller, "handler", handler, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var byte: UInt8 = 0
                SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
                return byte
            }
            randoms.forEach { byte in
                guard remaining > 0 else { return }
                if byte < charset.count { result.append(charset[Int(byte)]); remaining -= 1 }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Presentation context

extension AuthRepository: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? UIWindow()
    }
}

// MARK: - Re-auth helper (separate delegate object to avoid retain cycles)

private final class AppleReAuthHandler: NSObject, ASAuthorizationControllerDelegate {
    private let nonce: String
    private let completion: (Result<(AuthCredential, String), Error>) -> Void

    init(nonce: String, completion: @escaping (Result<(AuthCredential, String), Error>) -> Void) {
        self.nonce = nonce
        self.completion = completion
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization auth: ASAuthorization) {
        guard
            let cred = auth.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = cred.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let authCodeData = cred.authorizationCode,
            let authCode = String(data: authCodeData, encoding: .utf8)
        else {
            completion(.failure(AuthError.missingToken)); return
        }
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: cred.fullName)
        completion(.success((credential, authCode)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}

// MARK: - AuthProviderID helper

enum AuthProviderID {
    case apple, google, unknown
}

extension FirebaseAuth.User {
    var authProviderID: AuthProviderID {
        if providerData.contains(where: { $0.providerID == "apple.com" }) { return .apple }
        if providerData.contains(where: { $0.providerID == "google.com" }) { return .google }
        return .unknown
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case noRootViewController, missingToken, notSignedIn

    var errorDescription: String? {
        switch self {
        case .noRootViewController: return "Unable to present sign-in. Please try again."
        case .missingToken:         return "Authentication failed. Please try again."
        case .notSignedIn:          return "You are not signed in."
        }
    }
}
