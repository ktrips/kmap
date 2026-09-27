"""Komap Global の古地図の元データ（OpenStreetMap）を Overpass API から取得する。

    python3 fetch.py   # <city>.json を書き出す（render.py が読む）
"""
import json, os, time, urllib.request, urllib.parse
UA={"User-Agent":"Komap-map-builder/1.0 (kenichiyoshida13@gmail.com)"}
CITIES={
 "helsinki":(60.141,24.886,60.224,25.053),
 "stockholm":(59.317,18.063,59.329,18.089),
 "amsterdam":(52.360,4.883,52.380,4.916),
 "tallinn":(59.436,24.736,59.444,24.752),
}
def overpass(city,bbox):
    s,w,n,e=bbox
    # 範囲の少し外側まで取って、端で線や水域が途切れないようにする
    ds=(n-s)*0.08; dw=(e-w)*0.08
    b=f"{s-ds},{w-dw},{n+ds},{e+dw}"
    big = city=="helsinki"
    roads = "motorway|trunk|primary|secondary|tertiary" + ("|residential" if big else "|residential|unclassified|pedestrian|living_street|service|footway|steps")
    q=f"""[out:json][timeout:180];
(
 way["natural"="coastline"]({b});
 way["natural"="water"]({b});
 relation["natural"="water"]({b});
 way["waterway"="riverbank"]({b});
 way["waterway"~"^(canal|river|stream)$"]({b});
 way["highway"~"^({roads})$"]({b});
 way["railway"="rail"]({b});
 way["leisure"~"^(park|garden)$"]({b});
 way["landuse"~"^(forest|grass|cemetery|meadow)$"]({b});
 way["natural"="wood"]({b});
 way["historic"="citywalls"]({b});
 way["barrier"="city_wall"]({b});
 way["building"]({b});
);
out geom;"""
    data=urllib.parse.urlencode({"data":q}).encode()
    for url in ["https://overpass-api.de/api/interpreter","https://overpass.kumi.systems/api/interpreter","https://maps.mail.ru/osm/tools/overpass/api/interpreter"]:
        try:
            r=urllib.request.urlopen(urllib.request.Request(url,data=data,headers=UA),timeout=240)
            return json.load(r)
        except Exception as ex:
            print("overpass fail",url,ex)
    raise SystemExit(1)
for c,b in CITIES.items():
    if os.path.exists(f"{c}.json"): continue
    d=overpass(c,b); json.dump(d,open(f"{c}.json","w")); print(c,"elements",len(d["elements"])); time.sleep(3)
