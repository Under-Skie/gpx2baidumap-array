import os,xmlparser,xmltree,strutils,httpclient,json,future,re, asyncdispatch,sequtils,marshal
#[
 * coords 需转换的源坐标，多组坐标以“；”分隔
]#
discard """ 单次请求可批量解析100个坐标  """
const apiEndPoint:string = "http://api.map.baidu.com/geoconv/v1/?coords=$1&from=1&to=5&ak=$2"
const apiLimit:int = 100

type
    Point = tuple[lat: string, lon: string ,i:int,j:int]

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

proc apiRequest(pts:seq[Point],ak:string,res2: ptr seq[seq[array[2,float]]] ):Future[string] {.async.}  =
    let 
        client = newAsyncHttpClient()
        total:int = pts.len
        extro:bool =  if total mod apiLimit > 0:true else: false
        steps:int = total /% apiLimit + ord(extro)
    for step in 0..steps - 1 :
        let 
            hindex = min(step * apiLimit + apiLimit - 1,pts.len - 1)
            lindex = (step * apiLimit)
            ops:seq[Point] = pts[ lindex .. hindex ]
            url:string = apiEndPoint % [ops.join(";"),ak]
            content = await client.getContent( url )
            jsonNode = parseJson(content)
            res = to(jsonNode,Result)
            seqs:seq[XY] = res.result
            seqs2:seq[array[2,float]] = lc[ xy.toArray | ( xy <- seqs), array[2,float] ]

        for i,p in seqs2.pairs:
            let 
                point:Point = ops[i]

            res2[point.i][point.j] = p
    result = $$ cast[ptr seq[seq[array[2,float]]] ](res2)[]
    

proc main(gpxPath,ak:string):Future[string] {.async.}  =
    var xml:XmlNode
    try:
        xml = loadXml(gpxPath)
    except IOError:
        quit("Can NOT load gpx file with given path!")
    let trks:seq[XmlNode] =  xml.findAll("trk")
    var flatSeq:seq[Point] = @[]
    var res:seq[seq[array[2,float]]] = @[]
    setlen(res,trks.len)
    var refer: ptr seq[seq[array[2,float]]] = addr(res)
    for i,trk in trks.pairs:
        let 
            seg:XmlNode =  trk.findAll("trkseg")[0]
            trkptNodes:seq[XmlNode]  = seg.findAll("trkpt")
        var resi:seq[array[2,float]] =  @[]
        
        setlen(resi,trkptNodes.len)
        res[i] = resi
        for j,node in trkptNodes.pairs:
            let 
                lat:string = node.attr("lat")
                lon:string = node.attr("lon")
                point:Point = (lat,lon,i,j)

            flatSeq.add(point)
    result = await apiRequest(flatSeq,ak,refer)

when isMainModule:
    if paramCount() < 2:
        quit("Needs 2 params as least!")
    let 
        ak:string = paramStr(1)
        gpxPath:string = paramStr(2)
 
    echo waitFor main(gpxPath,ak)