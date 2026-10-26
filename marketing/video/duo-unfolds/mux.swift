import Foundation
import AVFoundation
let folder=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let movie=AVURLAsset(url:folder.appendingPathComponent("sipli-duo-4x1-silent.mp4"))
let music=AVURLAsset(url:folder.appendingPathComponent("soundtrack.wav"))
let composition=AVMutableComposition()
let video=composition.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid)!
try video.insertTimeRange(CMTimeRange(start:.zero,duration:movie.duration),of:movie.tracks(withMediaType:.video)[0],at:.zero)
let audio=composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid)!
try audio.insertTimeRange(CMTimeRange(start:.zero,duration:movie.duration),of:music.tracks(withMediaType:.audio)[0],at:.zero)
let export=AVAssetExportSession(asset:composition,presetName:AVAssetExportPresetHighestQuality)!
let out=folder.appendingPathComponent("sipli-iphone-duo-4x1.mp4")
try? FileManager.default.removeItem(at:out)
export.outputURL=out;export.outputFileType = .mp4;export.shouldOptimizeForNetworkUse=true
let done=DispatchSemaphore(value:0);export.exportAsynchronously{done.signal()};done.wait()
guard export.status == .completed else {fatalError(export.error!.localizedDescription)}
print("Final export:",out.path)
