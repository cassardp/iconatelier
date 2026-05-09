import Foundation
import UIKit

enum OpenAIImageError: LocalizedError {
    case missingAPIKey
    case http(status: Int, body: String)
    case decoding
    case noData

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Clé API OpenAI manquante (Secrets.swift)."
        case .http(let status, let body): "Erreur HTTP \(status): \(body)"
        case .decoding: "Réponse OpenAI invalide."
        case .noData: "Aucune image renvoyée."
        }
    }
}

struct OpenAIImageService {
    private let endpoint = URL(string: "https://api.openai.com/v1/images/generations")!

    func generateBackground(prompt: String) async throws -> UIImage {
        try await generate(
            model: "gpt-image-2",
            prompt: prompt,
            background: nil
        )
    }

    func generateOverlay(prompt: String) async throws -> UIImage {
        try await generate(
            model: "gpt-image-1.5",
            prompt: prompt,
            background: "transparent"
        )
    }

    private func generate(model: String, prompt: String, background: String?) async throws -> UIImage {
        guard !Secrets.openAIKey.isEmpty, Secrets.openAIKey != "sk-REPLACE_ME" else {
            throw OpenAIImageError.missingAPIKey
        }

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

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

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
}
