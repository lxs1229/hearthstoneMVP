import SwiftUI
import CoreGraphics
import Foundation

struct CalibrationPreviewView: View {
    let image: CGImage
    let regions: [CaptureRegion]

    private var aspectRatio: CGFloat {
        CGFloat(image.width) / CGFloat(image.height)
    }

    var body: some View {
        let width: CGFloat = 256
        let height = width / aspectRatio

        ZStack(alignment: .topLeading) {
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)

            ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
                let rect = CGRect(
                    x: region.normalizedRect.origin.x * width,
                    y: region.normalizedRect.origin.y * height,
                    width: region.normalizedRect.size.width * width,
                    height: region.normalizedRect.size.height * height
                )

                Rectangle()
                    .stroke(Color.green.opacity(0.85), lineWidth: 1.5)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                Text(region.name)
                    .font(.system(size: 9, weight: .semibold))
                    .padding(2)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .position(x: rect.minX + 18, y: rect.minY + 8)
            }
        }
        .frame(width: width, height: height)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
}
