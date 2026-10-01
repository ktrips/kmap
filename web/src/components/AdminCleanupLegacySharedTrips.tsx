import { useState } from "react";
import { loadFunctions } from "../lib/firebase";

/**
 * 管理者が実行する後片付け（Cloud Function`cleanupLegacySharedTrips`）。以前のiOSアプリが作っていた
 * 公開用のコピー（`sharedTrips`の中身と、`sharedPhotos/`の写真の複製）を消す。何度実行してもよい。
 */
export function AdminCleanupLegacySharedTrips() {
  const [isRunning, setIsRunning] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  const run = async () => {
    if (!window.confirm("以前の公開用のコピー（旅のコピーと写真の複製）を削除しますか？ いいね・コメントは残ります。")) return;
    setIsRunning(true);
    setMessage(null);
    try {
      const { functions, httpsCallable } = await loadFunctions("us-central1");
      if (!functions) throw new Error("Firebaseが設定されていません。");
      const result = await httpsCallable<Record<string, never>, { copies: number; photos: number }>(
        functions,
        "cleanupLegacySharedTrips",
      )();
      setMessage(`旅のコピー${result.data.copies}件・写真の複製${result.data.photos}枚を削除しました。`);
    } catch (err) {
      setMessage(`削除に失敗しました: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsRunning(false);
    }
  };

  return (
    <section className="admin-promo">
      <h3>以前の公開用のコピーの後片付け</h3>
      <p className="muted admin-promo-hint">
        公開中の旅は、旅の文書の公開フラグだけで見せています。以前のiOSアプリが作っていたコピーは使われないので削除できます
        （古いアプリが残っている間は、また作られることがあります）。
      </p>
      <button type="button" className="sidebar-menu-button" onClick={() => void run()} disabled={isRunning}>
        {isRunning ? "削除中…" : "コピーを削除"}
      </button>
      {message && <p className="admin-promo-hint">{message}</p>}
    </section>
  );
}
