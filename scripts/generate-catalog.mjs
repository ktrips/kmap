#!/usr/bin/env node
// 古地図・史跡チェックポイントの一覧（catalog/*.json）から、iOS（Swift）と Web（TypeScript）の
// データファイルを生成する。一覧はこの JSON だけで管理し、生成したファイルは直接編集しない。
//
//   node scripts/generate-catalog.mjs          # 生成して書き出す
//   node scripts/generate-catalog.mjs --check  # 生成結果とリポジトリのファイルが一致するか確かめる（CI 用）
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const read = (path) => JSON.parse(readFileSync(join(root, path), "utf8"));
const { maps, mergedInto } = read("catalog/old_maps.json");
const { sites, mergedInto: siteMergedInto = {} } = read("catalog/historic_sites.json");

const HEADER = (source) =>
  `このファイルは scripts/generate-catalog.mjs が ${source} から生成したものです。直接編集しないでください。`;

// ---- 入力の確認（ID の重複・参照切れ）
const mapIDs = new Set();
for (const map of maps) {
  if (mapIDs.has(map.id)) throw new Error(`古地図のIDが重複しています: ${map.id}`);
  mapIDs.add(map.id);
}
const siteIDs = new Set();
for (const site of sites) {
  if (siteIDs.has(site.id)) throw new Error(`チェックポイントのIDが重複しています: ${site.id}`);
  if (!mapIDs.has(site.overlayMapID)) throw new Error(`${site.id} の古地図 ${site.overlayMapID} がありません`);
  siteIDs.add(site.id);
}
for (const [from, to] of Object.entries(mergedInto)) {
  if (!mapIDs.has(to)) throw new Error(`統合先の古地図 ${to}（${from}）がありません`);
}
for (const [from, to] of Object.entries(siteMergedInto)) {
  if (!siteIDs.has(to)) throw new Error(`統合先のチェックポイント ${to}（${from}）がありません`);
}

const num = (value) => (Number.isInteger(value) ? value.toFixed(1) : String(value));
const swiftComment = (lines, indent) =>
  lines.map((line) => (line === "" ? `${indent}//` : `${indent}// ${line}`)).join("\n");

// ---- Swift: 古地図
function swiftMaps() {
  const out = [`// ${HEADER("catalog/old_maps.json")}`, "", "import CoreLocation", "", "extension OldMapCatalog {"];
  for (const map of maps) {
    if (map.notes?.length) out.push(swiftComment(map.notes, "    "));
    out.push(`    static let ${map.swiftName} = HistoricalOverlayMap(`);
    out.push(`        id: "${map.id}",`);
    out.push(`        title: "${map.title}",`);
    out.push(`        era: "${map.era}",`);
    out.push(`        summary: "${map.summary}",`);
    out.push(`        imageAssetName: "${map.imageAssetName}",`);
    if (map.boundsNotes?.length) out.push(swiftComment(map.boundsNotes, "        "));
    out.push(`        southWest: CLLocationCoordinate2D(latitude: ${num(map.southWest[0])}, longitude: ${num(map.southWest[1])}),`);
    const last = map.bearing === undefined;
    out.push(`        northEast: CLLocationCoordinate2D(latitude: ${num(map.northEast[0])}, longitude: ${num(map.northEast[1])})${last ? "" : ","}`);
    if (!last) out.push(`        bearing: ${num(map.bearing)}`);
    out.push("    )", "");
  }
  out.push("    /// 選択可能な古地図の一覧（`catalog/old_maps.json`の順）。");
  out.push("    static let all: [HistoricalOverlayMap] = [");
  for (const map of maps) out.push(`        ${map.swiftName},`);
  out.push("    ]", "");
  out.push("    /// 古地図の分類（古地図選択シートのセクション分け）。同梱リストにない古地図は分類なし。");
  out.push("    static let categoryByID: [String: Category] = [");
  for (const map of maps.filter((m) => m.category)) out.push(`        "${map.id}": .${map.category},`);
  out.push("    ]", "");
  out.push("    /// 統合によって廃止されたID → 統合先IDの対応表。過去の記録に残る廃止IDを表示時に読み替える。");
  out.push("    static let mergedIntoID: [String: String] = [");
  for (const [from, to] of Object.entries(mergedInto)) out.push(`        "${from}": "${to}",`);
  out.push("    ]", "}", "");
  return out.join("\n");
}

