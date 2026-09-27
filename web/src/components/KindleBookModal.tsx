import { useEffect, useState } from "react";
import { marked } from "marked";
import { Modal } from "./Modal";
import { isFirebaseConfigured, loadFunctions } from "../lib/firebase";

interface Props {
  onClose: () => void;
  /** サインイン中なら、Komap Plus かどうかを確かめて、Plus なら全文を表示する。 */
  isSignedIn?: boolean;
  /** 未サインイン時に「サインインして全文を読む」を出す場合のサインイン処理。 */
  onSignIn?: () => void;
}

/** 冒頭の続き、Kindle版に収録予定の内容（実在の章タイトルから抜粋した目次）。 */
const upcomingChapters = [
  "第4章　古地図・画像オーバーレイの実装",
  "第6章　ゲーミフィケーション設計：チェックポイントと御朱印",
  "第9章　Apple Watch対応",
  "第13章　地図ゲームアプリの収益化モデルを選ぶ",
  "第20章　3人の起業家哲学から学ぶ収益化・マーケティング戦略",
  "第21章　費用構造とマーケティングROIの詳細分析",
  "第22章　リリース後に追加した機能：外部機器連携・写真管理・表示品質の磨き込み",
  "付録B　開発チェックリスト／付録C　参考リソース",
];

const KINDLE_URL = "https://link.amazon/B006awnVi";

type Access = "checking" | "preview" | "full";

interface KindleFullTextResult {
  status: "ok" | "not-plus";
  markdown?: string;
}

/** Plus の人だけに全文（Markdown）を返す Cloud Function を呼ぶ。Plus でなければ`null`。 */
async function fetchFullText(): Promise<string | null> {
  const { functions, httpsCallable } = await loadFunctions();
  if (!functions) return null;
  const call = httpsCallable<Record<string, never>, KindleFullTextResult>(functions, "getKindleFullText");
  const result = await call();
  return result.data.status === "ok" && result.data.markdown ? result.data.markdown : null;
}

/**
 * 「Komapの作り方 Kindle」ボタンから開く、Kindle原稿の表示。
 *
 * - 誰でも: 冒頭（目安10ページ相当）を読める。`public/kindle-preview.md`は、原稿のうち
 *   冒頭部分だけをあらかじめ切り出して配置した専用ファイル。
 * - Komap Plus（iOSアプリのサブスクリプション）の人: サインインしていれば全文を読める。
 *   全文は公開フォルダには置かず、Cloud Function（`getKindleFullText`）が購入状態を
 *   確かめてから返す。
 */
export function KindleBookModal({ onClose, isSignedIn = false, onSignIn }: Props) {
  const [html, setHtml] = useState<string | null>(null);
  const [access, setAccess] = useState<Access>(isSignedIn ? "checking" : "preview");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      if (isSignedIn && isFirebaseConfigured) {
        try {
          const full = await fetchFullText();
          if (cancelled) return;
          if (full) {
            setHtml(marked.parse(full, { async: false }) as string);
            setAccess("full");
            return;
          }
        } catch (err) {
          // 全文の確認に失敗しても、冒頭部分は読めるようにする。
          console.warn("Kindle本の全文の取得に失敗しました", err);
        }
      }
      try {
        const response = await fetch("/kindle-preview.md");
        if (!response.ok) throw new Error(`status ${response.status}`);
        const markdown = await response.text();
        if (cancelled) return;
        setHtml(marked.parse(markdown, { async: false }) as string);
        setAccess("preview");
      } catch {
        if (!cancelled) setError("原稿の読み込みに失敗しました。時間をおいて再度お試しください。");
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [isSignedIn]);

  const isFull = access === "full";

  return (
    <Modal title={isFull ? "Komapの作り方（Kindle原稿・全文）" : "Komapの作り方（Kindle原稿・一部無料）"} onClose={onClose}>
      <p className="kindle-lead">
        本書「
        <a href={KINDLE_URL} target="_blank" rel="noopener noreferrer">
          週末だけでできる！Google Mapを使った地図ゲームアプリを作る＆収益化する方法
        </a>
        」は、Komapを実際に開発した経験をもとにしたKindle原稿です。
        {isFull
          ? "Komap Plus の特典として、全文をお読みいただけます。"
          : "冒頭部分（目安10ページ相当）を無料でお読みいただけます。Komap Plus の方は全文を読めます。"}
      </p>

      {error && <p className="error-text">{error}</p>}
      {!error && (!html || access === "checking") && <p className="kindle-loading">読み込み中…</p>}
      {html && access !== "checking" && (
        <div className="kindle-preview-content" dangerouslySetInnerHTML={{ __html: html }} />
      )}

      {!isFull && access !== "checking" && (
        <div className="kindle-upcoming">
          <p className="kindle-upcoming-label">この続きに収録されている内容（一部）</p>
          <ul>
            {upcomingChapters.map((chapter) => (
              <li key={chapter}>🔒 {chapter}</li>
            ))}
          </ul>

          <div className="kindle-plus-box">
            <p className="kindle-plus-title">Komap Plus なら全文を読めます</p>
            {isSignedIn ? (
              <p className="kindle-upcoming-note">
                iPhoneアプリの「設定」→「Komap Plus」から登録できます（月額480円／年額3,800円）。
                登録後にこの画面を開き直すと、全文が表示されます。
              </p>
            ) : (
              <>
                <p className="kindle-upcoming-note">
                  Komap Plus に登録済みの方は、アプリと同じGoogleアカウントでサインインしてください。
                </p>
                {onSignIn && (
                  <button type="button" className="kindle-plus-signin" onClick={onSignIn}>
                    サインインして全文を読む
                  </button>
                )}
              </>
            )}
          </div>

          <a href={KINDLE_URL} target="_blank" rel="noopener noreferrer" className="kindle-buy-button">
            📖 Amazonで続きを読む
          </a>
        </div>
      )}
    </Modal>
  );
}

/**
 * `?book=1`付きのURL（iOSアプリの Komap Plus 画面からのリンク）で開いた時は、
 * 最初からKindle原稿を開く。閉じたらURLからパラメータを外す。
 */
export function useKindleDeepLink(): [boolean, (open: boolean) => void] {
  const [isOpen, setIsOpenState] = useState(() => new URLSearchParams(window.location.search).has("book"));
  const setIsOpen = (open: boolean) => {
    setIsOpenState(open);
    if (!open) {
      const url = new URL(window.location.href);
      if (url.searchParams.has("book")) {
        url.searchParams.delete("book");
        window.history.replaceState(null, "", url.toString());
      }
    }
  };
  return [isOpen, setIsOpen];
}
