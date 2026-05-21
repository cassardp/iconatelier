import Foundation

struct AIStyle: Identifiable, Hashable {
    let id: String
    let label: String
    let promptFragment: String

    static let all: [AIStyle] = [
        AIStyle(
            id: "illustration",
            label: "Illustration",
            promptFragment: "soft matte gradient illustration, simplified rounded forms, vivid saturated palette, smooth color-to-color transitions modeling gentle volume, diffused ambient lighting, no outlines, no grain, no specular highlights; matte finish with subtle tonal shifts for soft three-dimensionality; harmonious palette of three to five hues maximum; plump rounded silhouettes, organic curves favored over hard edges; moderate detail with a few selective accents; no text or lettering. Single centered subject, isolated on a neutral background, generous negative space around it, no duplicates, no extra elements, no frame, no background shape behind the subject, no cast shadows under the subject."
        ),
        AIStyle(
            id: "flat",
            label: "Flat",
            promptFragment: "flat vector illustration in the spirit of Adobe Illustrator artwork, strictly solid flat color fills only — absolutely no gradients, no shading, no highlights, no ambient occlusion, no 3D, no texture, no grain; clean geometric vector shapes with crisp clean edges; limited harmonious palette of three to five flat colors maximum; bold simplified silhouettes built from clean curves and straight lines; subtle thin uniform outlines allowed only if they reinforce the silhouette, otherwise no outlines; moderate detail expressed through shape composition, never through tonal shading; no text or lettering. Single centered subject, isolated on a plain neutral background, generous negative space around it, no duplicates, no extra elements, no frame, no cast shadows, no glows. Every fill must be a single solid color, perfectly uniform, with hard edges between color regions."
        ),
        AIStyle(
            id: "flat-mono",
            label: "Flat Mono",
            promptFragment: "flat monochrome vector illustration, single color only — pure solid white (#FFFFFF) shape on a transparent background; strictly one flat color, no gradients, no shading, no tonal variation, no highlights, no texture, no 3D, no grain; absolutely no outlines of any kind, no contour, no stroke, no border around the shape or any of its parts; absolutely no cutouts, no holes, no negative space carved inside the shape, no internal openings — the silhouette must be one fully filled solid white shape; clean geometric vector silhouette with crisp hard edges; bold simplified shape designed to read as a solid pictogram; all internal structure must be expressed through the outer silhouette only, never through inner cuts, never through outlines, never through color; no text or lettering. Single centered subject, isolated on a transparent background, no duplicates, no extra elements, no frame, no cast shadows, no glows. The entire subject must be rendered as one solid pure white silhouette so the user can tint it freely afterwards."
        )
    ]
}
