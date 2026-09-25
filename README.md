# Komap 古地図巡り

現在のGoogle Map上に古地図を重ね合わせ、自分が歩いている場所の「昔の姿」をAIが解説してくれる、
時間旅行気分の散策アプリです。iOSアプリ本体に加えてApple Watch単体でも記録でき、
保存した「My Trips（私の時空旅）」はWebアプリ（`komap.ktrips.net` など）からも
同じGoogleアカウントでログインして見ることができます。

## 主な機能

### 地図・古地図まわり
- 現在地をGoogle Map上に表示。Google純正の現在地マーク（小さく見づらいとの声があったため）
  に代えて、自前描画の大きな現在地マークを写真ピンより必ず前面に表示する
  （記録中はさらに拡大）。歩行記録中はGPSの進行方向（`CLLocation.course`）が
  分かっている間、現在地マークから外向きに小さな三角を突き出して、
  進んでいる方向がひと目で分かるようにする（三角は現在地マークの縁から少し離して表示する。
  静止中など進行方向を算出できていない間は隠す。
  三角の色は選んでいる現在地マークの見た目（`CurrentLocationIconStyle`）に揃える）
- 江戸〜明治期の古地図（同梱サンプル、詳細は後述）を現在の地図に重ねて表示
- **🌍 Komap Global（海外の旧市街）**: 東京版とは別の分類として、アムステルダム（中世〜黄金時代）・
  ヘルシンキ（帝政期）・ストックホルム（ガムラスタン）・タリン（ハンザ同盟）の4都市の旧市街を
  象ったオリジナル古地図と、各5箇所のチェックポイントを同梱。「古地図を選択」一覧の末尾の
  独立したセクションに並ぶ。これらの地図では御朱印（金の印章）の代わりに、紋章学の
  地・彩色・図形のルールに沿った紋章（クレスト）風バッジ（SFシンボル＋色）を集める。
  既定では表示せず、「設定」の「古地図のデフォルト」にある「Komap Global（海外の旧市街）を表示」を
  オンにした時だけ、古地図の選択肢・全地図・現在地からの古地図選択・御朱印一覧に出る
- スライダーで「現在の地図」⇔「古地図」の濃さ（不透明度）を自由に調整
- 「全ての古地図を表示」を選ぶと、同梱・登録済みの古地図とチェックポイントを
  地図上にまとめて重ねて見られる（チェックポイント以外の場所をタップすると、
  その座標を含む古地図があればその単体表示に切り替わる）
- **古地図の選択**（マップ下部・左上どちらからでも開く「古地図を選択」）
  - 一番上に、コンパクトな4つのクイックボタン「現在地」「新地図」「全地図」「地図無し」を横並びで
    表示する。「現在地」は現在地を含む古地図を自動で選び（複数あれば中心が最も近いもの）、
    画面の中心も現在地へ動かす。含む古地図が無い時は、現在地付近の古地図を作る検索画面
    （検索文に現在地の地名・緯度経度が入った状態）へ進む。「新地図」は「設定」→「アドバンス設定」→
    「AI設定」の「新しい地図を追加」がオンの時だけ表示する（AI APIを呼ぶ機能のため既定はオフ）。
    「全地図」は全ての古地図を重ねて表示、「地図無し」は古地図を出さずに歩く
  - 各地図の右側の詳細アイコン（ⓘ）から、古地図の詳細（画像・その上の番号つきチェックポイントの
    ピン・時代・紹介文・範囲・番号に対応したチェックポイントの説明）を見られる。マップ上部中央の
    地図名を押した時の説明シートも、歩行中を含めて同じ形式（`OverlayInfoContent`）で表示する
  - 一覧の最下部に「追加した古地図」（自分が追加したもの）と「みんなの古地図」（クラウドで
    公開されているもの。＋で自分の古地図として取り込める）を並べる
  - 「設定」→「古地図のデフォルト」の「最初に表示する古地図」は「現在地」「全地図」「各古地図」から
    選べる（未設定は「現在地」＝最初に現在地が取れた時に現在地を含む古地図を自動選択）
- **新しい古地図の検索・作成**（古地図選択の「新地図」）。AI（デフォルトのAIプロバイダー）が
  地域の説明から位置範囲・タイトル・時代を推定し、画像は国立国会図書館デジタルコレクション
  （IIIF、APIキー不要）→ Wikimedia Commons（APIキー不要）の順に探す。どちらでも画像が
  見つからない時は、条件に合わせてAIが範囲とチェックポイント5件を考え、古地図風の半透明の
  地図レイヤーで代用する。範囲は「現在の範囲」（既定）・「周囲5km」・「周囲10km」から選べ、
  画面を開いた時の地図の表示範囲（またはその中心から）の内側にだけ地図とチェックポイントを作る。
  「ファンタジー地図を生成」をオンにすると、実在の古地図を探さず、その地域を舞台にした
  架空のファンタジー地図（名前・チェックポイントはAI、絵はOpenAI/Googleの画像生成）を作る
  （Anthropicは画像生成APIが無いため方眼レイヤーで代用）。追加した画像は
  1024×1024pxの正方形に揃えて保存する（Google Maps SDKの描画の制約）
- **追加した古地図の編集**: 詳細画面の「編集」（右上メニュー）から、地図の上でポイントの追加
  （地図をタップ）・削除（ポイントをタップ）、地図名の変更、公開範囲（自分だけ／公開）、
  「地図をアップデート」（説明を入れると、いまの画像をもとにAIが見た目をより綺麗に描き直す。
  OpenAI/Google）、古地図の削除ができる。公開にするとFirestore（`sharedOverlayMaps`）と
  Storageへ画像・範囲・ポイントを上げ、「みんなの古地図」に出る（編集に合わせて自動更新）。
  メインの地図をタップしてポイントを追加する機能は廃止し、追加は編集画面の中だけにした
- **管理者による同梱の古地図の編集**: `kenichiyoshida13@gmail.com`（`AuthService.adminEmail`）で
  サインインしている管理者は、同梱の古地図の詳細画面にも「編集」が出て、名前・画像・
  ポイント（追加／削除＝非表示）を変更できる。変更は元のデータを書き換えず、端末内の
  「上書き」（`OverlayOverrideStore`）として保存し、「変更を元に戻す」で同梱の内容に戻せる
  （この上書きはその端末だけで有効）
- 史跡チェックポイントをタップした時に出る名前表示は、GPSの更新やカメラのパン・ズームで
  巻き添えに閉じられることなく、タップした状態のまま表示され続ける
- 歩行中にGoogle Maps SDK側のGPU不具合で古地図が透明になって消えてしまっても、
  古地図メニューからもう一度（同じ古地図であっても）選び直すだけで、オーバーレイを
  貼り直して復帰できる。加えて、徒歩ルート記録中（iPhone本体・Apple Watch伴走どちらでも）は、
  GPSの更新が来ない（信号待ち・写真撮影等で静止している）間やカメラを操作していない間も、
  一定間隔（4秒ごと）でオーバーレイを自動的に貼り直し続けるため、手動で選び直さなくても
  古地図が消えたまま長時間戻らない状態になりにくい
- 歩行中も、マップ上部中央の地図名を押すと地図の説明シートが開く（GPU不具合で古地図が
  消えた時のための「古地図を再読み込み」ボタンは、歩行中だけそのシートの中に出る）
- マップ左上・下部どちらの「古地図選択」からも、歩行記録中かどうかによらず選び直しシートが
  開き、実際に別の古地図へ切り替えられる（以前は歩行中だけシートを開かず貼り直しのみ行って
  いたため、歩きながら古地図を変更できなかった）

