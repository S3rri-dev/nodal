// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ImageIO

// Geometry transcribed from the approved Nodal reference; PNG and SVG use these same paths.
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let directory=root.appendingPathComponent("build/AppIcon.iconset")
let brand=root.appendingPathComponent("Resources/web/brand")
try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
try FileManager.default.createDirectory(at:brand,withIntermediateDirectories:true)
func marks()->[NSBezierPath] {
    let left=NSBezierPath()
    left.move(to:NSPoint(x:77,y:72));left.curve(to:NSPoint(x:119,y:117),controlPoint1:NSPoint(x:97,y:72),controlPoint2:NSPoint(x:119,y:90))
    left.line(to:NSPoint(x:119,y:271));left.line(to:NSPoint(x:84,y:271))
    left.curve(to:NSPoint(x:60,y:245),controlPoint1:NSPoint(x:69,y:271),controlPoint2:NSPoint(x:60,y:260))
    left.line(to:NSPoint(x:60,y:90));left.curve(to:NSPoint(x:77,y:72),controlPoint1:NSPoint(x:60,y:79),controlPoint2:NSPoint(x:65,y:72));left.close()
    let middle=NSBezierPath();middle.move(to:NSPoint(x:131,y:119));for point in [NSPoint(x:203,y:192),NSPoint(x:203,y:263),NSPoint(x:131,y:186)]{middle.line(to:point)};middle.close()
    let right=NSBezierPath();right.move(to:NSPoint(x:220,y:72));right.line(to:NSPoint(x:255,y:72))
    right.curve(to:NSPoint(x:279,y:96),controlPoint1:NSPoint(x:270,y:72),controlPoint2:NSPoint(x:279,y:81))
    right.line(to:NSPoint(x:279,y:254));right.curve(to:NSPoint(x:263,y:271),controlPoint1:NSPoint(x:279,y:265),controlPoint2:NSPoint(x:274,y:271))
    right.line(to:NSPoint(x:220,y:271));right.close()
    return [left,middle,right]
}
func svgPath(_ path:NSBezierPath)->String {
    var text="",points=[NSPoint](repeating:.zero,count:3)
    func point(_ p:NSPoint)->String {"\(Int(p.x)) \(Int(p.y))"}
    for i in 0..<path.elementCount {
        let element=path.element(at:i,associatedPoints:&points)
        switch element {
        case .moveTo:text+="M"+point(points[0])
        case .lineTo:text+="L"+point(points[0])
        case .curveTo,.cubicCurveTo:text+="C"+point(points[0])+" "+point(points[1])+" "+point(points[2])
        case .quadraticCurveTo:text+="Q"+point(points[0])+" "+point(points[1])
        case .closePath:text+="Z"
        @unknown default:break
        }
    };return text
}
let shape=marks().map{"<path d=\"\(svgPath($0))\"/>"}.joined()
let iconSVG="""
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="Nodal">
<rect x="25" y="25" width="974" height="974" rx="210" fill="#551725"/>
<g transform="translate(25 25) scale(2.8647058824)" fill="#DCB974">\(shape)</g></svg>
"""
try iconSVG.write(to:brand.appendingPathComponent("nodal-icon.svg"),atomically:true,encoding:.utf8)
let markSVG="<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"40 52 259 239\"><g fill=\"#100D10\">\(shape)</g></svg>"
try markSVG.write(to:brand.appendingPathComponent("nodal-mark.svg"),atomically:true,encoding:.utf8)
func render(_ pixels:Int,background:Bool=true,monochrome:Bool=false)->Data {
    let cg=CGContext(data:nil,width:pixels,height:pixels,bitsPerComponent:8,bytesPerRow:pixels*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    cg.scaleBy(x:CGFloat(pixels)/1024,y:CGFloat(pixels)/1024)
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:cg,flipped:false)
    cg.translateBy(x:0,y:1024);cg.scaleBy(x:1,y:-1)
    if background {cg.setFillColor(red:85/255,green:23/255,blue:37/255,alpha:1);NSBezierPath(roundedRect:NSRect(x:25,y:25,width:974,height:974),xRadius:210,yRadius:210).fill()}
    let transform=AffineTransform(translationByX:background ? 25:83-60*3.9,byY:background ? 25:124-72*3.9)
    var scale=transform;scale.scale(background ? 974/340:3.9)
    for path in marks() {
        path.transform(using:scale)
        if monochrome {cg.setFillColor(red:0,green:0,blue:0,alpha:1);path.fill()}
        else {cg.setFillColor(red:220/255,green:185/255,blue:116/255,alpha:1);path.fill()}
    }
    NSGraphicsContext.restoreGraphicsState()
    let data=NSMutableData(),destination=CGImageDestinationCreateWithData(data,"public.png" as CFString,1,nil)!
    CGImageDestinationAddImage(destination,cg.makeImage()!,nil)
    precondition(CGImageDestinationFinalize(destination));return data as Data
}
for size in [16,32,128,256,512] {for scale in [1,2] {
    try render(size*scale).write(to:directory.appendingPathComponent("icon_\(size)x\(size)\(scale==2 ? "@2x":"").png"))
}}
try render(512).write(to:brand.appendingPathComponent("nodal-icon-512.png"))
try render(128).write(to:brand.appendingPathComponent("nodal-icon-128.png"))
try render(64,background:false,monochrome:true).write(to:root.appendingPathComponent("Resources/brand/nodal-template.png"))
print("Nodal: SVG, PNG, plantilla de menús e iconset generados desde la geometría aprobada.")
