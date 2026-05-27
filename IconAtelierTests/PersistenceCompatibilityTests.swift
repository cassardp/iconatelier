import Foundation
import Testing
@testable import IconAtelier

@MainActor
@Suite("Persistence schema compatibility")
struct PersistenceCompatibilityTests {

    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    @Test("A legacy project.json without schemaVersion or recent fields still decodes")
    func decodesLegacyProject() throws {
        let json = """
        {
          "uuid": "11111111-1111-1111-1111-111111111111",
          "title": "Legacy",
          "createdAt": "2024-01-01T00:00:00Z",
          "updatedAt": "2024-01-01T00:00:00Z",
          "layers": []
        }
        """
        let project = try makeDecoder().decode(IconProject.self, from: Data(json.utf8))

        #expect(project.title == "Legacy")
        #expect(project.schemaVersion == 1)
        #expect(project.tags.isEmpty)
        #expect(project.isPublic == false)
        #expect(project.background == nil)
        #expect(project.layers.isEmpty)
    }

    @Test("Encoding then decoding preserves the project and stamps the current schema version")
    func roundTrip() throws {
        let project = IconProject(title: "Round trip")
        project.tags = ["icon", "tool"]
        project.isPublic = true
        project.ensureBackground()
        project.layers = [
            Layer.shape(name: "Squircle", spec: .iosSquircle),
            Layer.text(name: "Label", text: "Hi")
        ]

        let data = try makeEncoder().encode(project)
        let decoded = try makeDecoder().decode(IconProject.self, from: data)

        #expect(decoded.title == "Round trip")
        #expect(decoded.tags == ["icon", "tool"])
        #expect(decoded.isPublic == true)
        #expect(decoded.schemaVersion == IconProject.currentSchemaVersion)
        #expect(decoded.layers.count == 2)
        #expect(decoded.layers.map(\.kind) == [.parametricShape, .text])
        #expect(decoded.layers[1].text == "Hi")
        #expect(decoded.background != nil)
    }

    @Test("A new project encodes the current schema version into JSON")
    func encodesSchemaVersion() throws {
        let project = IconProject(title: "Fresh")
        let data = try makeEncoder().encode(project)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["schemaVersion"] as? Int == IconProject.currentSchemaVersion)
    }
}