- **表示のパフォーマンス**: 地図の描画フレームレートを60Hzに抑え（既定は最大）、古地図の上では
  不要な立体の建物・屋内地図の描画を止めている。古地図・チェックポイントの参照はID索引と
  キャッシュで行い、写真は一覧・地図ピン用にImageIOで必要なサイズだけ縮小読み込み
  （`StampPhotoStore.thumbnail`）する。写真の縮小は実ピクセル数（`format.scale = 1`）で行い、
  以前の版で巨大なまま保存された写真は、起動後に一度だけ長辺1600pxへ縮小し直す

### 記録・ゲーミフィケーション
- 「スタート」でGPSによる徒歩ルートの記録を開始。「完了」を押すと、大きな「保存」ボタンと
  小さな「破棄」ボタン（誤操作防止の確認つき）で記録を残すか選べる
- 記録中は画面をロックしたりアプリをバックグラウンドに回しても、位置情報のバックグラウンド
  更新（`UIBackgroundModes: location`）でGPS記録を継続する。実際に継続させるには「常に許可」
  への昇格が必要なため、記録を始めた瞬間にまだ「使用中のみ許可」であればアップグレードを促す
  （起動直後にいきなり「常に許可」を求めず、必要になったタイミングで聞くApple推奨の方式）。
  記録中以外はバックグラウンド更新をオフに戻し、余計なバッテリー消費を防ぐ
- 「スタート」を押すと現在地へズームし、古地図が未選択の場合は自動で表示、
  不透明度も50%まで引き上げる。「全ての古地図を表示」がオフになるなど記録中に
  古地図の選択が意図せず外れても、自動で立て直して表示が消えないようにする
- 記録中は過去に保存済みの軌跡・投稿写真ピンを薄く表示し、今歩いている軌跡だけ
  ひときわ濃く太い色で描いて歩き進めている実感を強める
  （軌跡はChaikinのコーナーカット法で滑らかに描画）。軌跡描画は新しく増えた区間だけを
  差分で追記する方式のため、長時間歩いてもGPS更新1回あたりの処理が重くならない。
  古地図自体は、記録中かどうかによらず常にスライダーの不透明度のまま全体を表示する
  （以前あった「通った場所だけくっきり見せる」演出は、重い画像合成が歩行中の表示の
  もたつき・消失の原因になっていたため廃止した）
- 歩数はCMPedometerに加えてApple Health（HealthKit、読み取りのみ）からも取得し、
  取得できればWatch・iPhoneのセンサー値を統合したより正確な歩数を優先して保存する
- Apple Watch単体でも同じ記録ができ（iPhoneを開いていなくても可）、iPhone側にも
  リアルタイムで軌跡・御朱印・写真投稿が同期される。Watch単体で記録を始めた後に
  iPhone側アプリを開いた場合も、直近の状態を読み直してすぐに連動状態に追いつく
- iPhoneで「スタート」した記録でも、Apple Watchが接続していれば裏でWatch自身のGPSも
  「伴走」させ、iPhone単体より多くの点を捉えられていればそちらの軌跡を表示・保存する
  （画面上はいつも通り「iPhoneでの記録」のまま。Watchの画面も「iPhoneと連動中」の
  表示を変えない）
- 古地図ごとに置かれた史跡チェックポイントに近づくと「御朱印」を自動で獲得
  （Komap Globalの地図では、チェックイン画面・御朱印帳のグリッドに紋章風バッジを表示。
  未獲得は灰色の盾。意匠は`HistoricSite`の`crestSymbolName`/`crestTintHex`、描画は
  `CrestBadgeCatalog`（`Komap/Views/Stamps/CrestBadge.swift`））
- 御朱印を1件獲得するごとに50pt、ウォーキング中に自由なタイミングで写真を投稿すると1枚10pt
  （史跡の御朱印時の写真とは別枠）、歩いた距離に応じても1kmあたり10pt（端数の距離分も比例して
  加算）を獲得できる。「My Trips」の「時空ポイント」カードから開ける履歴は、旅（`WalkRoute`）
  ごとに新しい順でグルーピングし、それぞれ御朱印ポイント・写真投稿ポイント・歩いたポイントの
  内訳とその旅の合計を表示する（どの旅にも紐付かない古いデータは「その他」にまとめる）
- 「My Trips（私の時空旅）」タブで、歩いた記録を古地図ごとにグルーピングして一覧表示
  （直近3件のみ表示し、「それ以前を表示」で全件展開）。日時は`YYYY/M/D HH:MI`形式で表示。
  御朱印・アップした写真（チェックポイント／プラスポイントに分けて4枚横並び）・
  保存した物語・感想（メモ）もまとめて見返せる
- 「マイ時空旅」の「時空ポイント」カードの下にある「後から旅を追加」から、GPS記録の
  「スタート」を使わずに、スマートウォッチや他アプリで記録済みのGPXファイル（`.gpx`）を
  取り込んで時空旅を追加できる。使った古地図を選んでGPXファイルを選ぶだけで、
  `<trkpt>`/`<rtept>`の軌跡（`<time>`があれば開始・終了日時もそのまま）を読み取って
  `WalkRoute`として保存する（`Komap/Services/GPXParser.swift`）
- 「My Trips」タブ上部のセグメントピッカーで「マイ時空旅」「マイ御朱印」「みんなの旅」の
  3つを切り替えられる。「マイ時空旅」は一番上に「時空ポイント」カードを配置。「マイ御朱印」は
  同梱・登録済みの古地図ごとに獲得済み御朱印をまとめて見られる一覧（旧・マップ左上の
  専用アイコンから開いていたものをここに統合）。「みんなの旅」はWeb版と同じ`sharedTrips`
  （自分の公開分も含む）を開始日時が新しい順に、左にサムネイル写真を添えた行で一覧表示し、
  タップすると旅日記・御朱印/投稿写真の説明・写真（タップで拡大）を見られる閲覧専用の
  詳細シートが開く
- 「みんなの旅」の一番上には、今週のポイントが多い順の全ユーザーランキング
  （1位には王冠アイコン、ユーザー名・今週のポイント・通算ポイントを表示）を掲出。
  右上の「友達を招待」から、メールアドレス（相手が未サインインでも送れ、後でサインインした時に
  届く）またはユーザー名（表示名の前方一致検索）で友達申請を送れ、届いた申請はその場で
  承認・却下できる（相互承認で成立する`friendships`。ランキング自体は友達に限らず全ユーザーが
  対象）
- マップ画面左上に「マイ時空旅」「古地図選択」、右上に「セットアップ」のボタンを配置し、
  メニューを開かずワンタップでそれぞれの画面・シートへ移動できる（御朱印は「マイ時空旅」の
  「マイ御朱印」タブから見るため、マップ画面には専用アイコンを置いていない）
  （「このアプリについて」セクションに、GitHub READMEへの「Komapの使い方」リンクと、
  Amazonへの「Komapの作り方 Kindle本」リンクを設置）
- マップ上部中央に選択中の古地図名を表示。タップするとその地域の時代・簡単な説明と、
  チェックポイントの名前・簡単な説明の一覧をモーダルで見られる
- 「設定」の「写真の加工」で、御朱印・投稿写真の撮影・追加時に自動で適用する加工
  （なし／鮮やか／セピア／ビンテージ風）を選べる
