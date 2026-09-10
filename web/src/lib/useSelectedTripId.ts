import { useCallback, useEffect, useState } from "react";
import { shortIdToUuid, uuidToShortId } from "./tripShortId";

/** 短縮ID用のパラメータ名（新しいURLはこちら）。 */
const SHORT_PARAM_NAME = "t";
/** これより前に発行されたリンク（UUIDそのまま）を、引き続き開けるようにするためのパラメータ名。 */
const LEGACY_PARAM_NAME = "trip";

function readTripIdFromLocation(): string | null {
  const params = new URLSearchParams(window.location.search);
  const shortId = params.get(SHORT_PARAM_NAME);
  if (shortId) {
    const uuid = shortIdToUuid(shortId);
    if (uuid) return uuid;
  }
  return params.get(LEGACY_PARAM_NAME);
}

/**
 * 選択中の時空旅IDを、URLのクエリパラメータ（`?t=<短縮ID>`）と同期させる。
 * ページを開いた時にこのパラメータ（または、以前発行したリンクが使っている
 * `?trip=<UUID>`）があればそれを初期選択にし、選択を変えるたびにURLを書き換える
 * （ブラウザの戻る/進むにも追従する）ことで、個別の時空旅を直接リンクできるように
 * する（例: `komap.ktrips.net?t=xxxxxxxxxxxxxxxxxxxxxx`）。
 */
export function useSelectedTripId(): [string | null, (id: string | null) => void] {
  const [selectedTripId, setSelectedTripIdState] = useState<string | null>(readTripIdFromLocation);

  useEffect(() => {
    const onPopState = () => setSelectedTripIdState(readTripIdFromLocation());
    window.addEventListener("popstate", onPopState);
    return () => window.removeEventListener("popstate", onPopState);
  }, []);

  const setSelectedTripId = useCallback((id: string | null) => {
    setSelectedTripIdState(id);
    const url = new URL(window.location.href);
    url.searchParams.delete(LEGACY_PARAM_NAME);
    const shortId = id ? uuidToShortId(id) : null;
    if (shortId) {
      url.searchParams.set(SHORT_PARAM_NAME, shortId);
    } else {
      url.searchParams.delete(SHORT_PARAM_NAME);
    }
    window.history.pushState({}, "", url);
  }, []);

  return [selectedTripId, setSelectedTripId];
}
