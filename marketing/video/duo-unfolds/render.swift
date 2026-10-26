import Foundation
import AppKit
import AVFoundation
import CoreText

// Run from this directory: swift render.swift [--preview]
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let preview = CommandLine.arguments.contains("--preview")
let W = 3840, H = 960, fps = 30, duration = 26.0
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ r: Double,_ g: Double,_ b: Double,_ a: Double = 1)->CGColor {CGColor(srgbRed:r,green:g,blue:b,alpha:a)}
let ink=color(0.035,0.12,0.19), blue=color(0.13,0.36,0.94), muted=color(0.29,0.40,0.46)
func smooth(_ t:Double)->Double {let v=max(0,min(1,t));return v*v*(3-2*v)}
func load(_ p:String)->CGImage { NSImage(contentsOf:root.appendingPathComponent(p))!.cgImage(forProposedRect:nil,context:nil,hints:nil)! }
func png(_ image:CGImage,_ p:String) throws {let rep=NSBitmapImageRep(cgImage:image);try rep.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent(p))}

// Use pixels from the actual Device Hub hardware shell, retaining its hinge,
// metal edge and side buttons. The live screen recording fills its aperture.
let source=load("assets/frame-open-source.png")
let shell=source.cropping(to:CGRect(x:718,y:278,width:764,height:1060))!
let shellCtx=CGContext(data:nil,width:764,height:1060,bitsPerComponent:8,bytesPerRow:764*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
shellCtx.draw(shell,in:CGRect(x:0,y:0,width:764,height:1060))
let bytes=shellCtx.data!.assumingMemoryBound(to:UInt8.self)
for p in 0..<(764*1060) {let i=p*4;if bytes[i]>238 && bytes[i+1]>238 && bytes[i+2]>238 {bytes[i]=0;bytes[i+1]=0;bytes[i+2]=0;bytes[i+3]=0}}
shellCtx.setBlendMode(.clear)
shellCtx.addPath(CGPath(roundedRect:CGRect(x:28,y:26,width:708,height:1008),cornerWidth:62,cornerHeight:62,transform:nil));shellCtx.fillPath()
let nativeShell=shellCtx.makeImage()!
try png(nativeShell,"assets/native-duo-frame.png")
let icon=load("../../../appstore-screenshots/public/app-icon.png")
var generators:[String:AVAssetImageGenerator]=[:]
func video(_ file:String,_ seconds:Double)->CGImage {
    let gen=generators[file] ?? {let g=AVAssetImageGenerator(asset:AVURLAsset(url:root.appendingPathComponent("assets/"+file)));g.appliesPreferredTrackTransform=true;g.requestedTimeToleranceBefore=CMTime(value:1,timescale:60);g.requestedTimeToleranceAfter=CMTime(value:1,timescale:60);generators[file]=g;return g}()
    return try! gen.copyCGImage(at:CMTime(seconds:seconds,preferredTimescale:600),actualTime:nil)
}
func drawImage(_ c:CGContext,_ img:CGImage,_ rect:CGRect) {c.saveGState();c.translateBy(x:0,y:rect.minY+rect.maxY);c.scaleBy(x:1,y:-1);c.draw(img,in:rect);c.restoreGState()}
func text(_ c:CGContext,_ string:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ width:CGFloat,_ weight:NSFont.Weight = .regular,_ fill:CGColor = ink,_ tracking:CGFloat = -1) {
    let para=NSMutableParagraphStyle();para.lineSpacing=6
    let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:NSColor(cgColor:fill)!,.kern:tracking,.paragraphStyle:para]
    let a=NSAttributedString(string:string,attributes:attrs), setter=CTFramesetterCreateWithAttributedString(a)
    let s=CTFramesetterSuggestFrameSizeWithConstraints(setter,CFRange(),nil,CGSize(width:width,height:1000),nil)
    let r=CGRect(x:x,y:y,width:width,height:ceil(s.height)+8)
    c.saveGState();c.translateBy(x:0,y:r.minY+r.maxY);c.scaleBy(x:1,y:-1)
    CTFrameDraw(CTFramesetterCreateFrame(setter,CFRange(),CGPath(rect:r,transform:nil),nil),c);c.restoreGState()
}
func device(_ c:CGContext,_ image:CGImage,_ rect:CGRect,_ landscape:Bool) {
    c.saveGState()
    c.setShadow(offset:CGSize(width:0,height:18),blur:36,color:color(0.05,0.2,0.3,0.20))
    c.setFillColor(color(0,0,0));c.addPath(CGPath(roundedRect:rect.insetBy(dx:7,dy:7),cornerWidth:58,cornerHeight:58,transform:nil));c.fillPath();c.setShadow(offset:.zero,blur:0,color:nil)
    let screen:CGRect
    if landscape {screen=CGRect(x:rect.minX+rect.width*26/1060,y:rect.minY+rect.height*28/764,width:rect.width*1008/1060,height:rect.height*708/764)}
    else {screen=CGRect(x:rect.minX+rect.width*28/764,y:rect.minY+rect.height*26/1060,width:rect.width*708/764,height:rect.height*1008/1060)}
    c.saveGState();c.addPath(CGPath(roundedRect:screen,cornerWidth:screen.height*0.059,cornerHeight:screen.height*0.059,transform:nil));c.clip();drawImage(c,image,screen);c.restoreGState()
    if landscape {c.saveGState();c.translateBy(x:rect.midX,y:rect.midY);c.rotate(by:.pi/2);drawImage(c,nativeShell,CGRect(x:-rect.height/2,y:-rect.width/2,width:rect.height,height:rect.width));c.restoreGState()}
    else {drawImage(c,nativeShell,rect)}
    c.restoreGState()
}
func scene(_ c:CGContext,_ index:Int,_ local:Double,_ absolute:Double,_ opacity:Double = 1) {
    let rise=CGFloat(1-smooth(local/0.8))*28
    let intro=smooth(local/0.7)
    c.saveGState();c.setAlpha(intro*opacity)
    text(c,"SIPLI  /  IPHONE DUO",180,160+rise,30,1600,.semibold,blue,4)
    if index==0 {
        text(c,"Small sips.\nBigger possibilities.",180,265+rise,112,1840,.semibold)
        text(c,"Your hydration ritual, with room to grow.",186,600+rise,42,1640,.regular,muted)
        device(c,video("open-home.mov",3+local),CGRect(x:2675-40*intro,y:52,width:615,height:853),false)
    } else if index==1 {
        text(c,"Your daily goal.\nIn full view.",180,265+rise,112,1800,.semibold)
        text(c,"A layout that makes the most of iPhone Duo.",186,600+rise,42,1700,.regular,muted)
        device(c,video("open-landscape.mov",3+local),CGRect(x:2290-40*intro,y:70,width:1180,height:850.57),true)
    } else if index==2 {
        text(c,"See the pattern.\nBuild the habit.",180,265+rise,112,1800,.semibold)
        text(c,"Explore your hydration, over days and weeks.",186,600+rise,42,1700,.regular,muted)
        device(c,video("open-insights.mov",62.0+local),CGRect(x:2290-40*intro,y:70,width:1180,height:850.57),true)
    } else {
        text(c,"Sipli",180,325+rise,172,1500,.semibold)
        text(c,"A little more water. A little more you.",186,565+rise,48,1850,.regular,muted)
        c.setFillColor(blue);c.addPath(CGPath(roundedRect:CGRect(x:186,y:700,width:540,height:82),cornerWidth:41,cornerHeight:41,transform:nil));c.fillPath()
        text(c,"Made for iPhone Duo",225,717,34,500,.semibold,color(1,1,1),0)
        device(c,video("open-landscape.mov",5+local),CGRect(x:2080,y:180,width:1030,height:742.38),true)
        device(c,video("open-home.mov",4+local),CGRect(x:3100,y:80,width:570,height:790.84),false)
    }
    c.restoreGState()
}
func render(_ c:CGContext,_ t:Double) {
    c.translateBy(x:0,y:CGFloat(H));c.scaleBy(x:1,y:-1);c.interpolationQuality = .high
    let g=CGGradient(colorsSpace:space,colors:[color(0.97,0.985,0.98),color(0.83,0.94,0.97)] as CFArray,locations:[0,1])!
    c.drawLinearGradient(g,start:CGPoint(x:0,y:0),end:CGPoint(x:3840,y:960),options:[])
    for n in 0..<7 {let r=CGFloat(230+n*110)+CGFloat(sin(t*0.25))*14;c.setStrokeColor(color(0.1,0.54,0.76,0.065));c.setLineWidth(2);c.strokeEllipse(in:CGRect(x:2900-r,y:480-r,width:r*2,height:r*2))}
    for n in 0..<3 {let p=CGMutablePath();let base=CGFloat(820+n*25);p.move(to:CGPoint(x:0,y:base));for x in stride(from:0,through:3840,by:16){p.addLine(to:CGPoint(x:CGFloat(x),y:base+sin(CGFloat(x)/360+CGFloat(t)*0.3+CGFloat(n))*24))};c.setStrokeColor(color(0.1,0.48,0.8,0.07));c.setLineWidth(3);c.addPath(p);c.strokePath()}
    let starts=[0.0,5.0,12.0,20.0]
    let i=t<5 ? 0:t<12 ? 1:t<20 ? 2:3
    if i>0 && t-starts[i]<0.55 {scene(c,i-1,t-starts[i-1],t,1-smooth((t-starts[i])/0.7))}
    scene(c,i,t-starts[i],t)
    text(c,"HYDRATION, AT YOUR PACE.",185,880,22,1500,.medium,muted,3)
    c.setFillColor(color(0.2,0.4,0.5,0.12));c.fill(CGRect(x:180,y:933,width:3480,height:2))
    c.setFillColor(blue);c.fill(CGRect(x:180,y:933,width:3480*min(1,t/26),height:2))
}
if preview {
    for (i,t) in [2.5,8.0,16.0,23.0].enumerated(){let c=CGContext(data:nil,width:W,height:H,bitsPerComponent:8,bytesPerRow:W*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!;render(c,t);try png(c.makeImage()!,"preview-\(i+1).png")}
    exit(0)
}
let out=root.appendingPathComponent("sipli-duo-4x1-silent.mp4")
try? FileManager.default.removeItem(at:out)
let writer=try AVAssetWriter(outputURL:out,fileType:.mp4)
let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:W,AVVideoHeightKey:H,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:20_000_000,AVVideoExpectedSourceFrameRateKey:fps]])
let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:W,kCVPixelBufferHeightKey as String:H])
writer.add(input);writer.startWriting();writer.startSession(atSourceTime:.zero)
for f in 0..<Int(duration*Double(fps)) {
    autoreleasepool {
        while !input.isReadyForMoreMediaData {Thread.sleep(forTimeInterval:0.002)}
        var pb:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,adaptor.pixelBufferPool!,&pb);let b=pb!;CVPixelBufferLockBaseAddress(b,[])
        let c=CGContext(data:CVPixelBufferGetBaseAddress(b),width:W,height:H,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(b),space:space,bitmapInfo:CGImageAlphaInfo.premultipliedFirst.rawValue|CGBitmapInfo.byteOrder32Little.rawValue)!
        render(c,Double(f)/Double(fps));CVPixelBufferUnlockBaseAddress(b,[])
        if !adaptor.append(b,withPresentationTime:CMTime(value:Int64(f),timescale:Int32(fps))){fatalError(writer.error!.localizedDescription)}
    }
    if f%90==0 {print("Rendered \(f)/780")}
}
input.markAsFinished();let done=DispatchSemaphore(value:0);writer.finishWriting{done.signal()};done.wait()
guard writer.status == .completed else {fatalError(writer.error!.localizedDescription)}
print("Completed 3840 × 960, 26 seconds, 30 fps")
