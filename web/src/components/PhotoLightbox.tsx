import { useCallback, useEffect, useRef, useState } from "react";
import type { SharedPhoto } from "../types/sharedTrip";

export interface LightboxItem extends SharedPhoto {
  /** 「御朱印・チェックポイント」「投稿した写真」のどちらのポイントか。 */
  section: string;
}

interface Props {
  items: LightboxItem[];
  startIndex: number;
  onClose: () => void;
}

/** これ以上横に動かしたら、前後のポイントへ移るとみなす距離（px）。 */
const SWIPE_THRESHOLD_PX = 50;

/**
 * 旅日記の御朱印・投稿写真を押した時に、写真を大きく、その説明と一緒に見せるビューア。
 * 左右のスワイプ（スマホ）・矢印キー・左右のボタンで、前後のポイントへ移れる。
 */
export function PhotoLightbox({ items, startIndex, onClose }: Props) {
  const [index, setIndex] = useState(startIndex);
  const touchStartX = useRef<number | null>(null);
  const item = items[index];

  const goTo = useCallback(
    (next: number) => {
      if (next >= 0 && next < items.length) setIndex(next);
    },
    [items.length],
  );

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
      if (event.key === "ArrowLeft") goTo(index - 1);
      if (event.key === "ArrowRight") goTo(index + 1);
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onClose, goTo, index]);

  // 前後の写真を先に読み込んでおき、送った時にすぐ表示されるようにする。
  useEffect(() => {
    for (const neighbor of [items[index - 1], items[index + 1]]) {
      if (neighbor) new Image().src = neighbor.url;
    }
  }, [items, index]);

  if (!item) return null;

  const handleTouchStart = (event: React.TouchEvent) => {
    touchStartX.current = event.touches[0]?.clientX ?? null;
  };
  const handleTouchEnd = (event: React.TouchEvent) => {
    const startX = touchStartX.current;
    touchStartX.current = null;
    const endX = event.changedTouches[0]?.clientX;
    if (startX === null || endX === undefined) return;
    const dx = endX - startX;
    if (dx <= -SWIPE_THRESHOLD_PX) goTo(index + 1);
    if (dx >= SWIPE_THRESHOLD_PX) goTo(index - 1);
  };

  return (
    <div className="modal-overlay photo-lightbox-overlay" onClick={onClose}>
      <button type="button" className="photo-lightbox-close" onClick={onClose} aria-label="閉じる">
        ✕
      </button>
      <div
        className="photo-lightbox-card"
        onClick={(event) => event.stopPropagation()}
        onTouchStart={handleTouchStart}
        onTouchEnd={handleTouchEnd}
        role="dialog"
        aria-label={item.label || item.section}
      >
        <div className="photo-lightbox-stage">
          <img key={item.url} src={item.url} alt={item.label} className="photo-lightbox-image" />
          {index > 0 && (
            <button
              type="button"
              className="photo-lightbox-nav is-prev"
              onClick={() => goTo(index - 1)}
              aria-label="前のポイント"
            >
              ‹
            </button>
          )}
          {index < items.length - 1 && (
            <button
              type="button"
              className="photo-lightbox-nav is-next"
              onClick={() => goTo(index + 1)}
              aria-label="次のポイント"
            >
              ›
            </button>
          )}
        </div>
        <div className="photo-lightbox-text">
          <p className="photo-lightbox-meta">
            {item.section}
            <span className="photo-lightbox-count">
              {index + 1} / {items.length}
            </span>
          </p>
          {item.label && <p className="photo-lightbox-title">{item.label}</p>}
          {item.detail && <p className="photo-lightbox-detail">{item.detail}</p>}
        </div>
      </div>
    </div>
  );
}
