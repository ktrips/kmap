import { httpsCallable } from "firebase/functions";
import { useCallback, useState } from "react";
import { functions } from "./firebase";

export type TestFlightInviteStatus = "idle" | "sending" | "sent" | "already-invited" | "error";

interface RequestTestFlightInviteResult {
  status: "sent" | "already-invited";
}

/**
 * サインイン中のユーザー本人のメールアドレスへ、TestFlightの外部テスト招待を送るよう
 * Cloud Function（`requestTestFlightInvite`）へ依頼する。
 *
 * サインイン直後の自動送信（`useAuth`）と、Header の「iOSアプリを取得」ボタンの
 * 両方から使うため、呼び出しロジックと状態管理をここに共通化している。
 */
export function useTestFlightInvite() {
  const [status, setStatus] = useState<TestFlightInviteStatus>("idle");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const requestInvite = useCallback(async () => {
    if (!functions) {
      setStatus("error");
      setErrorMessage("Firebaseが設定されていません。");
      return;
    }
    setStatus("sending");
    setErrorMessage(null);
    try {
      const call = httpsCallable<Record<string, never>, RequestTestFlightInviteResult>(
        functions,
        "requestTestFlightInvite",
      );
      const result = await call();
      setStatus(result.data.status);
    } catch (err) {
      console.warn("TestFlight招待の送信に失敗しました", err);
      setStatus("error");
      setErrorMessage(err instanceof Error ? err.message : "招待の送信に失敗しました。");
    }
  }, []);

  return { status, errorMessage, requestInvite };
}
