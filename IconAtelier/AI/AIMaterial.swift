import Foundation

struct AIMaterial: Identifiable, Hashable {
    let id: String
    let label: String
    let promptFragment: String

    static let all: [AIMaterial] = [
        .init(id: "matte",       label: "Matte",       promptFragment: "matte finish material, no gloss, no reflections, soft diffused surface"),
        .init(id: "glossy",      label: "Glossy",      promptFragment: "glossy shiny material, polished reflective surface, specular highlights"),
        .init(id: "glass",       label: "Glass",       promptFragment: "transparent glass material, refractive, subtle reflections, see-through"),
        .init(id: "metal",       label: "Metal",       promptFragment: "metallic material, brushed metal finish, subtle reflections, industrial feel"),
        .init(id: "gold",        label: "Gold",        promptFragment: "polished gold material, luxurious warm metallic golden surface, rich reflections"),
        .init(id: "silver",      label: "Silver",      promptFragment: "polished silver material, cool metallic surface, chrome-like reflections"),
        .init(id: "copper",      label: "Copper",      promptFragment: "copper material, warm reddish metallic surface, oxidized patina accents"),
        .init(id: "bronze",      label: "Bronze",      promptFragment: "bronze material, warm dark metallic surface, antique patina feel"),
        .init(id: "wood",        label: "Wood",        promptFragment: "natural wood material, visible wood grain texture, warm organic feel"),
        .init(id: "clay",        label: "Clay",        promptFragment: "soft matte clay material, handmade feel, smooth sculpted surface"),
        .init(id: "plastic",     label: "Plastic",     promptFragment: "smooth plastic material, slightly glossy, clean manufactured feel"),
        .init(id: "rubber",      label: "Rubber",      promptFragment: "soft rubber material, matte elastic surface, slightly textured grip feel"),
        .init(id: "marble",      label: "Marble",      promptFragment: "polished marble material, subtle veins and patterns, elegant stone surface"),
        .init(id: "concrete",    label: "Concrete",    promptFragment: "raw concrete material, rough mineral surface, brutalist industrial texture"),
        .init(id: "stone",       label: "Stone",       promptFragment: "natural carved stone material, rough hewn mineral surface, sculptural feel"),
        .init(id: "ceramic",     label: "Ceramic",     promptFragment: "glazed ceramic material, smooth porcelain-like surface, delicate crafted feel"),
        .init(id: "fabric",      label: "Fabric",      promptFragment: "soft fabric textile material, woven texture, cloth-like surface"),
        .init(id: "leather",     label: "Leather",     promptFragment: "rich leather material, fine grain texture, visible saddle stitch seams (point sellier), premium handcrafted luxury leather goods feel"),
        .init(id: "felt",        label: "Felt",        promptFragment: "soft felt material, fuzzy textile surface, handcrafted warm feel"),
        .init(id: "wool",        label: "Wool",        promptFragment: "knitted wool material, chunky yarn texture, cozy handmade feel"),
        .init(id: "embroidery",  label: "Embroidery",  promptFragment: "embroidered textile material, visible thread stitches, cross-stitch or satin stitch texture, handcrafted needlework on fabric"),
        .init(id: "mercury",     label: "Mercury",     promptFragment: "liquid mercury material, highly reflective chrome-like liquid surface, fluid metallic blob, T-1000 style molten metal"),
        .init(id: "ice",         label: "Ice",         promptFragment: "frozen ice material, translucent crystalline surface, cold blue refractions, frost details"),
        .init(id: "wax",         label: "Wax",         promptFragment: "warm wax material, slightly translucent, soft melting edges, candle-like surface"),
        .init(id: "candy",       label: "Candy",       promptFragment: "hard candy material, glossy sugary surface, translucent colorful sweet, lollipop-like shine"),
        .init(id: "chocolate",   label: "Chocolate",   promptFragment: "smooth chocolate material, rich brown glossy surface, molded confectionery feel"),
        .init(id: "leaf",        label: "Leaf",        promptFragment: "natural leaf material, organic green leaf texture with visible veins, shaped from a real tree leaf, botanical natural feel"),
        .init(id: "coral",       label: "Coral",       promptFragment: "organic coral material, porous natural marine texture, underwater reef aesthetic"),
        .init(id: "popcorn",     label: "Popcorn",     promptFragment: "popcorn material, the entire shape is made of clustered popcorn kernels, puffy irregular white and yellow pieces, movie snack texture"),
        .init(id: "balloon",     label: "Balloon",     promptFragment: "inflated latex balloon material, smooth stretched rubber surface, shiny highlights, balloon sculpture twist aesthetic"),
        .init(id: "crystal",     label: "Crystal",     promptFragment: "transparent crystal gemstone material, faceted cuts, prismatic light refractions, precious stone clarity"),
        .init(id: "rust",        label: "Rust",        promptFragment: "oxidized rusted metal material, orange-brown corroded iron surface, rough flaking patina, aged industrial decay"),
        .init(id: "velvet",      label: "Velvet",      promptFragment: "soft velvet material, rich plush textile with light-catching nap, luxurious deep fabric texture"),
        .init(id: "denim",       label: "Denim",       promptFragment: "denim fabric material, visible twill weave pattern, indigo blue cotton textile, jeans texture"),
        .init(id: "fur",         label: "Fur",         promptFragment: "soft animal fur material, dense fluffy hair covering the surface, plush furry texture"),
        .init(id: "feather",     label: "Feather",     promptFragment: "feather material, the shape is covered in layered bird feathers, soft downy texture with fine barbs"),
        .init(id: "bubblegum",   label: "Bubblegum",   promptFragment: "stretched bubblegum material, soft pink glossy elastic surface, slightly translucent, chewy candy feel"),
        .init(id: "cookie",      label: "Cookie",      promptFragment: "baked cookie material, golden brown crumbly dough texture, shortbread or sugar cookie feel with subtle cracks"),
        .init(id: "cheese",      label: "Cheese",      promptFragment: "cheese material, smooth yellow-orange surface with characteristic round holes, Swiss cheese aesthetic"),
        .init(id: "cotton",      label: "Cotton",      promptFragment: "fluffy cotton material, soft white cloud-like cotton balls or cotton candy texture, airy and light"),
        .init(id: "holographic", label: "Holographic", promptFragment: "holographic iridescent material, rainbow shifting reflections, prismatic surface, futuristic feel"),
        .init(id: "cardboard",   label: "Cardboard",   promptFragment: "corrugated cardboard material, raw brown recycled texture, handmade craft feel"),
        .init(id: "terracotta",  label: "Terracotta",  promptFragment: "terracotta clay material, warm reddish-orange unglazed ceramic, Mediterranean pottery feel"),
        .init(id: "obsidian",    label: "Obsidian",    promptFragment: "volcanic obsidian glass material, deep black mirror-like surface, sharp beveled edges, subtle iridescent reflections, premium gemstone feel"),
        .init(id: "cloud",       label: "Cloud",       promptFragment: "soft puffy cloud material, billowy rounded cumulus shapes, white airy volumetric surface, dreamy sky-like softness")
    ]
}