- 「設定」の「記録の自動制御」（既定でオン）で、iPhone・Apple Watchのどちらで記録していても
  気づかず長時間GPSが回りっぱなしになるのを防ぐ。選んだ時間（1・5・10・20分、既定5分）
  以上動きがない状態が続くと記録を自動的に一時停止し（動き出すと自動で再開）、
  動いているかどうかによらず8時間を超えたら自動的に保存して記録を終了する
- Apple Watch単体・iPhoneでの伴走のどちらでも、動きがない自動一時停止・最長8時間の
  自動終了はWatch側の`WatchWorkoutLocationTracker`にも同じ仕組みで実装しており、
  iPhoneの「設定」の切り替え（オン/オフ・一時停止までの時間）はWatch接続時に自動で同期される
- 「設定」→「アドバンス設定」の一番上「AI設定」で、デフォルトのAIプロバイダー
  （OpenAI／Google／Anthropic、既定はOpenAI）と、それぞれのAPIキー、「新しい地図を追加」の
  オン・オフ、Google Mapsの設定状況を確認できる（キーはこの端末のKeychainに保存）。
  物語・旅日記・古地図検索などの生成処理は、ここで選んだプロバイダーのAPIを
  `AIClient`経由で呼び出す（OpenAI: gpt-4o-mini／Google: gemini-2.5-flash／
  Anthropic: claude-haiku-4-5。画像生成はOpenAI: gpt-image-1／Google: gemini-2.5-flash-image）。
  選択中のプロバイダーのキーが未設定なら、そのプロバイダー名で入力を案内する。
  GoogleのAPIキーで「blocked」エラーが出る場合は、キーの「APIの制限」に
  Generative Language APIが許可されていないため、Google AI Studioで作ったGemini用の
  キーを使うか、Cloud ConsoleでそのキーにこのAPIを許可する
- 「設定」→「アドバンス設定」→「連携機能」から、同じWi-Fi上の外部機器と連携できる
  - **連携カメラ**: ホスト名/IPを設定すると、御朱印チェックイン・写真投稿の画面に
    「連携カメラで撮る」が追加される（画像バイナリを直接返すタイプ、JSONで画像URLを
    返すタイプのどちらにも対応）
  - **連携プリンター**: 撮影・追加のたびに自動転送するトグルに加え、御朱印・投稿写真の
    詳細画面の「連携プリント」ボタンからその場で転送できる。転送方式（直接送信の
    multipart/form-data、または画像をアップロードしてURLを渡すGET）・大きさ（極小/小/中/大）・
    画質・ファイル形式（JPEG/PNG）・白黒変換を設定できる。設定画面の「テストプリント」から、
    入力したURL（既定`https://komap.ktrips.net/`）のQRコードを実際に連携プリンターへ
    送信して動作確認でき、失敗した場合はエラー内容（HTTPステータスや接続エラーの理由）を
    その場に表示する。転送先がHTTPステータス413（Payload Too Large）を返した場合は、
    M5Stackなど簡易なHTTPサーバーのバッファ上限を超えていることが多いため、
    「写真の大きさ」を下げる・「転送方式」を「写真のURLを渡す」に切り替えるよう
    具体的に案内するメッセージを表示する
- 投稿した写真を開くと、同じ時空旅の他の写真へ左右のフリックで移動できる。
  チェックイン（御朱印）の詳細と投稿写真の詳細は、写真の下を同じ2段の表示にそろえている
  （`PhotoDetailActionRow`）: 1段目に日付（左）と「公開／非公開」「削除」（右）、2段目に
  「写真を変更」「連携カメラ」「連携プリント」を横一線。「写真を変更」を押すとまずカメラが開き、
  左下のボタンからライブラリの写真にも切り替えられる。「非公開」は時空旅自体は公開中でも、
  その写真だけ「みんなの時空旅」から外す。「削除」はクラウド上のコピーも含めて削除する
- **旅の動画**: 時間旅の詳細画面の旅日記ボタンの下の「動画を再生」で、歩いた軌跡の上を
  アイコンが進み、写真（投稿写真・写真つきの御朱印）の地点で写真を大きく（動いている
  ポイントから遠い側にずらして）表示する動画（MP4、720px幅の縦長）を作って再生する。背景は
  画面に表示中の地図（古地図・チェックポイント入り）のスナップショット。動画は端末に保存して
  再利用し（長押しで作り直し）、作成後は再生ボタンの右に共有ボタンを出す（共有シートの
  「ビデオを保存」で写真ライブラリへ保存できる）。サインイン中はクラウド（Storage）にも上げ、
  共有リンクを旅日記の末尾（と「旅の動画を見る」ボタン。Webの旅日記にも同じリンクが載る）にセットする
- 時間旅の詳細画面は、名前（使った古地図）＋公開状況（例：「公開中」「自分だけ」「マップ非表示」）
  ／日付・距離・歩数・時間（`YYYY/M/D HH:MI`形式）／御朱印・写真・いいねの件数／感想と
  「旅日記を作成する」ボタン／御朱印・チェックポイント／投稿した写真／コメント、の順に
  整理して表示する。公開状況の表示をタップすると、そのままメニューで公開範囲
  （公開／自分だけ／非表示）を切り替えられる
- 「旅日記を作成する」から、その旅の名前・使った古地図・巡った御朱印スポットの詳細・
  投稿写真・感想をもとに、AIが「旅日記」を生成する（OpenAI APIキーが必要）。御朱印スポットの
  詳細は、既にAIで生成済みなら（チェックポイント詳細シートと同じキャッシュを）そのまま
  再利用し、無ければこの時に生成してキャッシュに保存するため、アプリの他画面と旅日記とで
  内容が一致する。生成済みなら「旅日記を読む」ボタンとその場で作り直せる再生成ボタンに
  切り替わる。旅日記画面は、時間旅の詳細画面とほぼ同じヘッダー情報（名前・公開状況・日時・
  距離・歩数・件数。ただし名前の横の古地図名は表示しない）・AIが書いた200字程度のサマリー
  （見出しは「（使った古地図名）の時空旅」）・歩いたルートの地図・御朱印・チェックポイント
  （写真＋説明）・投稿した写真（写真＋説明）をこの順に並べた、見返して楽しいスクラップブック
  形式で表示する。旅日記があるかどうかは「My Trips（私の時空旅）」一覧にも📖アイコンで
  表示される（Web版の一覧も同様）。投稿写真の見出しは、付けた名前があればそれを、
  無ければGPSから取得した場所名を使う（名前を付けていて場所名も別にある場合は場所名を
  小さく添える）。写真をタップすると前後にスワイプできる詳細シートが開いて大きく見られる
- 時間旅の詳細画面のヘッダーは「マイ時空旅：（使った古地図名）」。公開中の時空旅では、
  いいねの横と右上「...」メニューの両方から、その旅の要約カード画像を生成し、
  Web版の個別URL（`komap.ktrips.net?t=<短縮ID>`）を添えたメッセージ
  「Komapで古地図巡りしよう！旅日記はこちら（URL）」と一緒に、標準の共有シート
  （LINE・SNSなど）で送れる。要約カード画像の地図部分は、画面に表示中の地図
  （現在地図＋古地図オーバーレイ＋歩いたルート＋御朱印マーカー）をそのままスナップショット
  したもの（取得できない場合のみ簡易描画にフォールバック）。御朱印・チェックポイントと
  投稿した写真は件数の上限なく全件を並べて表示する。共有URLの短縮IDは、時空旅のUUID
  （16バイト）をBase64URLエンコードした22文字で、サーバー側の対応表を持たない可逆変換
  （`Komap/Models/UUID+ShortID.swift`／Web側は同じロジックの`web/src/lib/tripShortId.ts`）。
  以前発行した`?trip=<UUID>`形式のリンクも引き続き開ける

