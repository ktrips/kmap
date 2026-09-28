import { useCallback, useEffect, useState, type FormEvent } from "react";
import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  serverTimestamp,
  setDoc,
  type Timestamp,
} from "firebase/firestore/lite";
import type { User } from "firebase/auth";
import { db } from "../lib/firebase";
import { tripDateFormatter as dateFormatter } from "../lib/format";

interface PromoUser {
  email: string;
  note: string;
  grantedAt: Date | null;
}

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Komap Plus を購入せずに使える人（プロモユーザー）の登録・削除。管理者レポートの中に表示する。
 * `plusPromoUsers/{小文字のメールアドレス}`に書き、iOSアプリ（`PlusStore.isPromoGrant`）と
 * Cloud Function（`getKindleFullText`）がサインイン中のメールアドレスで確かめる。
 * 読み書きできるのは管理者だけ（firestore.rules）。
 */
export function AdminPromoUsers({ user }: { user: User }) {
  const [promoUsers, setPromoUsers] = useState<PromoUser[]>([]);
  const [email, setEmail] = useState("");
  const [note, setNote] = useState("");
  const [isBusy, setIsBusy] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!db) return;
    try {
      const snapshot = await getDocs(collection(db, "plusPromoUsers"));
      const users = snapshot.docs.map((snap) => ({
        email: snap.id,
        note: typeof snap.get("note") === "string" ? (snap.get("note") as string) : "",
        grantedAt: (snap.get("grantedAt") as Timestamp | undefined)?.toDate() ?? null,
      }));
      users.sort((a, b) => (b.grantedAt?.getTime() ?? 0) - (a.grantedAt?.getTime() ?? 0));
      setPromoUsers(users);
      setErrorMessage(null);
    } catch (err) {
      setErrorMessage(`プロモユーザーを読み込めませんでした: ${err instanceof Error ? err.message : String(err)}`);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const handleAdd = async (event: FormEvent) => {
    event.preventDefault();
    const normalized = email.trim().toLowerCase();
    if (!EMAIL_PATTERN.test(normalized)) {
      setErrorMessage("メールアドレスの形式が正しくありません。");
      return;
    }
    if (!db) return;
    setIsBusy(true);
    try {
      await setDoc(doc(db, "plusPromoUsers", normalized), {
        email: normalized,
        note: note.trim().slice(0, 200),
        grantedAt: serverTimestamp(),
        grantedBy: user.email ?? "",
      });
      setEmail("");
      setNote("");
      await load();
    } catch (err) {
      setErrorMessage(`登録できませんでした: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsBusy(false);
    }
  };

  const handleRemove = async (target: string) => {
    if (!db || !window.confirm(`${target} をプロモユーザーから外しますか？`)) return;
    setIsBusy(true);
    try {
      await deleteDoc(doc(db, "plusPromoUsers", target));
      await load();
    } catch (err) {
      setErrorMessage(`削除できませんでした: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsBusy(false);
    }
  };

  return (
    <section className="admin-promo">
      <h3>Komap Plus のプロモユーザー（{promoUsers.length}人）</h3>
      <p className="muted admin-promo-hint">
        ここに登録したGoogleアカウントのメールアドレスでサインインすると、購入しなくても Plus
        の機能（iOSアプリ・Webの Kindle本の全文）を使えます。iOSアプリには、次にサインイン・起動した時に反映されます。
      </p>
      <form className="admin-promo-form" onSubmit={(event) => void handleAdd(event)}>
        <input
          type="email"
          placeholder="メールアドレス"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          required
        />
        <input
          type="text"
          placeholder="メモ（任意。例: 取材・協力者）"
          value={note}
          maxLength={200}
          onChange={(event) => setNote(event.target.value)}
        />
        <button type="submit" className="sidebar-menu-button" disabled={isBusy}>
          追加
        </button>
      </form>
      {errorMessage && <p className="admin-report-error">{errorMessage}</p>}
      {promoUsers.length > 0 && (
        <table className="admin-report-table">
          <thead>
            <tr>
              <th>メールアドレス</th>
              <th>メモ</th>
              <th>登録日</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {promoUsers.map((promo) => (
              <tr key={promo.email}>
                <td>{promo.email}</td>
                <td>{promo.note}</td>
                <td>{promo.grantedAt ? dateFormatter.format(promo.grantedAt) : ""}</td>
                <td>
                  <button
                    type="button"
                    className="admin-promo-remove"
                    onClick={() => void handleRemove(promo.email)}
                    disabled={isBusy}
                  >
                    外す
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
