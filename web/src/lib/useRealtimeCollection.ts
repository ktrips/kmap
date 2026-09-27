import { useEffect, useState } from "react";
import type { DocumentData } from "firebase/firestore";
import { isFirebaseConfigured, loadRealtimeFirestore } from "./firebase";

/**
 * サインイン中のユーザーのコレクション（`users/{uid}/places`など）を、新しい順にリアルタイムで購読する。
 * iOSアプリで保存・変更した記録が、Webにもすぐ反映される。
 *
 * 地点・時空旅・御朱印・投稿写真の4つの購読は、読み取る項目以外は同じ処理だったため、ここにまとめた。
 * リアルタイム更新に必要な完全版のFirestoreは、この購読を始める時に初めて読み込む（`loadRealtimeFirestore`）。
 *
 * @param path 購読するコレクションのパス（`null`なら購読しない）。
 * @param orderField 新しい順に並べるための日時の項目名。
 * @param parse 1件分のドキュメントを画面用の値にする関数（毎回同じ関数を渡すこと）。
 */
export function useRealtimeCollection<T>(
  path: string[] | null,
  orderField: string,
  parse: (id: string, data: DocumentData) => T,
) {
  const [items, setItems] = useState<T[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const key = path ? path.join("/") : null;

  useEffect(() => {
    if (!isFirebaseConfigured || !key) {
      setItems([]);
      return;
    }
    let cancelled = false;
    let unsubscribe: (() => void) | undefined;
    setIsLoading(true);
    setError(null);
    loadRealtimeFirestore()
      .then(({ firestore, db }) => {
        if (cancelled || !db) return;
        const [first, ...rest] = key.split("/");
        const q = firestore.query(firestore.collection(db, first, ...rest), firestore.orderBy(orderField, "desc"));
        unsubscribe = firestore.onSnapshot(
          q,
          (snapshot) => {
            setItems(snapshot.docs.map((doc) => parse(doc.id, doc.data())));
            setIsLoading(false);
          },
          (err) => {
            setError(err.message);
            setIsLoading(false);
          },
        );
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : "読み込みに失敗しました。");
        setIsLoading(false);
      });
    return () => {
      cancelled = true;
      unsubscribe?.();
    };
  }, [key, orderField, parse]);

  return { items, isLoading, error };
}
