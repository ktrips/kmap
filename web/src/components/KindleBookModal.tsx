import { useEffect, useState } from "react";
import { marked } from "marked";
import { Modal } from "./Modal";

interface Props {
  onClose: () => void;
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

/**
 * 「Komapの作り方 Kindle（一部無料）」ボタンから開く、執筆中のKindle原稿の
 * 冒頭（目安10ページ相当）プレビュー。`public/kindle-preview.md`は、原稿全文のうち
 * 冒頭部分だけをあらかじめ切り出して配置した専用ファイル（全文はここでは配信しない）。
 */
export function KindleBookModal({ onClose }: Props) {
  const [html, setHtml] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetch("/kindle-preview.md")
      .then((response) => {
        if (!response.ok) throw new Error(`status ${response.status}`);
        return response.text();
      })
      .then((markdown) => {
        if (cancelled) return;
        setHtml(marked.parse(markdown, { async: false }) as string);
      })
      .catch(() => {
        if (!cancelled) setError("原稿の読み込みに失敗しました。時間をおいて再度お試しください。");
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <Modal title="Komapの作り方（Kindle原稿・一部無料）" onClose={onClose}>
      <p className="kindle-lead">
        本書「週末だけでできる！Google Mapを使った地図ゲームアプリを作る＆収益化する方法」は、
        Komapを実際に開発した経験をもとにした執筆中のKindle原稿です。冒頭部分（目安10ページ相当）を
        無料でお読みいただけます。
      </p>

      {error && <p className="error-text">{error}</p>}
      {!error && !html && <p className="kindle-loading">読み込み中…</p>}
      {html && <div className="kindle-preview-content" dangerouslySetInnerHTML={{ __html: html }} />}

      <div className="kindle-upcoming">
        <p className="kindle-upcoming-label">この続きに収録されている内容（一部）</p>
        <ul>
          {upcomingChapters.map((chapter) => (
            <li key={chapter}>🔒 {chapter}</li>
          ))}
        </ul>
        <p className="kindle-upcoming-note">Kindle版は現在準備中です。公開時期は追ってお知らせします。</p>
      </div>
    </Modal>
  );
}
