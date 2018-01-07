import os,xmlparser,xmltree,strutils,httpclient,json,future,re
#[
 * coords 需转换的源坐标，多组坐标以“；”分隔
]#
discard """ 单次请求可批量解析100个坐标  """
const apiEndPoint:string = "http://api.map.baidu.com/geoconv/v1/?coords=$1&from=1&to=5&ak=$2"

type
    Point = tuple[lat: string, lon: string]

type
    XY = object
        x *: float
        y *: float

proc `toArray`(xy: XY): array[2,float] =
    result = [xy.y,xy.x]

proc `$`(p: Point): string =
    p.lat & "," & p.lon

type
    Result = object
        status *: int
        result *: seq[XY]

proc main() =
    if paramCount() < 2:
        quit("")
    let 
        ak:string = paramStr(1)
        gpxPath:string = paramStr(2)
    var xml:XmlNode
    try:
        xml = loadXml(gpxPath)
    except IOError:
        quit("")
    let trks:seq[XmlNode] =  xml.findAll("trk")
    let client = newHttpClient()
    var res2 : seq[seq[array[2,float]]] = @[]
    for i,trk in trks.pairs:
        let seg:XmlNode =  trk.findAll("trkseg")[0]
        let trkptNodes:seq[XmlNode]  = seg.findAll("trkpt")
        var trkpts:seq[Point] = @[] 
        for node in trkptNodes:
            let 
                lat:string = node.attr("lat")
                lon:string = node.attr("lon")
                point:Point = (lat,lon)
            trkpts.add(point)
        let url:string = apiEndPoint % [trkpts.join(";"),ak]
        let response = client.request( url ,httpMethod=HttpGet) #{"status":0,"result":[{"x":32.0259054,"y":118.8463384},
        let jsonNode = parseJson(response.body)
        let res = to(jsonNode,Result)
        let seqs:seq[XY] = res.result
        let seqs2:seq[array[2,float]] = lc[ xy.toArray | ( xy <- seqs), array[2,float] ]
        res2.add(seqs2)
    echo replace(repr(res2),re("0x[A-Fa-f0-9]+"),"")
when isMainModule:
    main()