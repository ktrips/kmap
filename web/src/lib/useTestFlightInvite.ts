import { FunctionsError, httpsCallable } from "firebase/functions";
import { useCallback, useState } from "react";
import { functions } from "./firebase";

export type TestFlightInviteStatus = "idle" | "sending" | "sent" | "already-invited" | "error";

interface RequestTestFlightInviteResult {
  status: "sent" | "already-invited";
}

/** Cloud Function側のHttpsErrorが`details.adminReport`を持つ場合の型。 */
interface AdminReportDetails {
  adminReport?: string;
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
  // サーバー側で原因の切り分けができた場合だけ入る、管理者への問い合わせ
  // メール本文用の詳細メッセージ（Cloud Functionの`details.adminReport`）。
  const [adminReport, setAdminReport] = useState<string | null>(null);

  const requestInvite = useCallback(async () => {
    if (!functions) {
      setStatus("error");
      setErrorMessage("Firebaseが設定されていません。");
      setAdminReport(null);
      return;
    }
    setStatus("sending");
    setErrorMessage(null);
    setAdminReport(null);
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
      if (err instanceof FunctionsError) {
        const details = err.details as AdminReportDetails | undefined;
        setAdminReport(typeof details?.adminReport === "string" ? details.adminReport : null);
      }
    }
  }, []);

  return { status, errorMessage, adminReport, requestInvite };
}
