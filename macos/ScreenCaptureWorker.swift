import Foundation
import AppKit
import ScreenCaptureKit
import CoreImage
import CoreMedia
import CoreVideo

// One capture stream per process: avoids launching 'screencapture' every 1.8 s.
// This requires the USER to approve Apple's Screen Recording permission.
// No TCC/ScreenCaptureApprovals database edits or consent bypass.
final class SnapshotOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    private let framePath: URL
    private let context = CIContext()
    private let queue = DispatchQueue(label: "tech.wfs.capture-output")
    private var lastWrite = Date.distantPast

    init(framePath: URL) {
        self.framePath = framePath
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        queue.async { [self] in
            guard Date().timeIntervalSince(lastWrite) >= 1.0 else { return }
            let image = CIImage(cvPixelBuffer: pixel)
            guard let cg = context.createCGImage(image, from: image.extent),
                  let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return }
            do {
                try data.write(to: framePath, options: .atomic)
                lastWrite = Date()
            } catch {
                fputs("[WFS Capture] Cannot write frame: \(error)\n", stderr)
            }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        fputs("[WFS Capture] Stream stopped: \(error)\n", stderr)
        exit(12)
    }
}

@main
struct CaptureWorker {
    static func main() async {
        guard CommandLine.arguments.count == 2 else {
            fputs("Usage: WFS-Capture <private-frame-file.png>\n", stderr)
            exit(2)
        }
        let dest = URL(fileURLWithPath: CommandLine.arguments[1])
        do {
            let screens = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let display = screens.displays.first else {
                throw NSError(domain: "WFS", code: 1, userInfo: [NSLocalizedDescriptionKey: "No shareable display available"])
            }
            let config = SCStreamConfiguration()
            config.width = min(display.width, 1920)
            config.height = min(display.height, 1200)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            config.showsCursor = false
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let out = SnapshotOutput(framePath: dest)
            let stream = SCStream(filter: filter, configuration: config, delegate: out)
            try stream.addStreamOutput(out, type: .screen, sampleHandlerQueue: DispatchQueue(label: "tech.wfs.sckit"))
            try await stream.startCapture()
            print("[WFS Capture] Native ScreenCaptureKit stream active; user consent required.")
            fflush(stdout)
            while true { try await Task.sleep(for: .seconds(10)) }
        } catch {
            fputs("[WFS Capture] Could not start authorized capture: \(error)\n", stderr)
            exit(10)
        }
    }
}
