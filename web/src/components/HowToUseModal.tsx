import { Modal } from "./Modal";
import { IOS_APP_VERSION } from "../version";

interface Props {
  onClose: () => void;
  onSignInWithGoogle: () => void;
}

/**
 * ページ右上の「使い方」ボタンから開く、Komapの簡単な説明。
 *
 * Web版でできることはあえて短くまとめ、その分iOSアプリでできること（本編）を
 * 強く押し出す構成にしている。Web版は「みんなの時空旅を見るだけ」の入り口であり、
 * 実際に歩いて古地図を巡る本体験はiOSアプリ側にあるため、ここから
 * iOSアプリへの乗り換え（Googleサインイン→TestFlight招待）を後押しする。
 */
export function HowToUseModal({ onClose, onSignInWithGoogle }: Props) {
  return (
    <Modal title="Komapの使い方" onClose={onClose}>
      <p className="howto-lead">
        Komap（古地図巡り）は、現在の地図に古地図を重ね合わせて、歩いている場所の「昔の姿」を
        味わえる散策アプリです。
      </p>

      <h3>Web版でできること</h3>
      <p className="howto-web-summary">
        みんなが公開した時空旅（歩いたルート・御朱印・写真）を、誰でも地図上で眺められます。
        Googleでサインインすれば、自分の記録の閲覧・編集やいいね・コメントも可能です。
      </p>

      <div className="howto-ios-pitch">
        <p className="howto-ios-pitch-eyebrow">📱 Googleでサインインすれば、旅の記録の閲覧・</p>
        <h3>iOSアプリなら、こんなこともできる！</h3>
        <ul>
          <li>
            <strong>実際に歩いて古地図を発見</strong> —
            現在地の地図に江戸〜明治期の古地図やオリジナル地図を重ね、自分の足で「昔の街」を歩けます
          </li>
          <li>
            <strong>AIがその場で物語を語ってくれる</strong> —
            地図上の好きな地点をタップするだけで、その場所にまつわるエピソードをAIが生成
          </li>
          <li>
            <strong>史跡めぐりで「御朱印」集め</strong> —
            チェックポイントに近づくと自動で獲得。歩くことがそのままゲームになります
          </li>
          <li>
            <strong>写真の加工・外部機器連携</strong> —
            撮った写真を自動でセピア調・ビンテージ風に加工。連携カメラ・連携プリンターとも組み合わせられます
          </li>
          <li>
            <strong>Apple Watch単体でも記録OK</strong> —
            iPhoneを開かなくても記録でき、後からWebやiPhoneで振り返れます
          </li>
        </ul>
        <p className="howto-ios-pitch-closer">
          このWebページで見られるのは、iOSアプリで生まれた記録の「一部」です。
          ぜひiOSアプリに移って、実際に古地図を持って歩く時空旅を体験してください！
        </p>
        <button type="button" className="howto-ios-cta-button" onClick={onSignInWithGoogle}>
          🚀 Googleでサインインして、iOSアプリを始める
        </button>
      </div>

      <p className="howto-footer-link">
        より詳しい機能一覧・セットアップ方法は{" "}
        <a href="https://github.com/ktrips/kmap#readme" target="_blank" rel="noreferrer">
          GitHubのREADME
        </a>{" "}
        をご覧ください。
      </p>
      <p className="howto-version">iOSアプリ バージョン {IOS_APP_VERSION}</p>
    </Modal>
  );
}
