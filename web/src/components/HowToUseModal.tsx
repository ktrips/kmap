import { Modal } from "./Modal";

interface Props {
  onClose: () => void;
}

/**
 * ページ右上の「使い方」ボタンから開く、Komapの簡単な説明。
 * 詳しいセットアップ手順はGitHubのREADMEに譲り、ここでは訪問者が
 * 「このサイト・アプリで何ができるか」をすぐ把握できることを優先する。
 */
export function HowToUseModal({ onClose }: Props) {
  return (
    <Modal title="Komapの使い方" onClose={onClose}>
      <p className="howto-lead">
        Komap（古地図巡り）は、現在の地図に古地図を重ね合わせて、歩いている場所の「昔の姿」をAIが
        解説してくれる、時間旅行気分の散策アプリです。
      </p>

      <h3>このページ（Web版）でできること</h3>
      <ul>
        <li>「そうだ、時空旅しよう」一覧から、みんなが公開した時空旅（歩いたルート・御朱印・写真）を誰でも閲覧できます</li>
        <li>時空旅を選ぶと、実際に歩いたルートを地図上でたどり、投稿写真やAIが生成した物語を見られます</li>
        <li>Googleでサインインすると、自分の記録（My Trips）の閲覧・名称や感想の編集、いいね・コメントができます</li>
      </ul>

      <h3>iOSアプリでできること</h3>
      <ul>
        <li>現在地の地図に、江戸〜明治期の古地図やオリジナルの地図を重ねて表示</li>
        <li>「スタート」でGPS記録を開始し、史跡チェックポイントに近づくと「御朱印」を自動獲得</li>
        <li>地図上の地点をタップすると、AIがその場所にまつわる物語を生成</li>
        <li>Apple Watch単体でも記録可能。Googleでサインインすれば、この Web ページからも同じ記録を閲覧できます</li>
      </ul>

      <p className="howto-footer-link">
        より詳しい機能一覧・セットアップ方法は{" "}
        <a href="https://github.com/ktrips/kmap#readme" target="_blank" rel="noreferrer">
          GitHubのREADME
        </a>{" "}
        をご覧ください。
      </p>
    </Modal>
  );
}
