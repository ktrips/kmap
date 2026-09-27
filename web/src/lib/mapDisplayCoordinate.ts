/**
 * 地図に描く時だけ使う座標の変換（中国本土の GCJ-02）。iOS の `MapDisplayCoordinate` と同じ処理。
 *
 * 中国本土では Google マップの道路・地名の地図が独自の座標系（GCJ-02）でずれて描かれている。
 * 古地図・チェックポイント・歩いたルートは世界測地系（WGS84）のため、地図に置く直前にこの変換を通して
 * 背景に合わせる。中国本土の外（香港・マカオ・台湾・日本・韓国・インドなど）では何もしない。
 */
export interface LatLng {
  lat: number;
  lng: number;
}

// 中国本土の国境・海岸線をおおまかになぞった多角形（経度, 緯度）。
const CHINA_BORDER: [number, number][] = [
  [73.5, 39.5], [75.0, 40.5], [80.0, 42.5], [82.5, 45.0], [85.0, 47.5], [87.5, 49.2], [90.0, 47.8],
  [95.0, 45.0], [97.0, 42.8], [105.0, 41.8], [111.5, 43.5], [116.0, 46.5], [119.5, 49.5], [121.5, 53.4],
  [126.0, 52.8], [131.0, 48.0], [134.8, 48.2], [131.0, 44.5], [131.0, 42.8], [129.5, 42.3], [126.0, 40.3],
  [124.2, 39.8], [122.0, 39.0], [122.5, 37.5], [123.0, 35.0], [122.5, 31.5], [122.0, 29.0], [120.5, 26.0],
  [118.0, 24.3], [117.0, 23.2], [111.0, 21.0], [108.5, 21.5], [106.5, 22.4], [105.5, 23.3], [103.5, 22.6],
  [101.7, 21.2], [100.0, 21.5], [99.2, 22.2], [98.7, 24.1], [97.5, 24.8], [98.6, 27.5], [97.4, 28.3],
  [96.0, 29.4], [94.0, 29.3], [92.0, 27.8], [90.0, 28.2], [88.9, 27.3], [88.0, 27.9], [86.0, 27.9],
  [84.0, 28.6], [81.5, 30.2], [79.5, 30.9], [79.0, 32.4], [78.4, 34.0], [79.5, 35.6], [77.8, 35.5],
  [76.0, 36.9], [74.6, 37.2],
];

export function isInMainlandChina({ lat, lng }: LatLng): boolean {
  if (lat < 18 || lat > 54 || lng < 73 || lng > 135) return false;
  if (lat >= 22.15 && lat <= 22.57 && lng >= 113.82 && lng <= 114.45) return false; // 香港
  if (lat >= 22.1 && lat <= 22.22 && lng >= 113.52 && lng <= 113.6) return false; // マカオ
  let inside = false;
  for (let i = 0, j = CHINA_BORDER.length - 1; i < CHINA_BORDER.length; j = i++) {
    const [xi, yi] = CHINA_BORDER[i];
    const [xj, yj] = CHINA_BORDER[j];
    if (yi > lat !== yj > lat && lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

/** WGS84 → 地図に描く座標（中国本土なら GCJ-02）。 */
export function toDisplay(point: LatLng): LatLng {
  if (!isInMainlandChina(point)) return point;
  const a = 6378245.0;
  const ee = 0.006693421622965943;
  const x = point.lng - 105.0;
  const y = point.lat - 35.0;
  let dLat = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(Math.abs(x));
  dLat += ((20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0) / 3.0;
  dLat += ((20.0 * Math.sin(y * Math.PI) + 40.0 * Math.sin((y / 3.0) * Math.PI)) * 2.0) / 3.0;
  dLat += ((160.0 * Math.sin((y / 12.0) * Math.PI) + 320 * Math.sin((y * Math.PI) / 30.0)) * 2.0) / 3.0;
  let dLng = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x));
  dLng += ((20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0) / 3.0;
  dLng += ((20.0 * Math.sin(x * Math.PI) + 40.0 * Math.sin((x / 3.0) * Math.PI)) * 2.0) / 3.0;
  dLng += ((150.0 * Math.sin((x / 12.0) * Math.PI) + 300.0 * Math.sin((x / 30.0) * Math.PI)) * 2.0) / 3.0;
  const radLat = (point.lat / 180.0) * Math.PI;
  let magic = Math.sin(radLat);
  magic = 1 - ee * magic * magic;
  const sqrtMagic = Math.sqrt(magic);
  dLat = (dLat * 180.0) / (((a * (1 - ee)) / (magic * sqrtMagic)) * Math.PI);
  dLng = (dLng * 180.0) / ((a / sqrtMagic) * Math.cos(radLat) * Math.PI);
  return { lat: point.lat + dLat, lng: point.lng + dLng };
}
