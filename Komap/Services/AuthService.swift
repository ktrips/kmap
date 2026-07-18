import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

enum AuthServiceError: LocalizedError {
    case firebaseNotConfigured
    case invalidAppleCredential
    case invalidGoogleCredential
    case noPresentingViewController

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebaseが設定されていません。GoogleService-Info.plistを追加してください。"
        case .invalidAppleCredential:
            return "Appleからの認証情報を取得できませんでした。もう一度お試しください。"
        case .invalidGoogleCredential:
            return "Googleからの認証情報を取得できませんでした。もう一度お試しください。"
        case .noPresentingViewController:
            return "サインイン画面を表示できませんでした。もう一度お試しください。"
        }
    }
}

/// Sign in with Apple / Googleサインインの資格情報でFirebase Authにサインインし、
/// サインイン状態（=同期先のFirestoreユーザーID）を公開する。
///
/// これにより、この端末で保存した地点と、Webアプリ（map.ktrips.net）で
/// 同じアカウントでログインした際に見える地点を、同一の `uid` で紐付けられる。
/// （Apple・Googleのどちらでサインインしても、Firebase Console側で
/// 「同じメールアドレスのアカウントをリンクする」設定にしておけば同じ `uid` になる）
@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published private(set) var userID: String?
    @Published private(set) var displayName: String?
    @Published private(set) var isSigningIn = false
    @Published var lastError: String?

    private var currentNonce: String?
    private var continuation: CheckedContinuation<Void, Error>?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    var isSignedIn: Bool { userID != nil }
    var isFirebaseConfigured: Bool { FirebaseApp.app() != nil }

    override init() {
        super.init()
        guard isFirebaseConfigured else { return }
        userID = Auth.auth().currentUser?.uid
        displayName = Auth.auth().currentUser?.displayName
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.userID = user?.uid
                self?.displayName = user?.displayName
            }
        }
    }

    func signInWithApple() async {
        guard isFirebaseConfigured else {
            lastError = AuthServiceError.firebaseNotConfigured.localizedDescription
            return
        }
        isSigningIn = true
        lastError = nil
        do {
            try await performAppleSignIn()
        } catch {
            lastError = error.localizedDescription
        }
        isSigningIn = false
    }

    func signInWithGoogle() async {
        guard isFirebaseConfigured else {
            lastError = AuthServiceError.firebaseNotConfigured.localizedDescription
            return
        }
        isSigningIn = true
        lastError = nil
        do {
            try await performGoogleSignIn()
        } catch {
            lastError = error.localizedDescription
        }
        isSigningIn = false
    }

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    /// Googleサインインの認証結果をアプリに戻すためのリダイレクトURLを処理する。
    /// `KomapApp` の `.onOpenURL` から呼び出す。
    func handleOpenURL(_ url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }

    private func performGoogleSignIn() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthServiceError.firebaseNotConfigured
        }
        guard let presentingViewController = Self.topViewController() else {
            throw AuthServiceError.noPresentingViewController
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthServiceError.invalidGoogleCredential
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        _ = try await Auth.auth().signIn(with: credential)
    }

    private func performAppleSignIn() async throws {
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let identityToken = credential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8)
        else {
            continuation?.resume(throwing: AuthServiceError.invalidAppleCredential)
            continuation = nil
            return
        }

        // `appleCredential` はApple側が「初回サインイン時にしか渡さない」氏名情報を
        // Firebase側のdisplayNameとして保存してくれる、公式に推奨されている方法。
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        Task {
            do {
                _ = try await Auth.auth().signIn(with: firebaseCredential)
                continuation?.resume()
            } catch {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Google Sign-Inの表示元ViewControllerの取得

private extension AuthService {
    static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }

        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - Nonce生成（Appleのリプレイ攻撃対策として推奨されている実装）

private extension AuthService {
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            precondition(status == errSecSuccess)

            for random in randoms {
                if remainingLength == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
