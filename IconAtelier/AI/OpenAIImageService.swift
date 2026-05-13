import Foundation
import UIKit

enum OpenAIImageError: LocalizedError {
    case missingAPIKey
    case http(status: Int, body: String)
    case decoding
    case noData
    case imageEncoding

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "OpenAI API key missing. Add it in Settings."
        case .http(let status, let body): "HTTP \(status): \(body)"
        case .decoding: "Invalid OpenAI response."
        case .noData: "No image returned."
        case .imageEncoding: "Could not prepare reference image."
        }
    }
}

struct OpenAIImageService {
    private let generationsURL = URL(string: "https://api.openai.com/v1/images/generations")!
    private let editsURL = URL(string: "https://api.openai.com/v1/images/edits")!

    func generateBackground(prompt: String, references: [UIImage] = []) async throws -> UIImage {
        try await run(
            model: "gpt-image-2",
            prompt: Self.wrapBackgroundPrompt(prompt),
            background: nil,
            references: references
        )
    }

    func generateOverlay(prompt: String, references: [UIImage] = []) async throws -> UIImage {
        try await run(
            model: "gpt-image-1.5",
            prompt: Self.wrapOverlayPrompt(prompt),
            background: "transparent",
            references: references
        )
    }

    static func wrapOverlayPrompt(_ userPrompt: String) -> String {
        """
        A single centered subject rendered in the visual style of a premium iOS app icon glyph or illustration (simplified confident shapes, clean lines, dense saturated palette, soft polished lighting, App Store quality): \(userPrompt).

        STRICT REQUIREMENTS (must be respected):
        - Fully transparent background. The output must be a PNG with a true alpha channel where every pixel that is not part of the subject is fully transparent (alpha = 0).
        - No background color, no gradient, no scene, no environment, no sky, no floor, no ground, no surface, no table, no wall, no stage, no studio backdrop, no plain color fill.
        - If a reference image is provided, use it ONLY as a guide for the subject's identity, shape, pose and proportions. Do NOT reproduce or carry over the reference image's background, sky, environment, ground, lighting, shadows, props, or any contextual element. The reference image's background must be completely discarded.
        - The subject is fully isolated, floating on transparency.
        - No shadow of any kind: no drop shadow, no cast shadow, no contact shadow, no ambient shadow under the object, no reflection, no glow halo on the ground.
        - Only ONE clearly defined object, with clean and crisp edges (alpha-cut style).
        - No additional decorative elements, no props, no particles, no smoke, no sparkles, no leaves, no rays, no extra small objects around the subject.
        - No text, no letters, no numbers, no logos, no watermark, no signature, no UI chrome, no frame, no border.
        - The subject is centered in the square frame with comfortable padding so it can be safely placed on top of any icon background.
        - Square 1:1 composition.
        """
    }

    static func wrapBackgroundPrompt(_ userPrompt: String) -> String {
        """
        Square iOS app icon background image, rendered in the visual style of a premium iOS app icon background (rich saturated colors, soft directional lighting, clean polished finish, App Store quality): \(userPrompt).

        STRICT REQUIREMENTS (must be respected):
        - The content of the image is fully driven by the prompt above. Scenes, characters, props, objects, environments, textures, gradients are all allowed if the prompt calls for them.
        - The image fills the entire square frame edge to edge. No outer border, no frame, no rounded corners drawn into the image, no vignette letterboxing, no padding around the image.
        - No text, no letters, no numbers, no captions, no labels, no logos, no watermark, no signature, no UI chrome.
        - Treat this as a background that another icon element may be placed on top of: avoid putting the single most important detail dead-center if the prompt does not require it, and keep the overall composition readable rather than chaotic. The center should remain reasonably clear visually.
        - Polished icon-quality rendering: clean lighting, consistent style throughout, no random clutter, no noisy artifacts.
        - Square 1:1 composition.
        """
    }

    private func run(
        model: String,
        prompt: String,
        background: String?,
        references: [UIImage]
    ) async throws -> UIImage {
        guard let apiKey = await APIKeyStore.shared.load(), !apiKey.isEmpty else {
            throw OpenAIImageError.missingAPIKey
        }

        let request: URLRequest
        if references.isEmpty {
            request = try makeGenerationRequest(
                apiKey: apiKey,
                model: model,
                prompt: prompt,
                background: background
            )
        } else {
            request = try makeEditRequest(
                apiKey: apiKey,
                model: model,
                prompt: prompt,
                background: background,
                references: references
            )
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIImageError.decoding
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIImageError.http(status: http.statusCode, body: body)
        }

        struct Envelope: Decodable {
            struct Item: Decodable { let b64_json: String? }
            let data: [Item]
        }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let b64 = envelope.data.first?.b64_json,
              let imgData = Data(base64Encoded: b64),
              let image = UIImage(data: imgData) else {
            throw OpenAIImageError.noData
        }
        return image
    }

    private func makeGenerationRequest(
        apiKey: String,
        model: String,
        prompt: String,
        background: String?
    ) throws -> URLRequest {
        var body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "size": "1024x1024",
            "n": 1,
            "output_format": "png",
        ]
        if let background {
            body["background"] = background
        }

        var request = URLRequest(url: generationsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120
        return request
    }

    private func makeEditRequest(
        apiKey: String,
        model: String,
        prompt: String,
        background: String?,
        references: [UIImage]
    ) throws -> URLRequest {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        appendField("model", model)
        appendField("prompt", prompt)
        appendField("size", "1024x1024")
        appendField("n", "1")
        appendField("output_format", "png")
        if let background {
            appendField("background", background)
        }

        for (index, image) in references.enumerated() {
            guard let jpegData = Self.prepareJPEGSquare(image) else {
                throw OpenAIImageError.imageEncoding
            }
            body.append("--\(boundary)\r\n")
            body.append(
                "Content-Disposition: form-data; name=\"image[]\"; filename=\"ref_\(index).jpg\"\r\n"
            )
            body.append("Content-Type: image/jpeg\r\n\r\n")
            body.append(jpegData)
            body.append("\r\n")
        }

        body.append("--\(boundary)--\r\n")

        var request = URLRequest(url: editsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = body
        request.timeoutInterval = 120
        return request
    }

    static func preparePNGSquare(_ image: UIImage, side: CGFloat = 1024) -> Data? {
        let target = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.pngData { _ in
            drawAspectFill(image, into: target)
        }
    }

    // Photo references have no alpha — JPEG is ~5–10× smaller than PNG at
    // visually equivalent quality, which dramatically reduces upload time
    // to OpenAI. The /images/edits endpoint accepts JPG, PNG, and WEBP.
    static func prepareJPEGSquare(
        _ image: UIImage,
        side: CGFloat = 1024,
        quality: CGFloat = 0.85
    ) -> Data? {
        let target = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.jpegData(withCompressionQuality: quality) { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: target))
            drawAspectFill(image, into: target)
        }
    }

    private static func drawAspectFill(_ image: UIImage, into target: CGSize) {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return }
        let scale = max(target.width / sourceSize.width, target.height / sourceSize.height)
        let drawSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        let origin = CGPoint(
            x: (target.width - drawSize.width) / 2,
            y: (target.height - drawSize.height) / 2
        )
        image.draw(in: CGRect(origin: origin, size: drawSize))
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
