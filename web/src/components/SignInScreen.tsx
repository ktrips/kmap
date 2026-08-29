interface Props {
  isSigningIn: boolean;
  error: string | null;
  isFirebaseConfigured: boolean;
  onSignInWithGoogle: () => void;
}

export function SignInScreen({
  isSigningIn,
  error,
  isFirebaseConfigured,
  onSignInWithGoogle,
}: Props) {
  return (
    <div className="sign-in-screen">
      <div className="sign-in-card">
        <p className="brand-eyebrow">Komap 古地図巡り</p>
        <h1>わたしの時間旅行</h1>
        <p className="sign-in-description">
          iOSアプリの「Komap 古地図巡り」で保存した地点と、AIが語ってくれた昔の物語を、
          こちらのWebページからも見られます。iOSアプリで使ったのと同じGoogleアカウントで、
          同じようにサインインしてください。
        </p>

        {isFirebaseConfigured ? (
          <div className="sign-in-buttons">
            <button className="google-button" onClick={onSignInWithGoogle} disabled={isSigningIn}>
              {isSigningIn ? "サインイン中..." : "Googleでサインイン"}
            </button>
          </div>
        ) : (
          <p className="setup-notice">
            Firebaseが未設定です。<code>web/.env</code> にFirebaseの設定値を入力してください。
          </p>
        )}

        {error && <p className="error-text">{error}</p>}
      </div>
    </div>
  );
}
