import type { User } from "firebase/auth";

interface Props {
  user: User;
  placeCount: number;
  onSignOut: () => void;
}

export function Header({ user, placeCount, onSignOut }: Props) {
  return (
    <header className="app-header">
      <div className="app-header-title">
        <p className="brand-eyebrow">Komap 古地図巡り</p>
        <h1>わたしの時間旅行</h1>
      </div>
      <div className="app-header-account">
        <div className="account-info">
          <span className="account-name">{user.displayName ?? "ゲスト"}</span>
          <span className="account-count">{placeCount}件の記録</span>
        </div>
        <button className="ghost-button" onClick={onSignOut}>
          サインアウト
        </button>
      </div>
    </header>
  );
}