### クラウド連携
- 追加した古地図をFirestore（`sharedOverlayMaps/{id}`）とStorage（`sharedOverlayMaps/{uid}/{id}.jpg`）で
  公開でき、他のユーザーが「みんなの古地図」から自分の端末に取り込める（読み取りは誰でも可、
  書き込み・削除は持ち主のみ。ルールは`firebase/*.rules`に追加済みで、
  `firebase deploy --only firestore:rules,storage`で反映する）
- Googleでサインインすると、保存した地点・御朱印・時間旅（歩いたルート）・投稿写真がクラウド
  （Firestore）に同期され、Webアプリからも同じ記録を閲覧できる
- 御朱印・投稿写真の画像本体はFirebase Storageへ自動アップロードされ、Web側やシェア時にも
  画像そのものを見られる
- Webアプリの「時空旅」タブは、サインイン後も自分の記録（My Trips）と他ユーザーが
  公開した時空旅の両方を一覧表示する（自分の記録が重複しないよう、公開中の
  自分の記録は「自分の記録」側にのみ表示）。公開されている記録（自分の公開中の
  記録・他ユーザーの記録のどちらも）には🌐アイコンを表示し、サインイン中であれば
  自分の記録に限り一覧・詳細から時空旅の名称・感想を直接編集できる
- 時空旅の詳細では、歩いたルートの地図に実際に使った古地図をオーバーレイ表示。
  統合済みの古地図ID（後述）を使う過去の記録・地点でも、統合先の古地図（タイトル・画像）を
  正しく表示する（iOSアプリ側も同様に統合先を解決して表示）
- 時空旅（`sharedTrips`）にいいね・コメント機能を搭載。WebアプリとiOSアプリ（マイ時空旅の
  一覧・詳細）のどちらから付けても同じFirestoreサブコレクション（`likes`/`comments`）に
  記録され、双方向に反映される
- Web公開ページ（`komap.ktrips.net`）の時空旅詳細は、iOSアプリで旅日記を開いた時と同じ
  順序（ヘッダー情報／サマリー／地図／御朱印・チェックポイント／投稿した写真）で表示する。
  サマリーの見出しは「（使った古地図名）の時空旅」。AI呼び出しはiOSアプリ側のみで行い、
  Web側は生成済みのMarkdown本文と、公開時に一緒に同期される御朱印・投稿写真それぞれの
  説明文（アプリの旅日記と同じ内容）をそのまま表示するだけ。旅日記が未生成の時空旅では、
  サマリー部分だけ省いてヘッダー情報・地図・御朱印・写真を表示する。ヘッダーの
  御朱印・写真・いいねの件数行では、いいねはコンパクトなアイコンボタン（❤️/🤍＋件数）と
  して埋め込み、投稿者名は「投稿者：」ラベルを付けず日付の右横に表示する。日付・投稿者名の
  行には、歩いた距離・歩数・時間も同じ1行に並べて表示する
- 個別の時空旅は`komap.ktrips.net?t=<短縮ID>`（旧`?trip=<UUID>`形式も引き続き有効）の
  ようなURLで直接リンクできる。選択している時空旅IDはURLのクエリパラメータと常に同期し、
  ブラウザの戻る/進むにも追従する（`web/src/lib/useSelectedTripId.ts`）
- 未サインインの訪問者でも、Web公開ページ（`komap.ktrips.net`）で「そうだ、時空旅しよう」
  としてサインインなしに公開済みの時空旅（sharedTrips）を地図・写真つきで閲覧できる。
  現在そのページを見ている人数（閲覧人数）もリアルタイムに表示される
- Web版に管理者専用の「管理者レポート」タブ（管理者自身のサインイン時のみ表示）があり、
  既存のFirestoreデータから「サインインのみ／時空旅を開始／御朱印を収集／時空旅を共有済み」
  というユーザーの利用フェーズを集計して確認できる
- Web公開ページ右上には、時空旅の一覧を見ている間は「使い方」ボタン（Web版でできることを
  簡潔にまとめつつ、iOSアプリでできることを強く訴求するモーダルを表示。末尾の
  「Googleでサインインして、iOSアプリを始める」ボタンからそのままサインイン
  （→TestFlight招待メールの自動送信）に進める）、個別の時空旅を開いている間は
  代わりに「ログイン」ボタン（Googleサインインボタンと同じ配色）を表示する。モバイルでない
  （720px超の）画面幅では、時空旅を開いても左の一覧メニューは収納されずそのまま表示され続ける
  （`web/src/lib/useIsMobile.ts`、サインイン後・未サインインの公開閲覧画面どちらも対応）。
  「そうだ、時空旅しよう」「Googleでサインイン」の案内はモバイルでない時はヘッダー下ではなく
  右側の表示ペインの空状態（何も選んでいない時）に表示し、ヘッダーの「ログイン」ボタンは
  モバイルでない時は「旅を選んでいるかどうか」を基準に表示する
- Web版の時空旅詳細で御朱印・投稿写真のサムネイルをクリックすると、写真を大きく
  モーダル表示する（`PhotoLightbox`）
- サイドバー下部に「Komapの作り方 Kindle（一部無料）」ボタンがあり、Kindle原稿
  （`docs/GeoGameAppWithGoogleMap.md`）の冒頭部分だけを切り出したプレビュー
  （`web/public/kindle-preview.md`）をその場で読める。プレビュー内・サイドバー最下部
  （「この続きはKindle本で」）の両方にAmazonの購入リンクを設置している
- 時空旅一覧はコンパクトな2行表示（1行目：旅名＋古地図名＋公開マーク、
  2行目：日付・距離・歩数・投稿者名・いいね数・コメント数）
- 「使い方」モーダルの末尾、およびiOSアプリの「設定」→「このアプリについて」に、
  現在のアプリバージョン（例：`1.0 (22)`）を表示する。iOS側はBundleから動的に
  読むため常に実態と一致するが、Web側は手動で更新する定数（`web/src/version.ts`）
- iPhoneでWeb公開ページを「ホーム画面に追加」すると、iOSアプリ本体と見分けられる
  よう「WEB」の帯を付けた専用アイコン（`apple-touch-icon.png`）が使われる

## 技術構成

