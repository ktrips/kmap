/**
 * 管理者のメールアドレス。管理者レポート（`getAdminFunnelReport`）の利用と、
 * Komap Plus を購入せずに使えること（`getKindleFullText`）に使う。
 * 個人開発の1人プロジェクトのため、複数管理者を想定した仕組み（Firestoreの
 * 管理者フラグなど）は導入せず、固定のメールアドレス比較で十分とした。
 */
export const ADMIN_EMAIL = "kenichiyoshida13@gmail.com";
