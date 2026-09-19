#!/bin/bash
# Komap の Xcode DerivedData（ビルド成果物・インデックス）を削除する。
# いずれも Xcode が自動で作り直すキャッシュで、消しても次回のビルドが遅くなるだけ。
# 他のプロジェクトの DerivedData には触らない。ビルド中（xcodebuild 実行中）は何もしない。
# launchd（~/Library/LaunchAgents/net.ktrips.komap.clean-derived-data.plist）から毎日実行される。

set -u
DERIVED="$HOME/Library/Developer/Xcode/DerivedData"

if pgrep -x xcodebuild >/dev/null; then
  echo "xcodebuild 実行中のためスキップ"
  exit 0
fi

for dir in "$DERIVED"/Komap-*; do
  [ -d "$dir" ] || continue
  before=$(du -sk "$dir" 2>/dev/null | cut -f1)
  rm -rf "$dir/Build" "$dir/Index.noindex" "$dir/Logs" "$dir/ModuleCache.noindex"
  echo "$(date '+%F %T') $(basename "$dir"): 約$((before / 1024))MB 中のビルド成果物を削除"
done
