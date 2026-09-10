import type { User } from "firebase/auth";
import { useTestFlightInvite } from "../lib/useTestFlightInvite";

/** Cloud Functions側の管理者チェックと同じアドレス。エラー時の問い合わせ先。 */
const ADMIN_EMAIL = "kenichiyoshida13@gmail.com";

interface Props {
  user: User;
  tripCount: number;
  onSignOut: () => void;
  /** trueの間は、左側のアプリ名の代わりに「一覧」ボタンを表示する（詳細を見ている時用）。 */
  showListButton?: boolean;
  onShowList?: () => void;
}

export function Header({ user, tripCount, onSignOut, showListButton = false, onShowList }: Props) {
  const { status, errorMessage, adminReport, requestInvite } = useTestFlightInvite();

  const adminMailtoHref = adminReport
    ? `mailto:${ADMIN_EMAIL}?subject=${encodeURIComponent(
        "Komap: TestFlight招待エラー",
      )}&body=${encodeURIComponent(`${adminReport}\n\n---\n問い合わせ元: ${user.email ?? "(不明)"}`)}`
    : null;

  const handleAvatarClick = () => {
    if (window.confirm("サインアウトしますか?")) {
      onSignOut();
    }
  };

  const buttonLabel = {
    idle: "📱 iOSアプリを取得",
    sending: "送信中…",
    sent: "✅ 招待メールを送信しました",
    "already-invited": "✅ 招待メールを送信済みです",
    error: "⚠️ 送信に失敗しました",
  }[status];

  return (
    <header className="app-header app-header--authenticated">
      <div className="app-header-title">
        <button
          type="button"
          className="app-header-icon-button"
          onClick={onShowList}
          aria-label="一覧を表示"
        >
          <img src="/app-icon.png" alt="Komap" className="app-header-icon" />
        </button>
        <p className="brand-eyebrow">Komap 古地図巡り</p>
        {showListButton && (
          <button type="button" className="sidebar-menu-button" onClick={onShowList} aria-label="一覧を表示">
            <span aria-hidden="true">☰</span> 一覧
          </button>
        )}
      </div>
      <div className="app-header-account">
        {!showListButton && <span className="account-count">{tripCount}件の旅</span>}
        <div className="testflight-invite">
          <button
            type="button"
            className="testflight-invite-button"
            onClick={() => requestInvite()}
            disabled={status === "sending"}
            title={`${user.email ?? ""} 宛にTestFlightの招待メールを送ります`}
          >
            {buttonLabel}
          </button>
          {(status === "sent" || status === "already-invited") && (
            <p className="testflight-invite-note">
              {user.email} 宛のメールから、TestFlightアプリ経由でインストールできます。
            </p>
          )}
          {status === "error" && errorMessage && (
            <p className="testflight-invite-note is-error">
              {adminMailtoHref ? (
                <>
                  iOSのダウンロードに失敗した時は、お手数ですが、この
                  <a href={adminMailtoHref}>リンク</a>
                  から管理者にメールで連絡して下さい。
                </>
              ) : (
                errorMessage
              )}
            </p>
          )}
        </div>
        <button
          className="account-avatar-button"
          onClick={handleAvatarClick}
          title={user.displayName ?? "サインアウト"}
        >
          {user.photoURL ? (
            <img src={user.photoURL} alt={user.displayName ?? "アカウント"} className="account-avatar" />
          ) : (
            <span className="account-avatar account-avatar-fallback">
              {(user.displayName ?? "?").charAt(0)}
            </span>
          )}
        </button>
      </div>
    </header>
  );
}
