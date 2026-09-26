#!/usr/bin/env node
// iOS（Swift）とWeb（TypeScript）に二重に持っている、同梱の古地図・史跡チェックポイントの
// 一覧が食い違っていないかを確かめる。片方だけに追加すると、Webでその古地図が重ならない・
// 御朱印の名前が出ないといった不具合になるため、CI（.github/workflows/catalog-sync.yml）で実行する。
//
//   node scripts/check-catalog-sync.mjs
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const read = (path) => readFileSync(join(root, path), "utf8");

/** Swiftの`<型名>(` の直後の `id: "..."` を集める。 */
function swiftIDs(source, typeName) {
  const pattern = new RegExp(`${typeName}\\(\\s*id:\\s*"([^"]+)"`, "g");
  return new Set([...source.matchAll(pattern)].map((m) => m[1]));
}

/** TypeScriptのカタログ配列内の `id: "..."` を集める。 */
function tsIDs(source) {
  return new Set([...source.matchAll(/\bid:\s*"([^"]+)"/g)].map((m) => m[1]));
}

const checks = [
  {
    label: "古地図",
    ios: swiftIDs(read("Komap/Models/HistoricalOverlayMap.swift"), "HistoricalOverlayMap"),
    web: tsIDs(read("web/src/lib/oldMapCatalog.ts")),
  },
  {
    label: "史跡チェックポイント",
    ios: swiftIDs(read("Komap/Models/HistoricSite.swift"), "HistoricSite"),
    web: tsIDs(read("web/src/lib/historicSiteCatalog.ts")),
  },
];

let failed = false;
for (const { label, ios, web } of checks) {
  const onlyIOS = [...ios].filter((id) => !web.has(id));
  const onlyWeb = [...web].filter((id) => !ios.has(id));
  if (ios.size === 0 || web.size === 0) {
    console.error(`✗ ${label}: IDを読み取れませんでした（iOS ${ios.size}件・Web ${web.size}件）。スクリプトの読み取り方を確認してください。`);
    failed = true;
    continue;
  }
  if (onlyIOS.length === 0 && onlyWeb.length === 0) {
    console.log(`✓ ${label}: iOS・Webとも${ios.size}件で一致`);
    continue;
  }
  failed = true;
  console.error(`✗ ${label}: iOSとWebで一覧が食い違っています`);
  if (onlyIOS.length) console.error(`  iOSにだけある: ${onlyIOS.join(", ")}`);
  if (onlyWeb.length) console.error(`  Webにだけある: ${onlyWeb.join(", ")}`);
}
process.exit(failed ? 1 : 0);
