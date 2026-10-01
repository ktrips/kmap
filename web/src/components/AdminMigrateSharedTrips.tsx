import { useState } from "react";
import { loadFunctions } from "../lib/firebase";

/**
 * 管理者が一度だけ実行する移行（Cloud Function`migrateSharedTrips`）。以前の公開用のコピー（`sharedTrips`）から、
 * 旅の文書（`users/{uid}/walkRoutes`）に公開の印と公開ページ用の項目を写す。何度実行しても同じ結果になる。
 */
export function AdminMigrateSharedTrips() {
  const [isRunning, setIsRunning] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  const run = async () => {
    if (!window.confirm("以前の公開用のコピーから、公開中の旅を移行しますか？（何度実行しても同じ結果になります）")) return;
    setIsRunning(true);
    setMessage(null);
    try {
      const { functions, httpsCallable } = await loadFunctions("us-central1");
      if (!functions) throw new Error("Firebaseが設定されていません。");
      const result = await httpsCallable<Record<string, never>, { migrated: number }>(functions, "migrateSharedTrips")();
      setMessage(`公開中の旅を${result.data.migrated}件移行しました。`);
    } catch (err) {
      setMessage(`移行に失敗しました: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsRunning(false);
    }
  };

  return (
    <section className="admin-promo">
      <h3>公開中の旅の移行</h3>
      <p className="muted admin-promo-hint">
        公開中の旅を、旅の文書の公開フラグで切り替える新しい形に移します（Functionsとインデックスのデプロイ後に一度だけ）。
      </p>
      <button type="button" className="sidebar-menu-button" onClick={() => void run()} disabled={isRunning}>
        {isRunning ? "移行中…" : "移行を実行"}
      </button>
      {message && <p className="admin-promo-hint">{message}</p>}
    </section>
  );
}