| 項目 | 内容 |
|---|---|
| iOS UI | SwiftUI（iOS 17+） |
| iOS 地図 | Google Maps SDK for iOS（Swift Package Manager） |
| 位置情報 | CoreLocation |
| 歩数 | CMPedometer + HealthKit（歩数の読み取りのみ） |
| Watch連携 | Apple Watch単体アプリ（WatchOS）+ WatchConnectivity |
| ローカル保存 | SwiftData（保存した地点・物語・時間旅・御朱印・投稿写真） |
| AI | デフォルトのプロバイダー（OpenAI／Google Gemini／Anthropic Claude）のAPIを`AIClient`経由で呼び出し。画像生成はOpenAI・Google |
| 古地図画像の検索 | 国立国会図書館サーチ（OpenSearch）+ デジタルコレクションIIIF、Wikimedia Commons（いずれもAPIキー不要） |
| 動画生成 | AVFoundation（`AVAssetWriter`）で軌跡・写真をフレーム描画してMP4化 |
| クラウド同期 | Firebase Authentication（Googleサインイン） + Cloud Firestore + Firebase Storage（画像） |
| Webアプリ | Vite + React + TypeScript、Firebase JS SDK、Google Maps JavaScript API |
| iOSプロジェクト管理 | [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`project.yml` から `.xcodeproj` を生成） |
| CI/CD | GitHub Actions（`main`へのpushでWebアプリをFirebase Hostingへ自動デプロイ） |

`.xcodeproj` はリポジトリにコミットせず、`project.yml` から都度生成する運用です（`.gitignore` 済み）。

## リポジトリ構成

```
project.yml                 # iOS: XcodeGenのプロジェクト定義（iOS + Watchの両ターゲット）
Config/Secrets.xcconfig     # iOS: APIキー（Google Maps）などのビルド設定
Komap/                      # iOSアプリ本体（詳細は後述）
Komap Watch App/             # Apple Watch単体アプリ（スタート/一時停止/終了・保存確認など）
firebase.json               # Firebase Hosting / Firestore の設定
.firebaserc                 # Firebaseプロジェクトのエイリアス（要編集）
firebase/
  firestore.rules            # Firestoreセキュリティルール（本人のplaces/stamps/walkRoutes/photoPostsのみ読み書き可、sharedTrips・sharedOverlayMapsは閲覧のみ全員可）
  firestore.indexes.json
  storage.rules               # Firebase Storageセキュリティルール（御朱印・投稿写真の画像本体。sharedPhotos・sharedOverlayMapsは未サインインの訪問者も含め閲覧のみ全員可）
scripts/
  clean-derived-data.sh       # KomapのXcode DerivedData（ビルド成果物・インデックス）を削除（launchdで毎日実行する想定）
web/                         # Webアプリ本体（Vite + React）
.github/workflows/
  deploy-web.yml              # main へのpushでWebアプリをFirebase Hostingへ自動デプロイ
docs/
  CHANGELOG.md                # 主な機能追加・変更の更新履歴
  GeoGameAppWithGoogleMap.md  # 本アプリの開発・収益化手法をまとめたKindle向け原稿（Markdown）
  Komap_週末リリースと収益化ガイド.docx # 上記原稿をKindleペーパーバック判型（8.27x10.11in）で書き出したWord版
```

---

## Part 1: iOSアプリのセットアップ

### 1-1. 前提ツール

- Xcode（最新版を推奨。iOS 17以降のシミュレータ/実機が必要）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）

### 1-2. Google Maps APIキーの取得と設定

1. [Google Cloud Console](https://console.cloud.google.com/) でプロジェクトを作成し、
   「Maps SDK for iOS」を有効化してAPIキーを発行します。
   （手順: https://developers.google.com/maps/documentation/ios-sdk/get-api-key）
2. `Config/Secrets.xcconfig` を開き、`GOOGLE_MAPS_API_KEY` に発行したキーを設定します。

```
GOOGLE_MAPS_API_KEY = ここに実際のAPIキーを貼り付け
```

> このキーが未設定（デフォルト値のまま）の場合、アプリ起動時にセットアップ案内画面が表示され、
> 地図タブは利用できません。

### 1-3. AI APIキーの設定

- 使いたいAIプロバイダーのAPIキーを発行してください:
  [OpenAI Platform](https://platform.openai.com/)（既定）、
  [Google AI Studio](https://aistudio.google.com)（Gemini）、Anthropic Console（Claude）。
- キーはビルド時に設定する必要はありません。アプリを起動し、「設定」→「アドバンス設定」→
  「AI設定」でデフォルトのプロバイダーを選び、そのキーを入力すると、端末のKeychainに
  安全に保存されます。画像の生成（ファンタジー地図・地図のアップデート）はOpenAI・Googleのみ対応です。
- （任意）`Config/Secrets.xcconfig` の `OPENAI_API_KEY_DEFAULT` に設定すると、
  初回起動時のOpenAI用デフォルト値として使われます（開発・検証用途を想定）。

### 1-4. Firebase（Web連携）のセットアップ

Web（`map.ktrips.net`）で「自分のマップ」を見られるようにするには、Firebaseの設定が必要です。
不要であればスキップしても、iOSアプリ単体（ローカル保存のみ）は動作します。

1. [Firebase Console](https://console.firebase.google.com/) で新しいプロジェクトを作成します。
2. 「Authentication」→「Sign-in method」で **Google** プロバイダを有効化します。
   - GoogleサインインはFirebaseプロジェクト自身のOAuthクライアントを自動的に使うため、
     追加のキー発行は不要です。「有効にする」→サポートメールを選択→保存、のみで使えるようになります。
   - iOS側で使うには、後述の「1-4-1. iOSでGoogleサインインを使うための追加設定」も行ってください。
3. 「Firestore Database」を作成します（本番モードでOK。ルールは後述のものをデプロイします）。
3-1. 「Storage」を開き、「開始する（Get started）」でStorageバケットを作成します
   （御朱印・投稿写真の画像本体を保存するために必要です）。**バケットのリージョンは
   後から変更できない**ため、利用者に近いリージョン（例: `asia-northeast1`）を選んでください。
   このバケットを作成しないまま`firebase deploy`でStorageルールをデプロイしようとすると、
   `Firebase Storage has not been set up on project ...` というエラーで失敗します。
4. 「プロジェクトの設定」→「マイアプリ」で **iOSアプリ** を追加します。
   - Bundle ID には `project.yml` の `PRODUCT_BUNDLE_IDENTIFIER`（既定値 `com.komap.Komap`）を入力。
   - ダウンロードした `GoogleService-Info.plist` を `Komap/Resources/GoogleService-Info.plist`
     に配置してください（このファイルは`.gitignore`済みで、公開リポジトリにはコミットされません）。
5. 同じFirebaseプロジェクトに **Webアプリ** も追加し、表示された設定値を
   `web/.env` に設定します（Part 2を参照）。
6. Firebase CLIをインストールし、Firestoreのセキュリティルールをデプロイします。

> **注記: Apple Sign-inについて**
> このアプリはSign in with Appleには対応していません。Sign in with Appleの
> Capabilityは、無料のApple ID（Personal Team）では使用できず、有料のApple
> Developer Program（年間$99）への登録が必須のためです。Google
> サインインはこの制約がなく、無料のApple IDでも問題なく使えます。
> 有料のDeveloper Programに登録済みで、Apple Sign-inも追加したい場合は、
> `project.yml` の `Komap` ターゲットに以下の `entitlements` セクションを追加し、
> `Komap/Services/AuthService.swift` にApple版のサインイン処理
> （`ASAuthorizationController` を使ったフロー）を実装してください。
>
> ```yaml
> entitlements:
>   path: Komap/Komap.entitlements
>   properties:
>     com.apple.developer.applesignin:
>       - Default
> ```

```bash
npm install -g firebase-tools
firebase login
# .firebaserc の "YOUR_FIREBASE_PROJECT_ID" を実際のプロジェクトIDに書き換えてから:
firebase deploy --only firestore:rules,storage
```

> Storageルールのデプロイ対象は `storage:rules` ではなく `storage` を指定してください。
> このプロジェクトのようにStorageバケットが1つだけの構成では、`storage:rules`は
> `Could not find rules for the following storage targets: rules` というエラーで
> 失敗します（`storage:rules`は`firebase.json`で複数バケットをtarget指定している
> 構成向けの書き方です）。また、上記の手順3-1でStorageバケットを作成する前に
> このコマンドを実行すると失敗します。

> `firebase/firestore.rules` は「自分の `users/{uid}/places` `stamps` `walkRoutes`
> `photoPosts` 配下のみ読み書き可能、`sharedTrips`（みんなの時空旅）はサインインしていれば
> 誰でも閲覧可・書き込みは本人のみ」というルールです。iOSアプリ・Webアプリはどちらも
> このルールの下で、同じFirebase Authenticationの `uid` を使ってアクセスします。

### 1-4-1. iOSでGoogleサインインを使うための追加設定

上記手順で `GoogleService-Info.plist` を配置していれば、GoogleサインインのクライアントID
自体は自動的に読み込まれます。ただし、認証完了後にアプリへ戻ってくるためのURL Schemeを
別途設定する必要があります。

1. 配置した `GoogleService-Info.plist` を開き、`REVERSED_CLIENT_ID` の値
   （`com.googleusercontent.apps.` から始まる文字列）をコピーします。
2. `Config/Secrets.xcconfig` の `GOOGLE_REVERSED_CLIENT_ID` に、コピーした値を貼り付けます。

```
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

3. `xcodegen generate` を再実行して、Info.plistのURL Schemeに反映してください。

> この値を設定しないと、Googleサインインのボタンを押してもアプリに認証結果が
> 返ってこず、サインインが完了しません。

### 1-5. プロジェクトの生成とビルド

```bash
cd kmap
xcodegen generate
open Komap.xcodeproj
```

Xcodeが開いたら、Signing & Capabilities でご自身のDevelopment Teamを選択し、
シミュレータまたは実機を選んで実行してください（Googleサインインはシミュレータでも
ブラウザ経由でサインインできます）。

`project.yml` を変更した場合は、再度 `xcodegen generate` を実行してください。

---

## Part 2: Webアプリ（map.ktrips.net）のセットアップ

Webアプリは `web/` ディレクトリにあります。iOSアプリと同じFirebaseプロジェクトの
Firestoreを読むことで、「自分のマップ」をブラウザからも閲覧できます。

> 今回作成したのはWebアプリのコードとFirebase設定ファイルのみです。
> 実際に `map.ktrips.net` というドメインで公開するには、Firebase Hostingへのデプロイと
> ドメインのDNS設定をご自身のFirebase/ドメイン管理アカウントで行ってください。

### 2-1. 環境変数の設定

```bash
cd web
npm install
cp .env.example .env
```

`.env` を開き、Firebase Console の「プロジェクトの設定」→「マイアプリ」→Web アプリで
表示される値と、Web用に発行したGoogle Maps APIキー（JavaScript API有効化、
HTTPリファラーを `map.ktrips.net` や `localhost` に制限したもの）を設定してください。

```
VITE_FIREBASE_API_KEY=...
VITE_FIREBASE_AUTH_DOMAIN=...
VITE_FIREBASE_PROJECT_ID=...
VITE_FIREBASE_STORAGE_BUCKET=...
VITE_FIREBASE_MESSAGING_SENDER_ID=...
VITE_FIREBASE_APP_ID=...
VITE_GOOGLE_MAPS_API_KEY=...
```

### 2-2. ローカルで動作確認

```bash
npm run dev
```

表示されたローカルアドレス（既定では `http://localhost:5173/`）をブラウザで開いてください。
iOSアプリで使ったのと同じGoogleアカウントでサインインすると、
iOS側で保存した地点がリアルタイムに表示されます。

### 2-3. 本番公開（map.ktrips.net）へのデプロイ

```bash
cd web
npm run build
cd ..
firebase deploy --only hosting
```

デプロイ後、Firebase Console の「Hosting」→「カスタムドメインを追加」で
`map.ktrips.net` を接続し、案内されるDNSレコード（TXT/A等）をドメインのDNS設定に
追加してください。有効化されるまで数分〜数十分かかることがあります。

GoogleサインインはWeb上では追加設定なしで動作します（Firebase Consoleで
Googleプロバイダを有効化するだけです）。ただし本番ドメイン（`map.ktrips.net`）を
Firebase Authenticationの「承認済みドメイン」に追加しておく必要があります
（Authentication → Settings → Authorized domains）。カスタムドメインを複数接続した場合は、
それぞれをこの承認済みドメインに追加してください。

### 2-4. GitHub Actionsでの自動デプロイ

`web/**`・`firebase.json`・`firebase/**` を変更して`main`ブランチにpushすると、
`.github/workflows/deploy-web.yml` が自動的にWebアプリをビルドし、Firebase Hosting と
Firestore/Storageルールへデプロイします（手動で`workflow_dispatch`から実行することも可能）。

利用するには、GitHubリポジトリの Settings → Secrets and variables → Actions に、
以下のRepository secretsを登録してください。

| Secret名 | 内容 |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | デプロイ用サービスアカウントのJSONキー（下記手順で発行） |
| `VITE_FIREBASE_API_KEY` 他 `VITE_FIREBASE_*` | `web/.env` と同じ値（2-1を参照） |
| `VITE_GOOGLE_MAPS_API_KEY` | `web/.env` と同じ値 |

サービスアカウントは、Hosting・Firestore/Storageルールのデプロイだけができる最小権限で
発行することを推奨します。`roles/firebasestorage.admin`が無いと、Storageルールの
デプロイだけが `Deploy to Firebase Hosting + Firestore/Storage rules` ステップで
失敗します（Hosting・Firestoreは成功するため気づきにくい点に注意してください）。

```bash
gcloud iam service-accounts create github-actions-deploy \
  --project=YOUR_FIREBASE_PROJECT_ID \
  --display-name="GitHub Actions (Firebase deploy)"

for role in roles/firebasehosting.admin roles/firebaserules.admin roles/firebasestorage.admin roles/datastore.indexAdmin; do
  gcloud projects add-iam-policy-binding YOUR_FIREBASE_PROJECT_ID \
    --member="serviceAccount:github-actions-deploy@YOUR_FIREBASE_PROJECT_ID.iam.gserviceaccount.com" \
    --role="$role"
done

gcloud iam service-accounts keys create github-actions-deploy-key.json \
  --iam-account=github-actions-deploy@YOUR_FIREBASE_PROJECT_ID.iam.gserviceaccount.com
```

発行した `github-actions-deploy-key.json` の**中身**（JSON全体）を `FIREBASE_SERVICE_ACCOUNT`
シークレットに貼り付けたら、ローカルのキーファイルは削除してください。漏洩した場合は
`gcloud iam service-accounts keys delete` で失効できます。

### 2-5. Googleサインイン時のTestFlight自動招待（Cloud Functions）

Web版でGoogleサインインすると、そのメールアドレス宛にTestFlightの外部テスト招待が
自動送信されるようになっています（`functions/src/index.ts` の `requestTestFlightInvite`）。
初回サインイン時に一度だけ送信され、以降は`testflightInvites/{email}` (Firestore) を見て
重複送信しません。

**前提条件**（すべて揃っていないと動作しません）:
- Firebaseプロジェクトが **Blazeプラン**（従量課金）であること（外部API通信にはCloud
  FunctionsのBlazeプランが必須）
- App Store Connectで対象アプリの**外部テスターグループ**が作成済みで、External Beta App
  Reviewを通過していること（このグループに追加されたテスターへ実際に招待メールが飛ぶ）
- App Store Connect API キー（Issuer ID・Key ID・`.p8`秘密鍵）を発行済みであること
  （App Store Connect → ユーザとアクセス → 統合 → App Store Connect API）

**セットアップ手順**:

```bash
cd functions
npm install
```

Cloud Functionsのシークレットとして、以下4つを登録します（値はGoogle Secret Managerに
保存され、リポジトリには一切残りません）。

```bash
firebase functions:secrets:set APPSTORE_CONNECT_ISSUER_ID
firebase functions:secrets:set APPSTORE_CONNECT_KEY_ID
# .p8ファイルの中身をそのまま貼り付ける（改行はそのままでOK）
firebase functions:secrets:set APPSTORE_CONNECT_PRIVATE_KEY
# App Store Connect > TestFlight > 対象の外部テスターグループのURLに含まれるID
firebase functions:secrets:set APPSTORE_CONNECT_BETA_GROUP_ID
```

デプロイ:

```bash
firebase deploy --only functions
```

デプロイ後、Web版で新しいGoogleアカウントを使ってサインインすると、そのメール宛に
Appleから「TestFlightでKomapをテストするよう招待されました」というメールが届きます。
送信状況は `firebase functions:log` で確認できます。

---

## 古地図データについて（重要な注意）

同梱している古地図は、大きく次の種類に分かれます（いずれも `Komap/Models/HistoricalOverlayMap.swift`
の `OldMapCatalog` で定義）。

- **イラスト画像**（江戸城周辺・浅草周辺）: このサンプルアプリのために生成した
  **古地図"風"のイラスト**で、実際の歴史史料をスキャンしたものではありません。
  「江戸城周辺（安政期）」には、もともと別の古地図だった「九段下・千鳥ヶ淵（靖国神社周辺）」
  「霞ヶ関・虎ノ門（大名屋敷と社寺）」のチェックポイントも統合済みで、南側に少し範囲を
  広げています（画像自体は変わらないため、南端付近はやや引き伸ばされた表示になります）。
- **実在の歴史地図**（本郷・谷中・上野（明治の文豪）／日本橋・神田明神／銀座・歌舞伎座／芝／神田／
  東海道／中山道／松尾芭蕉ゆかりの地／明治神宮・表参道、および「五色不動めぐり」）:
  「1891 Meiji Map of Tokyo or Edo, Japan」
  （Geographicus発行、1931年より前の発行につきパブリックドメイン。出典: Wikimedia Commons）
  の実画像（フル解像度3500×2610pxの原本）を、エリアごとに切り出す、または広域のまま
  使ったものです。位置合わせは地図上の目印（不忍池・皇居のお堀等）を基準に手作業で
  行った概算で、史料的に厳密な測量座標ではありません。「五色不動めぐり」は、専用に
  切り出した画像を用意せず広域画像をそのまま使い回しているテーマ別ルートで、旧東京市の
  外側にあたる地域（目黒・世田谷・品川区南部など）も含む広域表示のため、地図の密度が粗く、
  位置合わせもより概算になります。「東海道」「中山道」「松尾芭蕉ゆかりの地」「明治神宮・
  表参道」は、同じ原本から専用に切り出した画像（それぞれ日本橋〜京橋・新橋、
  本郷〜小石川・巣鴨、深川〜浅草・本所、原宿・代々木一帯にかけてのエリア）を使っていますが、
  原本の解像度・記載範囲の都合上、品川宿・板橋宿・千住といった各街道の終点そのものまでは
  画像に収まっていません（チェックポイント自体は現在地の緯度経度に正しく配置されるため、
  御朱印機能自体には影響しません）。「松尾芭蕉ゆかりの地」は画像自体が正方形（内容は横幅の
  半分弱で左右が余白）のため、位置合わせ座標の東西の範囲を余白比率に合わせて正方形になる
  まで広げ、`GMSGroundOverlay`による縦方向への引き伸ばしを防いでいます。なお
  「明治神宮・表参道」は、明治神宮の鎮座
  （1920年）より前の1891年の地図のため、神社そのものは描かれておらず、その前身にあたる
  代々木御料地・青山練兵場一帯が写っています。「本郷・谷中・上野」は、もともと別の古地図
  だった「上野（寛永寺・不忍池周辺）」を統合済みで、東側に少し範囲を広げています。
  「銀座・歌舞伎座」は当初、自作のオリジナル「古地図風」イラストでしたが、
  日本橋・神田明神と同じこの実測図（画像自体が銀座・築地周辺まで含む範囲で
  撮影・位置合わせされている）を使うよう変更し、南側（浜離宮・大門）まで範囲を広げて
  同じ画像・位置合わせを使い回しています。
- **現在の地図から加工した「古地図風」画像**（赤坂・紀尾井町／麻布・六本木／
  大山街道〈赤坂〜二子玉川〉／神楽坂・早稲田）:
  実際の歴史史料ではなく、現在の地図から作成した画像に
  セピア調のフィルター（減彩・セピア変換・ビネット・粒状ノイズ）をかけて古地図"風"に
  加工したものです。「赤坂・紀尾井町」「麻布・六本木」は、アプリ内の現在の地図
  （チェックポイントのピン付き）のスクリーンショットから、ピンアイコン類をOpenCVの
  [inpaint](https://docs.opencv.org/)で除去した上でフィルターをかけています。
  「大山街道」「神楽坂・早稲田」は、
  [OpenStreetMap](https://www.openstreetmap.org/copyright)のタイル画像
  （© OpenStreetMapコントリビューター、ODbL）をそのまま結合してフィルターをかけたもので、
  ピン等が写り込んでいないためinpaintは行っていません。位置合わせ座標は、画像に写っている
  実在の駅・交差点（四ツ谷・青山一丁目・麻布十番など）の緯度経度、またはOpenStreetMapタイル
  座標から正確に算出しています。
- **Komap Global向けのオリジナル古地図イラスト**（アムステルダム／ヘルシンキ／ストックホルム／タリン）:
  実際の歴史史料ではなく、各都市の旧市街の地形（アムステルダムの運河環、ヘルシンキの群島と
  スオメンリンナ、ストックホルムの島々、タリンの城壁と塔）のシルエットを古地図風に描いた
  このアプリ用の完全オリジナルイラストです。チェックポイントは各5箇所
  （例: ダム広場・新教会／元老院広場・トゥオミオ教会／ストールシルカン／トームペア など）。
  iOS（`OldMapCatalog`・`HistoricSiteCatalog`）とWeb（`web/src/lib/oldMapCatalog.ts`・
  `web/src/lib/historicSiteCatalog.ts`、画像は`web/public/old-maps/`）で同じIDを使い、
  Firestoreの御朱印データを相互に参照できるようにしています。
- **アニメ・映画聖地巡礼向けのファンタジー地図画像**（「君の名は。」聖地巡礼／ジブリ映画の聖地巡り／
  東京トイレット（Perfect Days））:
  史実の古地図・現在の地図のセピア加工とは区別するため、深緑〜クリーム〜淡い金の配色・
  紙の質感・雲や木のシルエット・コンパスローズ・二重線の縁飾りを加えた、特定の作品の
  キャラクター・場面は再現しない汎用の冒険地図風デザインに加工したものです（元はOpenStreetMap
  のタイル画像。ただし「東京トイレット」は実在の道路データも使わない完全な自作イラスト）。
  「君の名は。聖地巡礼」は須賀神社・四ツ谷駅・ドコモタワー・バスタ新宿・
  カフェ ラ・ボエム（新宿御苑店）・SHIBUYA TSUTAYAを、「ジブリ映画の聖地巡り」は
  三鷹の森ジブリ美術館・井の頭恩賜公園・江戸東京たてもの園（千と千尋の神隠しの参考地）・
  聖蹟桜ヶ丘（耳をすませばの舞台）・日テレ大時計（宮崎駿デザイン）を、「東京トイレット」は
  映画『PERFECT DAYS』の舞台としても知られる、渋谷区内の公共トイレプロジェクト
  「THE TOKYO TOILET」の15施設（タコ公園のイカトイレ・森のコミチ・ザ・ハウスなど）を
  チェックポイントとした、現代の聖地巡礼スポット集です。

いずれの画像も、設定している緯度経度の位置合わせ座標
（`OldMapCatalog` 内の `southWest` / `northEast`）は、現在の地理に大まかに合わせた
**仮の値**です。

> **注記（古地図選択メニューについて）**: `OldMapCatalog.all` の件数が増えた結果、
> 以前はSwiftUIの `Menu` にそのまま並べていた選択肢が、iOS側の表示可能件数を超えた分を
> スクロールもできないまま黙って表示しなくなる問題が起きたことがある。そのため選択UIは
> `.sheet` + `List`（`OldMapPickerSheet`、`Komap/Views/Map/OverlayControlPanel.swift`）に
> しており、`OldMapCatalog` に何件追加してもスクロールで必ず選べる。今後古地図を追加する際も
> `Menu` へ戻さないよう注意する。一覧は「旧跡・名所巡り」「街道巡り」「アニメ・映画聖地巡礼」
> 「🌍 Komap Global（海外の旧市街）」の4セクションに分けており（`OldMapCatalog.Category` / `OldMapCatalog.category(of:)`）、
> 新しい古地図を追加する際は `categoryByID` にも分類を登録すること。

> **注記（古地図の画像サイズについて）**: Google Maps SDKにはグラウンドオーバーレイ用の
> テクスチャアトラスの上限があり、フル解像度の大きな画像のまま古地図を何度も切り替えると、
> ある地点から先の古地図が真っ白・あるいは一部だけしか描画されなくなることがある
> （`GoogleMapRepresentable.swift` 内のコメント参照）。単体選択時も
> `downsampledForSingleOverlay`（最長辺1600px）で縮小してから使うようにしているため、
> 新しい古地図画像を追加する場合も、この縮小処理を経由するパスを通すこと。

実際の史料に基づく古地図を使いたい場合は、次の手順で入れ替えてください。

1. 実際の古地図画像（できれば矩形に近い形でトリミング済みのもの）を用意する。
2. `Komap/Resources/Assets.xcassets` 内に新しいImage Setを追加し、画像を登録する。
3. `Komap/Models/HistoricalOverlayMap.swift` の `OldMapCatalog` に、
   画像名・時代・タイトルと合わせて、画像の南西端・北東端の緯度経度
   （できるだけ正確に位置合わせしたもの）を追加する。
4. `OldMapCatalog.all` に追加したエントリを登録すると、アプリ内のピッカーから選択できるようになる。
5. （任意）Web側でも時代ラベルを表示したい場合は、`web/src/lib/oldMapCatalog.ts` にも
   同じ `id` でエントリを追加してください。

## iOSアプリのプロジェクト構成

```
Komap/
  App/
    KomapApp.swift             # アプリのエントリーポイント（Google Maps / Firebase初期化）
  Models/
    SavedPlace.swift            # SwiftDataモデル（保存した地点・物語）
    WalkRoute.swift              # SwiftDataモデル（歩いた時間旅・軌跡）
    CollectedStamp.swift         # SwiftDataモデル（獲得した御朱印）
    WalkPhotoPost.swift          # SwiftDataモデル（投稿写真・ポイント）
    HistoricalOverlayMap.swift  # 古地図カタログ（画像・時代・位置合わせ座標）
    HistoricSite.swift           # 古地図ごとの史跡チェックポイント一覧
    TappedPoint.swift
  Services/
    LocationManager.swift       # 現在地・徒歩ルートの記録
    AIClient.swift              # デフォルトのAIプロバイダー（OpenAI/Google/Anthropic）へのテキスト・画像生成の共通クライアント
    AIHistoryService.swift      # AIで物語を生成
    TravelJournalService.swift  # AIで時間旅の記録から旅日記を生成
    KeychainStore.swift         # APIキーの安全な保存
    SecretsConfig.swift         # APIキーの読み込み口
    AuthService.swift           # Googleサインイン → Firebase Auth
    SyncService.swift           # Firestoreへの同期（地点・御朱印・時間旅・旅日記）
    WatchConnectivityManager.swift # Apple Watchとのコマンド・状態のやり取り
    OldMapSearchService.swift    # AI + 国立国会図書館/Wikimedia Commonsで新しい古地図を探す・作る（範囲の限定・ファンタジー地図）
    CustomOverlayMapStore.swift  # 追加した古地図（画像・ポイント・公開範囲）の端末内保存
    OverlayOverrideStore.swift   # 管理者による同梱の古地図への変更（上書き）の端末内保存
    OverlayMapShareService.swift # 追加した古地図のクラウド公開・取り込み（sharedOverlayMaps）
    TripVideoRenderer.swift      # 軌跡・写真から旅の動画（MP4）を書き出す
    TripVideoStore.swift         # 作った旅の動画の端末内保存
  Views/
    RootView.swift
    Map/                         # マップ画面・古地図オーバーレイ・古地図選択/詳細/編集/検索・みんなの古地図
    Shared/                      # 共通部品（カメラ、写真詳細のボタン行など）
    SavedPlaces/                 # 保存済み地点・時間旅の一覧・詳細
    MyTimeTrip/                  # 「My Trips」タブ（時間旅・御朱印・写真・物語）
    Stamps/                      # 御朱印のチェックイン画面・Komap Globalの紋章風バッジ
    Settings/                    # APIキー設定・Googleサインイン
  Resources/
    Assets.xcassets              # 古地図画像・アプリアイコンなどのアセット
    Info.plist                   # xcodegenが project.yml から自動生成（コミット対象外）
    GoogleService-Info.plist     # 各自のFirebase設定（要配置・コミット対象外）
Komap Watch App/
  ContentView.swift              # Watch単体の記録UI（スタート/一時停止/完了・保存確認）
  WatchSessionManager.swift      # Watch単体のGPS記録 + iPhoneとの連携
  WatchWorkoutLocationTracker.swift # HealthKitワークアウトセッション経由の位置情報取得
```

## 既知の制約・今後の拡張候補

- 古地図の位置合わせはサンプル用の仮座標です（上記「古地図データについて」を参照）。
- Google MapsのAPIキーはアプリ内からは変更できません（ビルド時のxcconfigのみ）。
  実運用では課金設定・APIキーの制限（Bundle ID制限など）も併せて設定してください。
- AIの物語生成・旅日記生成・古地図検索は、選んだプロバイダーのAPIキーが必要で、通信環境とAPI利用料が発生します。
- 管理者による同梱の古地図の変更は、その端末内の「上書き」で、他のユーザーには配られません
  （全員に反映するには、クラウドから配る仕組みが別途必要）。
- 「みんなの古地図」「旅の動画のリンク」を使うにはFirebaseの設定とサインインが必要で、
  `sharedOverlayMaps`のルールはデプロイが必要です。
- Firebase未設定のままでもiOSアプリは起動できますが、クラウド同期・Web連携・
  Googleサインインは利用できません（設定タブにその旨のメッセージが表示されます）。
- Sign in with Appleは未対応です（無料のApple IDでは使えないため。上記1-4の注記を参照）。
- Webアプリの「時空旅」タブは、サインイン後は自分の記録と他ユーザーが公開した
  時空旅の両方を一覧できます（距離・時間・歩数などの詳細、選択した時間旅の
  地図（軌跡）・投稿写真・御朱印も表示）。未サインインの訪問者向けには、
  同じ公開データをWeb公開ページ（`komap.ktrips.net`）でも閲覧できます。
- `OldMapCatalog` にエントリを追加するだけで、選べる古地図を拡張できます
  （Web側でも表示したい場合は `web/src/lib/oldMapCatalog.ts` にも同じ `id` で追加）。
