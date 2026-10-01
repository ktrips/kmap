import { useEffect, type ReactNode } from "react";
import { useAdminFunnelReport } from "../lib/useAdminFunnelReport";

/**
 * 管理者（`AuthenticatedApp`から、サインイン中のメールアドレスが一致する時だけ）
 * に表示する、Web経由のユーザーがどの利用フェーズにいるかのレポート。
 * データは既存のFirestore（Firebase Authのユーザー数・walkRoutes・stamps・
 * 公開中の旅）から`getAdminFunnelReport`が集計したものを使う。
 */
/** `children`は、レポートの下に並べる管理者用の操作（プロモユーザーの登録など）。 */
export function AdminFunnelReport({ children }: { children?: ReactNode }) {
  const { report, isLoading, errorMessage, load } = useAdminFunnelReport();

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <div className="admin-report">
      <div className="admin-report-header">
        <h2>管理者レポート</h2>
        <button type="button" className="sidebar-menu-button" onClick={() => void load()} disabled={isLoading}>
          {isLoading ? "更新中…" : "再読み込み"}
        </button>
      </div>

      {errorMessage && <p className="admin-report-error">{errorMessage}</p>}

      {report && (
        <>
          <div className="admin-report-summary">
            <div className="admin-report-stat">
              <span className="admin-report-stat-value">{report.totalUsers}</span>
              <span className="admin-report-stat-label">登録ユーザー数</span>
            </div>
            <div className="admin-report-stat">
              <span className="admin-report-stat-value">{report.currentAnonymousViewers}</span>
              <span className="admin-report-stat-label">今このページを見ている人数（未サインイン含む）</span>
            </div>
          </div>

          <table className="admin-report-table">
            <thead>
              <tr>
                <th>フェーズ</th>
                <th>人数</th>
                <th>次に打てる手</th>
              </tr>
            </thead>
            <tbody>
              {report.phases.map((phase) => (
                <tr key={phase.key}>
                  <td>{phase.label}</td>
                  <td className="admin-report-count">{phase.count}</td>
                  <td>{phase.suggestion}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
      {children}
    </div>
  );
}
