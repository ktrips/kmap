import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

enum AuthServiceError: LocalizedError {
    case firebaseNotConfigured
    case invalidGoogleCredential
    case noPresentingViewController

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebaseが設定されていません。GoogleService-Info.plistを追加してください。"
        case .invalidGoogleCredential:
            return "Googleからの認証情報を取得できませんでした。もう一度お試しください。"
        case .noPresentingViewController:
            return "サインイン画面を表示できませんでした。もう一度お試しください。"
        }
    }
}

/// Googleサインインの資格情報でFirebase Authにサインインし、
/// サインイン状態（=同期先のFirestoreユーザーID）を公開する。
///
/// これにより、この端末で保存した地点と、Webアプリ（map.ktrips.net）で
/// 同じGoogleアカウントでログインした際に見える地点を、同一の `uid` で紐付けられる。
///
/// （Sign in with Appleは、無料のApple ID（Personal Team）ではCapabilityが
/// 使えず provisioning profile を作成できないため未対応。
/// Apple Developer Program（有料）に登録済みの場合は、AuthServiceにApple版の
/// サインインを追加し、`project.yml` にentitlementsを追加すれば利用できる）
@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published private(set) var userID: String?
    @Published private(set) var displayName: String?
    @Published private(set) var isSigningIn = false
    @Published var lastError: String?

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
