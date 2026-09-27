/**
 * `firebase functions:secrets:set`での貼り付け方（実改行が保持される・
 * リテラルな`\n`になる・ヘッダー無しで本文だけ・CRLFなど）によらず、
 * 常に正しい形のPEM（1行64文字・実改行・BEGIN/ENDヘッダー付き）を作り直す。
 * これをしないと、改行が失われた場合などに`jsonwebtoken`が鍵として
 * 認識できず「secretOrPrivateKey must be an asymmetric key」で失敗する。
 */
export function normalizePEMPrivateKey(raw: string): string {
  const cleaned = raw.trim().replace(/\\n/g, "\n").replace(/\r\n/g, "\n");
  const match = cleaned.match(/-----BEGIN ([^-]+)-----([\s\S]*?)-----END \1-----/);
  const label = match?.[1] ?? "PRIVATE KEY";
  const body = (match?.[2] ?? cleaned).replace(/\s+/g, "");
  const lines = body.match(/.{1,64}/g) ?? [];
  return `-----BEGIN ${label}-----\n${lines.join("\n")}\n-----END ${label}-----\n`;
}
