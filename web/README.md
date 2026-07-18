# Komap Web（わたしの時間旅行）

iOSアプリ「Komap 古地図巡り」で保存した地点を、ブラウザからも見られるWebアプリです。
Firebase Authentication（Sign in with Apple）でログインし、同じユーザーのFirestoreデータ
（`users/{uid}/places`）をリアルタイムに表示します。

セットアップ手順はリポジトリルートの `README.md` を参照してください。

## ローカル開発

```bash
cd web
npm install
cp .env.example .env   # Firebase / Google MapsのAPIキーを設定
npm run dev
```

## ビルド

```bash
npm run build
```

`dist/` に静的ファイルが出力されます。Firebase Hostingへのデプロイはリポジトリルートで

```bash
firebase deploy --only hosting
```

を実行してください（事前に `firebase login` / `.firebaserc` の projectId 設定が必要です）。
