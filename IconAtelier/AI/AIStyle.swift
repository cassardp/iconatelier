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
        ),
        AIStyle(
            id: "glyph",
            label: "Glyph",
            promptFragment: "an iOS app-icon glyph — a single highly abstracted geometric pictogram representing the subject, designed to live inside an Apple system app icon, not an illustration of a real-world object; radical geometric reduction to the most essential silhouette, built from circles, squircles, rounded rectangles, arcs and clean strokes, balanced optical proportions; perfectly flat solid fill in a single saturated color or a smooth two-stop linear gradient, no outlines, no shading, no texture, no 3D, no perspective; crisp vector-quality anti-aliased edges, even stroke weights, generous rounded terminals; restrained palette of one base color and at most one accent; no text or lettering. Single centered glyph, isolated on a plain neutral background, generous symmetrical padding, no frame, no badge behind the glyph, no scene, no environment, no cast shadow, no duplicates, no extra elements."
        ),
        AIStyle(
            id: "squircle-badge",
            label: "Badge",
            promptFragment: "an iOS app-icon interior element rendered as a small three-dimensional badge — a soft squircle or rounded button shape with the subject expressed as a simplified sculpted form sitting on or fused with it, designed to feel like the central motif of an Apple app icon (Settings, Compass, Maps pin) rather than a standalone object; semi-realistic stylized proportions, refined rounded edges and generous fillets, matte-to-satin surfaces with delicate micro-reflections, soft diffused studio key light from upper-left, gentle ambient occlusion in crevices, subtle internal glow; restrained Apple-style palette of two to four harmonious hues, one dominant tone; high but uncluttered detail, no busy texture, no outlines, no flat areas; no text or lettering. Single centered element, isolated on a plain neutral background, generous padding, very soft low contact shadow acceptable directly under the element, no frame, no scene, no environment, no perspective floor, no duplicates, no extra props."
        ),
        AIStyle(
            id: "gradient-mark",
            label: "Gradient Mark",
            promptFragment: "an iOS app-icon mark — a single abstracted vector shape representing the subject in the visual language of Apple icons like Photos, App Store, FaceTime or iCloud, not an illustration of a real-world object; bold simplified geometric silhouette built from arcs, lobes, swooshes or stylized strokes, radically reduced to one strong idea; filled with a smooth vibrant multi-stop linear or radial gradient oriented diagonally from a lighter warm tone to a deeper saturated tone, gradient transitions soft and continuous, no banding; perfectly flat in finish, no shading, no 3D, no outlines, no texture, no grain; crisp anti-aliased vector edges, balanced optical proportions; saturated Apple-style palette of two to three closely related hues; no text or lettering. Single centered mark, isolated on a plain neutral background, generous symmetrical padding, no frame, no badge behind the mark, no scene, no environment, no cast shadow, no duplicates, no extra elements."
        ),
        AIStyle(
            id: "glass-pill",
            label: "Glass",
            promptFragment: "an iOS app-icon interior element rendered in translucent glass — the subject expressed as an abstracted geometric form made of clear or lightly tinted glass, in the spirit of Apple's Liquid Glass visual language (Compass dials, Watch complications, refraction-heavy iOS elements), not an illustration of a real-world glass object; rounded refined silhouette, smooth optical surfaces with delicate edge highlights and a subtle bright rim along the upper contour, gentle internal refraction and color shift across the body, soft caustic glow underneath, soft diffused environment lighting from upper-left; restrained palette of one tinted hue and clear glass tones, low color saturation, no opaque areas, no flat fills, no outlines, no texture, no grain; crisp anti-aliased edges, semi-realistic glass rendering; no text or lettering. Single centered element, isolated on a plain neutral background, generous padding, very soft low contact shadow under the element acceptable, no frame, no scene, no environment, no perspective floor, no duplicates, no extra props."
        ),
        AIStyle(
            id: "ribbon-wave",
            label: "Ribbon",
            promptFragment: "an iOS app-icon mark composed of fluid ribbon-like or wave-like forms representing the subject in the visual language of Apple icons like Photos petals, Music waveforms, Weather gradients and FaceTime swooshes, not an illustration of a real-world object; one or two confident continuous curving shapes with smooth varying width, gentle overlaps and elegant crossings, radically reduced to one expressive gesture; filled with a smooth multi-stop linear or radial gradient transitioning between two to three saturated Apple-style hues, gradient transitions soft and continuous, no banding; perfectly flat in finish, no 3D, no outlines, no texture, no grain, no shading beyond the gradient; crisp anti-aliased vector edges, generous rounded terminals, balanced optical proportions; no text or lettering. Single centered mark, isolated on a plain neutral background, generous symmetrical padding, no frame, no badge behind the mark, no scene, no environment, no cast shadow, no duplicates, no extra elements."
        ),
        AIStyle(
            id: "stacked-cards",
            label: "Stacked",
            promptFragment: "an iOS app-icon interior element composed of stacked flat layers seen perfectly head-on with NO perspective, NO isometric tilt, NO 3D angle — the layers are viewed orthogonally from directly in front, parallel to the picture plane, like cards lying flat against the screen; two to four overlapping rounded rectangular or squircle layers offset only vertically (the back layer peeking out at the top, the front layer lower) and very slightly horizontally if needed, never rotated, never tilted, never skewed, no foreshortening, no diagonal staggering that suggests depth, no isometric projection; each layer rendered with a subtle frosted-ice / frozen-glass finish — semi-translucent surface with a delicate cool tint, soft frosted interior diffusion, a thin bright luminous rim along the upper and left edges suggesting a cold glassy material, gentle inner glow, NO transparency that reveals what is behind (the layers still read as solid cards with a frozen surface, not see-through windows); layers arranged so the subject's idea reads through the composition (color choice, small abstracted glyph on the front layer, palette tone chosen to feel right for the subject); crisp anti-aliased vector edges, perfectly uniform rounded corners; restrained palette of two to four harmonious cool-tinted hues (icy blues, pale teals, frosted lavenders or pale pastels), each layer a slightly different tint of the family; very soft narrow drop shadow between layers only, no shadow under the whole stack; no outlines, no grain, no noise; no text or lettering. Single centered composition, isolated on a plain neutral background, generous symmetrical padding, no frame, no scene, no environment, no perspective floor, no duplicates, no extra props. CRITICAL: viewed straight-on, flat-front, no isometric perspective whatsoever."
        ),
        AIStyle(
            id: "petal-bloom",
            label: "Bloom",
            promptFragment: "an iOS app-icon mark built as a radial composition — a single repeating unit derived from the subject, repeated four to seven times with perfect radial symmetry around a central point, in the spirit of Apple radial-bloom marks; the repeating unit's silhouette MUST be derived from the subject itself, not from a generic flower petal: e.g. a heart subject produces heart-shaped lobes, a flame produces flame-shaped lobes, a music subject produces curved note-tail lobes, a leaf subject produces leaf-shaped lobes, a star subject produces star-tip lobes, a drop subject produces teardrop lobes, an arrow produces arrow-shaped lobes, an abstract subject still finds a characteristic curve from its essence — never default to a generic rounded petal unless the subject is literally a flower or petal; the units are simplified rounded vector shapes with smooth swelling silhouettes, balanced optical proportions, generous rounded terminals, slight overlaps between adjacent units with gentle blend modes producing harmonious mixed hues at the overlaps; each unit filled with a smooth multi-stop radial or linear gradient, saturated Apple-style palette of three to six closely related vibrant hues distributed evenly around the wheel, palette tone chosen to feel right for the subject (warm hues for fire/sun subjects, cool hues for water/sky, etc.); perfectly flat in finish beyond the gradients, no outlines, no 3D, no texture, no grain; crisp anti-aliased vector edges; no text or lettering. Single centered radial composition, isolated on a plain neutral background, generous symmetrical padding, no frame, no badge behind it, no scene, no environment, no cast shadow, no duplicates, no extra elements. CRITICAL: do not reproduce the Apple Photos app icon; the repeating unit's shape must reflect the subject, not generic flower petals."
        ),
        AIStyle(
            id: "mono-outline",
            label: "Outline",
            promptFragment: "an iOS app-icon glyph rendered as a clean monoline outline pictogram representing the subject in the spirit of Apple SF Symbols and system toolbar icons, not an illustration of a real-world object; radical geometric reduction to the essential silhouette, built from arcs, circles, rounded rectangles and straight strokes joined with generous rounded corners and rounded terminals; uniform stroke weight throughout, medium-thick weight, no variable line width, no calligraphic effect; pure outline only with no fill inside the shapes — strictly empty interiors, the background showing through; single monochrome stroke color in a deep neutral tone (dark gray or near-black), no shading, no gradients, no 3D, no texture, no grain; crisp anti-aliased vector edges, balanced optical proportions; no text or lettering. Single centered glyph, isolated on a plain neutral background, generous symmetrical padding, no frame, no badge behind the glyph, no scene, no environment, no cast shadow, no duplicates, no extra elements."
        )
    ]
}
