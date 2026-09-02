import type { User } from "firebase/auth";

interface Props {
  user: User;
  placeCount: number;
  onSignOut: () => void;
}

export function Header({ user, placeCount, onSignOut }: Props) {
  const handleAvatarClick = () => {
    if (window.confirm("サインアウトしますか?")) {
      onSignOut();
    }
  };

  return (
    <header className="app-header">
      <div className="app-header-title">
        <img src="/app-icon.png" alt="Komap" className="app-header-icon" />
        <p className="brand-eyebrow">Komap 古地図巡り</p>
      </div>
      <div className="app-header-account">
        <span className="account-count">{placeCount}件の記録</span>
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
