import Foundation
import AVFoundation
import AppKit
let url=URL(fileURLWithPath:CommandLine.arguments[1]), a=AVURLAsset(url:url)
let v=a.tracks(withMediaType:.video)[0]
let reader=try AVAssetReader(asset:a)
let out=AVAssetReaderTrackOutput(track:v,outputSettings:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA])
reader.add(out);reader.startReading();var count=0
while let s=out.copyNextSampleBuffer(){count += 1;_ = CMSampleBufferGetPresentationTimeStamp(s)}
guard reader.status == .completed, count == 780, v.naturalSize == CGSize(width:3840,height:960), abs(a.duration.seconds-26)<0.01 else {fatalError("Video validation failed")}
let ar=try AVAssetReader(asset:a)
let ao=AVAssetReaderTrackOutput(track:a.tracks(withMediaType:.audio)[0],outputSettings:[AVFormatIDKey:kAudioFormatLinearPCM,AVLinearPCMBitDepthKey:32,AVLinearPCMIsFloatKey:true,AVLinearPCMIsNonInterleaved:false])
ar.add(ao);ar.startReading();var peak:Float=0, sum=0.0, samples=0
while let s=ao.copyNextSampleBuffer(){if let b=CMSampleBufferGetDataBuffer(s){let size=CMBlockBufferGetDataLength(b);var data=[Float](repeating:0,count:size/4);data.withUnsafeMutableBytes{_ = CMBlockBufferCopyDataBytes(b,atOffset:0,dataLength:size,destination:$0.baseAddress!)};for x in data {peak=max(peak,abs(x));sum += Double(x*x);samples += 1}}}
guard ar.status == .completed, samples>0,peak<1 else {fatalError("Audio validation failed")}
let g=AVAssetImageGenerator(asset:a);g.appliesPreferredTrackTransform=true
for (i,t) in [2.5,8.0,16.0,23.0].enumerated(){let cg=try g.copyCGImage(at:CMTime(seconds:t,preferredTimescale:600),actualTime:nil);let rep=NSBitmapImageRep(cgImage:cg);try rep.representation(using:.jpeg,properties:[.compressionFactor:0.88])!.write(to:URL(fileURLWithPath:"verified-\(i+1).jpg"))}
print("PASS: 780 decoded frames; 3840×960; 26.00s; \(v.nominalFrameRate) fps; audio peak \(peak); RMS \(sqrt(sum/Double(samples))); four final frames extracted.")
