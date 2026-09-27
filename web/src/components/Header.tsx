import { useEffect, useRef, useState } from "react";
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
  /** 左上のアプリアイコンを押した時。選択中の時空旅・地点を解除してホームに戻す。 */
  onGoHome?: () => void;
  /** trueなら、アカウントメニューに「管理者レポート」を出す。 */
  isAdmin?: boolean;
  onOpenAdminReport?: () => void;
}

export function Header({
  user,
  tripCount,
  onSignOut,
  showListButton = false,
  onShowList,
  onGoHome,
  isAdmin = false,
  onOpenAdminReport,
}: Props) {
  const { status, errorMessage, adminReport, requestInvite } = useTestFlightInvite();
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  // メニューの外を押した時・Escキーで閉じる。
  useEffect(() => {
    if (!isMenuOpen) return;
    const handlePointerDown = (event: PointerEvent) => {
      if (!menuRef.current?.contains(event.target as Node)) setIsMenuOpen(false);
    };
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") setIsMenuOpen(false);
    };
    document.addEventListener("pointerdown", handlePointerDown);
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("pointerdown", handlePointerDown);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [isMenuOpen]);

  const adminMailtoHref = adminReport
    ? `mailto:${ADMIN_EMAIL}?subject=${encodeURIComponent(
        "Komap: TestFlight招待エラー",
      )}&body=${encodeURIComponent(`${adminReport}\n\n---\n問い合わせ元: ${user.email ?? "(不明)"}`)}`
    : null;

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
          onClick={onGoHome ?? onShowList}
          aria-label="ホームに戻る"
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
        <div className="account-menu-anchor" ref={menuRef}>
          <button
            className="account-avatar-button"
            onClick={() => setIsMenuOpen((open) => !open)}
            title={user.displayName ?? "アカウント"}
            aria-haspopup="menu"
            aria-expanded={isMenuOpen}
          >
            {user.photoURL ? (
              <img src={user.photoURL} alt={user.displayName ?? "アカウント"} className="account-avatar" />
            ) : (
              <span className="account-avatar account-avatar-fallback">
                {(user.displayName ?? "?").charAt(0)}
              </span>
            )}
          </button>
          {isMenuOpen && (
            <div className="account-menu" role="menu">
              <p className="account-menu-email">{user.email}</p>
              {isAdmin && onOpenAdminReport && (
                <button
                  type="button"
                  role="menuitem"
                  className="account-menu-item"
                  onClick={() => {
                    setIsMenuOpen(false);
                    onOpenAdminReport();
                  }}
                >
                  📊 管理者レポート
                </button>
              )}
              <button
                type="button"
                role="menuitem"
                className="account-menu-item"
                onClick={() => {
                  setIsMenuOpen(false);
                  onSignOut();
                }}
              >
                ログアウト
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
