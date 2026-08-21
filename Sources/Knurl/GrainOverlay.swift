import SwiftUI

struct GrainOverlay: View {
    var opacity: Double = 0.04

    @State private var noiseImage: NSImage?

    var body: some View {
        GeometryReader { geo in
            if let noiseImage {
                Image(nsImage: noiseImage)
                    .resizable()
                    .opacity(opacity)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        }
        .allowsHitTesting(false)
        .task { noiseImage = Self.generateNoise(width: 256, height: 256) }
    }

    private static func generateNoise(width: Int, height: Int) -> NSImage {
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        )!

        let data = bitmapRep.bitmapData!
        for i in 0..<(width * height * 4) {
            data[i] = UInt8.random(in: 50...200)
        }
        data.withMemoryRebound(to: UInt32.self, capacity: width * height) { ptr in
            for i in 0..<(width * height) {
                ptr[i] = (ptr[i] & 0xFFFFFF00) | 0x30
            }
        }

        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(bitmapRep)
        return image
    }
}
