import Foundation
import UIKit

// MARK: - Errors

enum CommunityError: LocalizedError {
    case renderFailed
    case bundleFailed
    case invalidResponse
    case http(status: Int, message: String)
    case notPublished

    var errorDescription: String? {
        switch self {
        case .renderFailed: "Could not render the icon image."
        case .bundleFailed: "Could not package the project."
        case .invalidResponse: "Unexpected server response."
        case .http(let status, let message): "HTTP \(status): \(message)"
        case .notPublished: "This icon is not published."
        }
    }
}

// MARK: - DTOs (the server already returns camelCase keys)

struct CommunityIcon: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let authorName: String?
    let appStoreURL: String?
    let tags: [String]
    let width: Int?
    let downloads: Int
    let createdAt: Int          // epoch ms
    let pngURL: String
    let projectURL: String
}

struct CommunityListResponse: Decodable, Sendable {
    let items: [CommunityIcon]
    let nextCursor: Int?
}

struct CommunityPublishResponse: Decodable, Sendable {
    let icon: CommunityIcon
    /// Returned only on first publication; nil on re-publish.
    let deleteToken: String?
}

// MARK: - Service

struct CommunityService: Sendable {
    /// Base URL of the IconAtelier web gallery (Cloudflare Worker).
    nonisolated static let baseURL = URL(string: "https://iconeatelier-web.cassard.workers.dev")!

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    // MARK: Publish

    /// Publishes a project: renders the 1024 PNG, zips the editable bundle, uploads both + metadata.
    func publish(_ project: IconProject) async throws -> CommunityPublishResponse {
        let payload = try await Self.preparePayload(project)

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.appendField("meta", payload.metaJSON, boundary: boundary)
        body.appendFile("png", filename: "icon.png", contentType: "image/png", data: payload.pngData, boundary: boundary)
        body.appendFile("project", filename: "project.zip", contentType: "application/zip", data: payload.zipData, boundary: boundary)
        body.append("--\(boundary)--\r\n")

        var request = URLRequest(url: Self.baseURL.appendingPathComponent("api/icons"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let data = try await Self.run(request)
        return try Self.decoder.decode(CommunityPublishResponse.self, from: data)
    }

    // MARK: List / download / delete (used by the in-app community gallery)

    func list(cursor: Int? = nil, limit: Int = 30) async throws -> CommunityListResponse {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent("api/icons"),
            resolvingAgainstBaseURL: true
        )!
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor { items.append(URLQueryItem(name: "cursor", value: String(cursor))) }
        components.queryItems = items

        let data = try await Self.run(URLRequest(url: components.url!))
        return try Self.decoder.decode(CommunityListResponse.self, from: data)
    }

    /// Downloads the editable project bundle (.zip) to a temporary file. Caller must clean it up.
    func downloadProjectBundle(id: String) async throws -> URL {
        let url = Self.baseURL.appendingPathComponent("api/icons/\(id)/project")
        let (localURL, response) = try await Self.session.download(for: URLRequest(url: url))
        try Self.validate(response, data: Data())

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("community-\(id)-\(UUID().uuidString).zip")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: localURL, to: destination)
        return destination
    }

    func delete(id: String, token: String) async throws {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("api/icons/\(id)"))
        request.httpMethod = "DELETE"
        request.setValue(token, forHTTPHeaderField: "X-Delete-Token")
        _ = try await Self.run(request)
    }

    // MARK: - Internals

    private static let decoder = JSONDecoder()

    /// Extracts everything needed off the @Observable model on the main actor into a Sendable payload.
    @MainActor
    private static func preparePayload(_ project: IconProject) throws -> Payload {
        guard let image = IconRenderer.render(project, side: 1024, includeBackground: true),
              let pngData = image.pngData() else {
            throw CommunityError.renderFailed
        }

        let zipURL: URL
        do {
            zipURL = try LibraryExporter.buildBundle(projects: [project])
        } catch {
            throw CommunityError.bundleFailed
        }
        defer { try? FileManager.default.removeItem(at: zipURL) }
        let zipData = try Data(contentsOf: zipURL)

        let meta = MetaPayload(
            title: project.title,
            sourceUuid: project.uuid.uuidString,
            authorName: project.authorName,
            appStoreURL: project.appStoreURL?.absoluteString,
            tags: project.tags
        )
        let metaJSON = String(decoding: try JSONEncoder().encode(meta), as: UTF8.self)
        return Payload(pngData: pngData, zipData: zipData, metaJSON: metaJSON)
    }

    private static func run(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)
        return data
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CommunityError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(ServerError.self, from: data))?.error
                ?? String(data: data, encoding: .utf8)
                ?? ""
            throw CommunityError.http(status: http.statusCode, message: message)
        }
    }

    private struct Payload: Sendable {
        let pngData: Data
        let zipData: Data
        let metaJSON: String
    }

    private struct MetaPayload: Encodable {
        let title: String
        let sourceUuid: String
        let authorName: String?
        let appStoreURL: String?
        let tags: [String]
    }

    private struct ServerError: Decodable { let error: String }
}

// MARK: - Multipart helpers

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }

    mutating func appendField(_ name: String, _ value: String, boundary: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func appendFile(
        _ name: String,
        filename: String,
        contentType: String,
        data: Data,
        boundary: String
    ) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(contentType)\r\n\r\n")
        append(data)
        append("\r\n")
    }
}
