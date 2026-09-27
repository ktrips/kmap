import json, os, time, urllib.request, urllib.parse
UA={"User-Agent":"Komap-map-builder/1.0 (kenichiyoshida13@gmail.com)"}
CITIES={
 "helsinki":(60.141,24.886,60.224,25.053),
 "stockholm":(59.317,18.063,59.329,18.089),
 "amsterdam":(52.360,4.883,52.380,4.916),
 "tallinn":(59.436,24.736,59.444,24.752),
 "beijing":(39.862,116.333,39.952,116.450),
 "xian":(34.212,108.898,34.287,108.9885),
 "lhasa":(29.632,91.086,29.679,91.140),
 "angkor":(13.404,103.848,13.447,103.8923),
 "delhi":(28.640,77.215,28.672,77.2515),
 "isfahan":(32.640,51.656,32.674,51.6965),
 "jerusalem":(31.767,35.2185,31.789,35.2444),
 "boston":(42.348,-71.0745,42.372,-71.042),
 "newyork":(40.698,-74.024,40.718,-73.9977),
 "mexico":(19.425,-99.1478,19.445,-99.1266),
 "cusco":(-13.527,-71.9895,-13.504,-71.9659),
 "buenosaires":(-34.626,-58.389,-34.597,-58.354),
}
def overpass(city,bbox):
    s,w,n,e=bbox
    # 範囲の少し外側まで取って、端で線や水域が途切れないようにする
    ds=(n-s)*0.08; dw=(e-w)*0.08
    b=f"{s-ds},{w-dw},{n+ds},{e+dw}"
    big = city in ("helsinki", "beijing", "xian")
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
import sys
for c,b in CITIES.items():
    if len(sys.argv) > 1 and c not in sys.argv[1:]: continue
    if os.path.exists(f"{c}.json"): continue
    d=overpass(c,b); json.dump(d,open(f"{c}.json","w")); print(c,"elements",len(d["elements"])); time.sleep(3)
