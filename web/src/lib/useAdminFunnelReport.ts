import { httpsCallable } from "firebase/functions";
import { useCallback, useState } from "react";
import { functions } from "./firebase";

export interface FunnelPhase {
  key: "signedInOnly" | "startedTrip" | "collectedStamp" | "shared";
  label: string;
  count: number;
  suggestion: string;
}

export interface AdminFunnelReport {
  totalUsers: number;
  currentAnonymousViewers: number;
  phases: FunnelPhase[];
}

/**
 * 管理者向けの利用フェーズレポートをCloud Function（`getAdminFunnelReport`）から取得する。
 * 呼び出し元が管理者本人かどうかはFunction側で`request.auth.token.email`を検証するため、
 * ここでの成否は実質的なアクセス制御にもなる（管理者以外が呼ぶと`permission-denied`で失敗する）。
 */
export function useAdminFunnelReport() {
  const [report, setReport] = useState<AdminFunnelReport | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!functions) {
      setErrorMessage("Firebaseが設定されていません。");
      return;
    }
    setIsLoading(true);
    setErrorMessage(null);
    try {
      const call = httpsCallable<Record<string, never>, AdminFunnelReport>(functions, "getAdminFunnelReport");
      const result = await call();
      setReport(result.data);
    } catch (err) {
      console.warn("管理者レポートの取得に失敗しました", err);
      setErrorMessage(err instanceof Error ? err.message : "レポートの取得に失敗しました。");
    } finally {
      setIsLoading(false);
    }
  }, []);

  return { report, isLoading, errorMessage, load };
}
