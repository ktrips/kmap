import { Timestamp, collection, deleteDoc, doc, getCountFromServer, query, serverTimestamp, setDoc, where } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";

/** 何秒おきに自分の生存（ハートビート）を書き込むか。 */
const HEARTBEAT_INTERVAL_MS = 20_000;
/** ハートビートがこれより古い記録は「もういない」とみなす（間隔より余裕を持たせる）。 */
const STALE_AFTER_MS = 45_000;
/** 人数の数え直しの間隔。 */
const POLL_INTERVAL_MS = 15_000;

const SESSION_STORAGE_KEY = "komap-presence-session-id";

function getSessionId(): string {
  let id = sessionStorage.getItem(SESSION_STORAGE_KEY);
  if (!id) {
    id = crypto.randomUUID();
    sessionStorage.setItem(SESSION_STORAGE_KEY, id);
  }
  return id;
}

/**
 * 「今◯人が時空旅中」の演出用に、このWebページを今開いている人数のおおよその
 * 目安を返す。`presence/{セッションID}`へ定期的に生存確認（ハートビート）を
 * 書き込み、直近{@link STALE_AFTER_MS}以内に書き込みがあった件数を数える方式。
 *
 * - Important: サーバー側でのプッシュ通知のような真のリアルタイム人数ではなく、
 *   ポーリングで数え直す簡易的な目安。タブを閉じた瞬間に正確に減るわけではない
 *   （`beforeunload`での削除はベストエフォート。基本は経過時間で自然に
 *   カウントから外れる）。
 */
export function usePresence(): number | null {
  const [count, setCount] = useState<number | null>(null);

  useEffect(() => {
    if (!db) return;
    const firestore = db;
    const sessionId = getSessionId();
    const presenceRef = doc(firestore, "presence", sessionId);

    const sendHeartbeat = () => {
      setDoc(presenceRef, { lastSeen: serverTimestamp() }).catch(() => {
        // 訪問者向けの演出用の数字なので、失敗しても画面には影響させない。
      });
    };
    sendHeartbeat();
    const heartbeatTimer = setInterval(sendHeartbeat, HEARTBEAT_INTERVAL_MS);

    const refreshCount = () => {
      const cutoff = Timestamp.fromMillis(Date.now() - STALE_AFTER_MS);
      const activeQuery = query(collection(firestore, "presence"), where("lastSeen", ">", cutoff));
      getCountFromServer(activeQuery)
        .then((snapshot) => setCount(snapshot.data().count))
        .catch(() => {});
    };
    refreshCount();
    const pollTimer = setInterval(refreshCount, POLL_INTERVAL_MS);

    const handleUnload = () => {
      void deleteDoc(presenceRef);
    };
    window.addEventListener("beforeunload", handleUnload);

    return () => {
      clearInterval(heartbeatTimer);
      clearInterval(pollTimer);
      window.removeEventListener("beforeunload", handleUnload);
      deleteDoc(presenceRef).catch(() => {});
    };
  }, []);

  return count;
}
