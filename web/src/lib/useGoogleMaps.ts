import { importLibrary, setOptions } from "@googlemaps/js-api-loader";
import { useEffect, useState } from "react";

let loaderPromise: Promise<unknown> | null = null;

/** Google Maps JavaScript APIを一度だけ読み込むためのフック。 */
export function useGoogleMaps() {
  const [isLoaded, setIsLoaded] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const apiKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY;

  useEffect(() => {
    if (!apiKey) {
      setError("Google Maps APIキーが設定されていません。");
      return;
    }

    if (!loaderPromise) {
      setOptions({ key: apiKey, v: "weekly" });
      loaderPromise = importLibrary("maps");
    }

    loaderPromise
      .then(() => setIsLoaded(true))
      .catch((err) => setError(err instanceof Error ? err.message : "Google Mapsの読み込みに失敗しました。"));
  }, [apiKey]);

  return { isLoaded, error, isConfigured: Boolean(apiKey) };
}
