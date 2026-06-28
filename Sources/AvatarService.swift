import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct AvatarStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let isPremium: Bool
    let top: UIColor
    let bottom: UIColor

    static let all: [AvatarStyle] = [
        .init(id: "pop", name: "Pop", isPremium: false, top: .systemPink, bottom: .systemPurple),
        .init(id: "comic", name: "Comic", isPremium: true, top: .systemTeal, bottom: .systemBlue),
        .init(id: "sketch", name: "Sketch", isPremium: true, top: UIColor(white: 0.9, alpha: 1), bottom: UIColor(white: 0.6, alpha: 1)),
        .init(id: "mono", name: "Mono", isPremium: true, top: .systemOrange, bottom: .systemRed),
    ]
}

enum AvatarError: Error { case badImage, notConfigured }

protocol AvatarGenerating {
    func generate(from image: UIImage, style: AvatarStyle) async throws -> UIImage
}

/// On-device stylized avatars: segment the subject, stylize with Core Image, and
/// composite onto a vivid gradient. Full generative avatars go behind Remote.
struct OnDeviceAvatarService: AvatarGenerating {
    private let context = CIContext()

    func generate(from image: UIImage, style: AvatarStyle) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) {
            try Self.render(image: image, style: style, context: context)
        }.value
    }

    private static func stylize(_ input: CIImage, style: AvatarStyle) -> CIImage {
        switch style.id {
        case "comic":
            return CIFilter.comicEffect().applied(to: input)
        case "sketch":
            let mono = CIFilter.photoEffectNoir(); mono.inputImage = input
            let edges = CIFilter.edges(); edges.inputImage = mono.outputImage; edges.intensity = 4
            let invert = CIFilter.colorInvert(); invert.inputImage = edges.outputImage
            return invert.outputImage ?? input
        case "mono":
            let f = CIFilter.photoEffectProcess(); f.inputImage = input
            return f.outputImage ?? input
        default: // pop
            let p = CIFilter.colorPosterize(); p.inputImage = input; p.levels = 6
            let c = CIFilter.colorControls(); c.inputImage = p.outputImage; c.saturation = 1.4
            return c.outputImage ?? input
        }
    }

    private static func render(image: UIImage, style: AvatarStyle, context: CIContext) throws -> UIImage {
        guard let cg = image.normalizedUp().cgImage else { throw AvatarError.badImage }
        let input = CIImage(cgImage: cg)
        let extent = input.extent

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])

        let stylized = stylize(input, style: style)

        let gradient = CIFilter.smoothLinearGradient()
        gradient.point0 = CGPoint(x: extent.midX, y: extent.maxY)
        gradient.point1 = CGPoint(x: extent.midX, y: extent.minY)
        gradient.color0 = CIColor(color: style.top)
        gradient.color1 = CIColor(color: style.bottom)
        let background = (gradient.outputImage ?? CIImage(color: CIColor(color: style.bottom))).cropped(to: extent)

        let composed: CIImage
        if let mask = request.results?.first?.pixelBuffer {
            var maskImage = CIImage(cvPixelBuffer: mask)
            maskImage = maskImage.transformed(by: CGAffineTransform(
                scaleX: extent.width / maskImage.extent.width,
                y: extent.height / maskImage.extent.height))
            let blend = CIFilter.blendWithMask()
            blend.inputImage = stylized
            blend.backgroundImage = background
            blend.maskImage = maskImage
            composed = blend.outputImage ?? stylized
        } else {
            composed = stylized
        }

        guard let result = context.createCGImage(composed.cropped(to: extent), from: extent) else {
            throw AvatarError.badImage
        }
        return UIImage(cgImage: result)
    }
}

struct RemoteAvatarService: AvatarGenerating {
    let apiKey: String
    func generate(from image: UIImage, style: AvatarStyle) async throws -> UIImage { throw AvatarError.notConfigured }
}

private extension CIFilter {
    func applied(to image: CIImage) -> CIImage {
        setValue(image, forKey: kCIInputImageKey)
        return outputImage ?? image
    }
}

extension UIImage {
    func normalizedUp() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
