import { useCallback, useEffect, useState } from "react";

const PARAM_NAME = "trip";

function readTripIdFromLocation(): string | null {
  return new URLSearchParams(window.location.search).get(PARAM_NAME);
}

/**
 * 選択中の時空旅IDを、URLのクエリパラメータ（`?trip=<id>`）と同期させる。
 * ページを開いた時に`?trip=`があればそれを初期選択にし、選択を変えるたびに
 * URLを書き換える（ブラウザの戻る/進むにも追従する）ことで、個別の時空旅を
 * 直接リンクできるようにする（例: `komap.ktrips.net?trip=xxxx`）。
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
    if (id) {
      url.searchParams.set(PARAM_NAME, id);
    } else {
      url.searchParams.delete(PARAM_NAME);
    }
    window.history.pushState({}, "", url);
  }, []);

  return [selectedTripId, setSelectedTripId];
}
