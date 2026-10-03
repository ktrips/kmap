import { useEffect, useState } from "react";
import { fromSharedTrip, type UnifiedTrip } from "../types/unifiedTrip";
import { useIsMobile } from "./useIsMobile";
import { useSelectedTripId } from "./useSelectedTripId";
import { useSharedTripById } from "./useSharedTripById";
import { useTripRoute } from "./useTripRoute";

/**
 * 時空旅の一覧（左のメニュー）と詳細（右）の画面に共通する状態をまとめたもの。
 * 公開ページ（`PublicSharedTripsView`）とサインイン後の画面（`AuthenticatedApp`）の両方で使う。
 *
 * - スマホ幅では、旅を選ぶと一覧を収納して詳細を広く見せる（URL`?t=`付きで開いた時は最初から詳細）。
 *   PC・タブレット幅では一覧を常に表示したままにする。
 * - 一覧（「みんなの時空旅」は直近50件）に無い旅を共有リンクで直接開いた時は、その1件だけ個別に取得する。
 * - 一覧は軌跡の座標を読まないので、選んだ旅の座標はその時に読む（`useTripRoute`）。
 */
export function useTripBrowser(trips: UnifiedTrip[]) {
  const [selectedTripId, setSelectedTripId] = useSelectedTripId();
  const isMobile = useIsMobile();
  const [isSidebarOpen, setIsSidebarOpen] = useState(isMobile ? selectedTripId === null : true);

  // モバイル幅からPC・タブレット幅へリサイズ（画面回転含む）された時も、
  // 一覧が収納されたままにならないよう、常に表示された状態に戻す。
  useEffect(() => {
    if (!isMobile) {
      setIsSidebarOpen(true);
    }
  }, [isMobile]);

  const isSelectedTripInList = selectedTripId !== null && trips.some((trip) => trip.id === selectedTripId);
  const fallbackSharedTrip = useSharedTripById(selectedTripId, isSelectedTripInList);
  // 公開中の旅の一覧は軌跡の座標を持たないので、選んだ旅の座標だけを読んで足す。
  const selectedTrip = useTripRoute(
    trips.find((trip) => trip.id === selectedTripId) ??
      (fallbackSharedTrip ? fromSharedTrip(fallbackSharedTrip) : null),
  );

  const selectTrip = (trip: UnifiedTrip) => {
    setSelectedTripId(trip.id);
    if (isMobile) {
      setIsSidebarOpen(false);
    }
  };

  /** 左上のアイコン: 選んでいた時空旅を解除して、一覧だけのホームに戻る。 */
  const goHome = () => {
    setSelectedTripId(null);
    setIsSidebarOpen(true);
  };

  return {
    isMobile,
    selectedTripId,
    selectedTrip,
    isSidebarOpen,
    openSidebar: () => setIsSidebarOpen(true),
    /** スマホ幅の時だけ一覧を収納する（旅以外の詳細を開いた時など）。 */
    collapseSidebarOnMobile: () => {
      if (isMobile) setIsSidebarOpen(false);
    },
    selectTrip,
    goHome,
  };
}
