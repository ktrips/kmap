import { useEffect, useState } from "react";

/** `index.css`のレイアウト切り替えと同じブレークポイント（`@media (max-width: 720px)`）。 */
const MOBILE_BREAKPOINT_QUERY = "(max-width: 720px)";

/**
 * 今の画面幅がモバイル向けレイアウト（左メニューが折りたたまれる幅）かどうかを返す。
 * リサイズ（画面回転含む）にも追従する。
 */
export function useIsMobile(): boolean {
  const [isMobile, setIsMobile] = useState(() => {
    if (typeof window === "undefined") return false;
    return window.matchMedia(MOBILE_BREAKPOINT_QUERY).matches;
  });

  useEffect(() => {
    const mediaQueryList = window.matchMedia(MOBILE_BREAKPOINT_QUERY);
    const handleChange = (event: MediaQueryListEvent) => setIsMobile(event.matches);
    mediaQueryList.addEventListener("change", handleChange);
    return () => mediaQueryList.removeEventListener("change", handleChange);
  }, []);

  return isMobile;
}
