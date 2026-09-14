import { useEffect } from "react";

interface Props {
  url: string;
  alt: string;
  onClose: () => void;
}

/** 御朱印・投稿写真のサムネイルをクリックした時に、大きく表示するためのライトボックス。 */
export function PhotoLightbox({ url, alt, onClose }: Props) {
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onClose]);

  return (
    <div className="modal-overlay photo-lightbox-overlay" onClick={onClose}>
      <button type="button" className="photo-lightbox-close" onClick={onClose} aria-label="閉じる">
        ✕
      </button>
      {/* eslint-disable-next-line jsx-a11y/no-noninteractive-element-interactions */}
      <img
        src={url}
        alt={alt}
        className="photo-lightbox-image"
        onClick={(event) => event.stopPropagation()}
      />
    </div>
  );
}
