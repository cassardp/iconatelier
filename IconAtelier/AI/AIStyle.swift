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
            id: "3d",
            label: "3D",
            promptFragment: "3D isometric collectible icon, front-facing three-quarter view, refined contours and rounded edges, matte-to-satin surfaces with subtle micro-reflections, deep ambient occlusion in crevices, soft diffused studio lighting, ultra-soft feathered contact shadow on a clean neutral surface; semi-realistic stylized proportions, balanced and appealing; natural realistic palette, restrained and harmonious; mix of straight and curved surfaces, generous fillets, no sharp corners; moderate detail with subtle surface texture; no text or lettering. Single centered subject, isolated on a neutral background, no duplicates, no extra elements, no frame, no background props."
        ),
        AIStyle(
            id: "pixar",
            label: "Pixar",
            promptFragment: "Pixar style. Stylized 3D Pixar-style character render in the unmistakable look of a Pixar animated feature film, soft rounded subdivision surfaces, slightly exaggerated cute proportions with oversized expressive eyes, three-quarter front-facing framing; warm cinematic key light with gentle rim light and rich global illumination, subtle ambient occlusion in crevices; subtle subsurface scattering on organic surfaces, smooth matte-to-satin materials with delicate controlled specular highlights, polished Pixar animation-film finish; vibrant warm storybook palette, appealing and inviting; high but readable detail, no busy texture noise; no text or lettering. Single centered subject, isolated on a soft neutral background, soft contact shadow under the subject acceptable, no duplicates, no extra elements, no frame, no other characters or props."
        ),
        AIStyle(
            id: "logo",
            label: "Logo",
            promptFragment: "flat vector logo mark in the spirit of Paul Rand, bold simplified geometric forms, confident silhouette, no outlines, no textures, no shading, completely flat; pure monochrome black on white; balanced mix of straight and curved geometry; extreme reduction, almost abstract, one strong idea; counter-shapes and negative space inside the mark allowed when the form calls for it; no text or lettering. Single centered subject, isolated on a plain white background, no duplicates, no extra elements, no frame, no cast shadows, no glows."
        ),
        AIStyle(
            id: "typography",
            label: "Typography",
            promptFragment: "a single typographic glyph, modern geometric sans-serif, semi-bold weight, balanced optical proportions, subtle flat two-tone shading suggesting volume without any 3D rendering, crisp clean edges; two-tone palette, one base color and one slightly darker accent; smooth balanced letterform, gentle curves and even strokes; minimal rendering, no textures; counters and apertures of the letter preserved exactly as the glyph's shape requires; no extra characters, just the single glyph. Single centered glyph, isolated on a neutral background, no duplicates, no extra elements, no frame, no cast shadows, no glows."
        ),
        AIStyle(
            id: "notion",
            label: "Notion",
            promptFragment: "minimalist black-and-white flat vector illustration in the expressive Notion avatar style, thick uniform monoline black outlines, organic confident hand-drawn quality, quirky charming proportions, selective solid black fills used as shape language for dark surfaces — not as shading or gradients, lighter areas remain pure flat white; strictly two values only, pure black and pure white, no gray, no gradients, no color; smooth organic confident lines, natural flowing shapes; extreme simplicity, very few strokes, almost abstract; no text or lettering. Single centered subject, isolated on a pure white background, no duplicates, no extra elements, no frame, no drop shadows. Outlines must be thick and uniform weight throughout, never thin or variable."
        ),
        AIStyle(
            id: "sticker",
            label: "Sticker",
            promptFragment: "flat die-cut sticker, solid opaque color fills, cartoon style, thick uniform off-white border (#FAF9F7, a warm near-white, never pure #FFFFFF) tracing the entire outer silhouette of the sticker uniformly; purely flat, no shading, no gradients, no 3D; limited palette of two to three bold flat colors; bold rounded simplified shapes; minimal interior detail, no textures; no text or lettering. Single centered subject, isolated on a transparent or neutral background, no duplicates, no extra elements, no frame, no drop shadow under the sticker. All shapes solid and fully filled, no holes inside the sticker. Every part of the sticker interior must be fully opaque; only the area outside the die-cut border is transparent."
        ),
        AIStyle(
            id: "doodle",
            label: "Doodle",
            promptFragment: "cute cartoon doodle illustration, thick uniform dark outlines of consistent weight throughout the entire shape — the outline color is a deep tone (dark brown, deep maroon, or near-black) slightly tinted to harmonize with the fill, never pure jet black; outlines are confident, slightly imperfect hand-drawn but smooth, never sketchy, never variable in weight; flat solid opaque color fills inside the outlines — strictly aplats, absolutely no gradients, no shading, no highlights, no 3D, no texture; saturated mid-tone palette, warm and earthy (mid brown, terracotta, dusty mint, teal, mustard, brick), never washed-out pastel, never neon; chunky exaggerated chubby silhouette — oversized rounded body shaped like a fat bean or potato, tiny stubby arms and legs hanging off the body, very short proportions, big round head fused with body or sitting directly on it; minimalist face: two small dot eyes spaced close together, a tiny simple smile, no nose, no other features; one or two small playful accents on top allowed (tiny sprouting leaves, a tuft of hair, a single sparkle) drawn with the same line weight; minimal interior detail, no inner linework beyond the silhouette outline and the face dots; no text or lettering. Single centered subject, isolated on a plain neutral or soft uniform background, no duplicates, no extra characters, no frame, no drop shadow under the subject, no environment props. Outlines must be thick, smooth and uniform — never thin, never scratchy, never sketchbook-style hatching."
        )
    ]
}