// ---- Swift: 史跡チェックポイント
function swiftSites() {
  const out = [`// ${HEADER("catalog/historic_sites.json")}`, "", "import CoreLocation", "", "extension HistoricSiteCatalog {"];
  out.push("    /// 同梱の史跡チェックポイント（古地図ごとに、`catalog/historic_sites.json`の順。この順が地図上の番号になる）。");
  out.push("    static let all: [HistoricSite] = [");
  for (const site of sites) {
    if (site.group) out.push(`        // ${site.group}`);
    out.push("        HistoricSite(");
    out.push(`            id: "${site.id}",`);
    out.push(`            overlayMapID: "${site.overlayMapID}",`);
    out.push(`            name: "${site.name}",`);
    out.push(`            summary: "${site.summary}",`);
    if (site.notes?.length) out.push(swiftComment(site.notes, "            "));
    out.push(`            coordinate: CLLocationCoordinate2D(latitude: ${num(site.lat)}, longitude: ${num(site.lng)})`);
    out.push("        ),");
  }
  out.push("    ]", "");
  out.push("    /// 置き換えによって廃止されたチェックポイントID → 置き換え先IDの対応表（例: 個人の古地図を同梱の古地図に置き換えた時）。");
  out.push("    /// 過去の御朱印に残る廃止IDを、表示時・起動時の移行（`CatalogMigration`）で読み替える。");
  out.push("    static let mergedIntoID: [String: String] = [");
  for (const [from, to] of Object.entries(siteMergedInto)) out.push(`        "${from}": "${to}",`);
  out.push("    ]", "}", "");
  return out.join("\n");
}

// ---- TypeScript（Web）
function tsData() {
  const str = (value) => JSON.stringify(value.replace(/\\"/g, '"'));
  const out = [
    `// ${HEADER("catalog/old_maps.json・catalog/historic_sites.json")}`,
    "",
    'import type { HistoricSiteEntry } from "../historicSiteCatalog";',
    'import type { OldMapEntry } from "../oldMapCatalog";',
    "",
    "export const OLD_MAP_DATA: OldMapEntry[] = [",
  ];
  for (const map of maps) {
    out.push("  {");
    out.push(`    id: ${str(map.id)},`);
    out.push(`    title: ${str(map.title)},`);
    out.push(`    era: ${str(map.era)},`);
    out.push(`    summary: ${str(map.summary)},`);
    out.push(`    imageUrl: ${str(`/old-maps/${map.webImage}`)},`);
    out.push(`    southWest: { lat: ${map.southWest[0]}, lng: ${map.southWest[1]} },`);
    out.push(`    northEast: { lat: ${map.northEast[0]}, lng: ${map.northEast[1]} },`);
    if (map.bearing !== undefined) out.push(`    bearing: ${map.bearing},`);
    out.push("  },");
  }
  out.push("];", "");
  out.push("/** 統合によって廃止された古地図ID → 統合先の古地図ID。 */");
  out.push("export const MERGED_INTO: Record<string, string> = {");
  for (const [from, to] of Object.entries(mergedInto)) out.push(`  ${str(from)}: ${str(to)},`);
  out.push("};", "");
  out.push("export const HISTORIC_SITE_DATA: HistoricSiteEntry[] = [");
  for (const site of sites) {
    if (site.group) out.push(`  // ${site.group}`);
    out.push(
      `  { id: ${str(site.id)}, name: ${str(site.name)}, overlayMapID: ${str(site.overlayMapID)}, coordinate: { lat: ${site.lat}, lng: ${site.lng} } },`,
    );
  }
  out.push("];", "");
  return out.join("\n");
}

const outputs = {
  "Komap/Models/Generated/OldMapCatalogData.swift": swiftMaps(),
  "Komap/Models/Generated/HistoricSiteCatalogData.swift": swiftSites(),
  "web/src/lib/generated/catalogData.ts": tsData(),
};

if (process.argv.includes("--check")) {
  const stale = Object.entries(outputs).filter(
    ([path, content]) => !existsSync(join(root, path)) || readFileSync(join(root, path), "utf8") !== content,
  );
  if (stale.length) {
    console.error("✗ 生成ファイルが catalog/*.json と一致しません。`node scripts/generate-catalog.mjs` を実行してください:");
    for (const [path] of stale) console.error(`  ${path}`);
    process.exit(1);
  }
  console.log(`✓ 生成ファイルは最新です（古地図${maps.length}件・チェックポイント${sites.length}件）`);
} else {
  for (const [path, content] of Object.entries(outputs)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
    console.log(`wrote ${path}`);
  }
}
