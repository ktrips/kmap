/**
 * 時空旅のID（UUID、36文字）を、URLに載せる短い表現（Base64URL、22文字）に
 * 相互変換する。UUIDの16バイトをそのままBase64URLエンコード／デコードするだけの
 * 可逆変換のため、サーバー側の対応表（短縮IDからUUIDを引く仕組み）を必要としない。
 * iOS側（`Komap/Models/UUID+ShortID.swift`）にも同じ変換ロジックを実装している。
 */

/** UUID文字列（ハイフンあり）を、URLで使う22文字のBase64URL文字列に変換する。 */
export function uuidToShortId(uuid: string): string | null {
  const hex = uuid.replace(/-/g, "");
  if (hex.length !== 32 || !/^[0-9a-fA-F]+$/.test(hex)) return null;

  const bytes = new Uint8Array(16);
  for (let i = 0; i < 16; i++) {
    bytes[i] = parseInt(hex.substring(i * 2, i * 2 + 2), 16);
  }
  let binary = "";
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte);
  });
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** `uuidToShortId`の逆変換。不正な入力の場合は`null`を返す。 */
export function shortIdToUuid(shortId: string): string | null {
  if (shortId.length !== 22) return null;
  try {
    const base64 = shortId.replace(/-/g, "+").replace(/_/g, "/") + "==";
    const binary = atob(base64);
    if (binary.length !== 16) return null;

    let hex = "";
    for (let i = 0; i < 16; i++) {
      hex += binary.charCodeAt(i).toString(16).padStart(2, "0");
    }
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  } catch {
    return null;
  }
}
