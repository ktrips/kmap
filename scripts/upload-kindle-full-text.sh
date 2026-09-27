#!/bin/bash
# Komap Plus の特典「Kindle本の全文（Web）」で配る原稿を、Firebase Storage の
# premium/kindle-full.md にアップロードする。このパスは storage.rules に一致する
# ルールが無いため、ブラウザからは直接読めない。Cloud Function（getKindleFullText）が
# Plus かどうかを確かめてから本文を返す。
#
# 使い方: scripts/upload-kindle-full-text.sh [原稿ファイル]
#   原稿ファイルを省略すると private/kindle/GeoGameAppWithGoogleMap.md を使う。
#   原稿は公開リポジトリには置かない（private/ は .gitignore 済み）。手元の原稿をここに置いてから実行する。
# 事前に `gcloud auth login` と、Firebaseプロジェクト（komapprj）の権限が必要。

set -euo pipefail
cd "$(dirname "$0")/.."

SOURCE="${1:-private/kindle/GeoGameAppWithGoogleMap.md}"
BUCKET="gs://komapprj.firebasestorage.app"

if [ ! -f "$SOURCE" ]; then
  echo "原稿ファイルが見つかりません: $SOURCE" >&2
  exit 1
fi

gcloud storage cp "$SOURCE" "$BUCKET/premium/kindle-full.md" \
  --content-type="text/markdown; charset=utf-8"
echo "アップロードしました: $BUCKET/premium/kindle-full.md"
