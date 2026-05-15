# IconAtelier — TODO technique

## Plan en cours — Création AI-first (overlay-only)

**Problème** : aujourd'hui la création AI est branchée via `AIPromptBar` en bas
de l'éditeur, contextuelle à la sélection. Lien implicite, friction à l'entrée,
canvas vide intimidant. La création AI doit devenir le geste **par défaut** au
tap sur le « + » de la galerie.

### ⚠️ Décision de scope (2026-05-13)

**Pas de génération AI de background.** Audit des apps installées sur le device
de Patrice : ~95 % utilisent un fond uni, dégradé ou mesh. Les rares fonds
« riches » sont en réalité des overlays étendus à toute la surface. Pas de
besoin réel → on évite un appel API lent, coûteux et superflu.

À la place :
- **AI = uniquement l'overlay** (modèle `gpt-image-1.5`, un seul appel).
- **Backgrounds = bibliothèque procédurale** (cf. section dédiée plus bas) :
  grilles, dots, lignes, gradients, mesh, etc., paramétrables (couleur,
  taille, espacement, rotation).

### Vision UX

1. Galerie → tap « + »
2. Sheet `CreateIconSheet` (.presentationDetent .large) avec :
   - Header « Create an icon »
   - Carousel **cartes empilées** swipeables (deck façon Arc Search / Raycast,
     pas un grid Canva). Chaque carte = un `PromptTemplate` (overlay).
   - Sur la carte : `previewGradient`, `name`, `tagline`, slots tappables
     (Menu natif avec choices prédéfinis + entrée « Custom… » pour text libre)
     + suggestion de background procédural (modifiable au chargement de
     l'éditeur).
   - Bouton primaire « Generate ».
   - **Lien discret en dessous** : « Start from scratch → » (shortcut vers le
     flow blank actuel). ⚠️ Surtout PAS en première carte du carousel, sinon
     90 % des users tapent dessus.
3. Tap Generate → `GeneratingOverlay` plein écran sur la sheet :
   - Spinner + compteur « 0:42 »
   - Message « Generating your icon — keep the app open »
   - Cancel button
4. Call OK → nouveau `IconProject` créé avec background procédural suggéré +
   overlay AI posé, navigation push vers `ContentView` immédiatement éditable.

### Modèle de données (à créer dans `PromptTemplate.swift`)

```swift
struct PromptSlot: Identifiable, Hashable {
    let id: String           // "style", "subject"
    let label: String
    let choices: [String]
    let defaultChoice: String
}

struct PromptTemplate: Identifiable {
    let id: String
    let name: String
    let tagline: String?
    let previewGradient: [Color]
    let overlayPromptTemplate: String       // "A {subject} in {style} style…"
    let slots: [PromptSlot]
    let suggestedBackground: ProceduralBackground.ID  // → lib procédurale
}
```

Slots référencés par `{slot_id}`, résolus au submit.

### Catalogue initial — 5 templates à écrire

1. **Bold Subject** — `{subject}`, `{style}` (flat/3D/line/glossy)
2. **Material World** — `{material}` (marble/velvet/paper/glass), `{subject}`
3. **Cosmic** — `{cosmic_theme}` (nebula/aurora/void/galaxy), `{subject}`
4. **Retro / Synthwave** — `{era}` (synthwave/risograph/vintage-print),
   `{subject}`
5. **Minimal Mono** — `{base_color}`, `{subject}`

3-5 choices par slot suffisent au début. Champ libre toujours dispo.

### Logique de génération

Dans `IconCreationModel` (`@Observable`) :

- `let overlay = try await service.generateOverlay(prompt)` — un seul appel.
- Wrap dans
  `UIApplication.shared.beginBackgroundTask(withName: "icon-gen") { … }` puis
  `endBackgroundTask` en `defer`. Couvre lock screen accidentel + brief switch
  d'app. **NE PAS** partir sur `URLSessionConfiguration.background` :
  sur-engineering pour un seul call court.
- Stocker la `Task` pour le cancel button.

### Création du projet final

Étendre `IconProject` avec :
```swift
@MainActor
static func createWithAI(
    overlayImage: UIImage,
    overlayPrompt: String,
    background: ProceduralBackground,
    in context: ModelContext
) -> IconProject
```

→ Pré-remplit le project avec le background procédural + un calque
`aiOverlay`, puis on navigue dessus.

### Fichiers à créer

- `PromptTemplate.swift` — modèle + catalogue statique
- `CreateIconSheet.swift` — sheet + carousel
- `TemplateCard.swift` — vue d'une carte
- `IconCreationModel.swift` — `@Observable` orchestrant l'appel overlay
- `GeneratingOverlay.swift` — UI d'attente

### Fichiers à modifier

- `GalleryView.swift` — le « + » présente `CreateIconSheet` au lieu de créer
  direct un blank `IconProject`.
- `IconProject.swift` — convenience factory `createWithAI(…)`.
- ⚠️ NE PAS toucher `ContentView` / `AIPromptBar` : ils restent utiles pour
  l'édition contextuelle d'un calque AI existant.

### Skills à invoquer AVANT chaque morceau (strict, cf. CLAUDE.md)

- Étape 1 (`PromptTemplate.swift`) : `swift-language`
- Étape 2 (`IconCreationModel`) : `swift-concurrency`, `swiftui-patterns`
- Étape 3 (`GeneratingOverlay`) : `swiftui-animation`,
  `swiftui-layout-components`
- Étape 4 (`CreateIconSheet` + `TemplateCard` + carousel) :
  `swiftui-layout-components`, `swiftui-navigation`, `swiftui-animation`
- Étape 5 (branchement `GalleryView` + factory `IconProject`) :
  `swiftdata`, `swiftui-navigation`

### Ordre de chantier

1. Bibliothèque procédurale de backgrounds (cf. section dédiée) — prérequis
   pour que les templates puissent référencer un `suggestedBackground`.
2. `PromptTemplate.swift` + catalogue (pure data, vite itérable)
3. `IconCreationModel` + appel overlay + `beginBackgroundTask`
4. `GeneratingOverlay` (UI minimal)
5. `CreateIconSheet` + `TemplateCard` + carousel
6. Branchement dans `GalleryView` + factory `IconProject.createWithAI`

### Nettoyage déjà fait

- `AIPromptPreset` struct + `aiPrompts` + `overlayPrompts` retirés de
  `BackgroundPresets.swift` (code mort, restes d'une version précédente).
- `linear`, `radial`, `mesh` presets conservés (toujours utilisés).

---

## Bibliothèque de backgrounds procéduraux

Remplace la génération AI de background. Tout est dessiné en Core Graphics /
SwiftUI (`Canvas`, `Path`, `LinearGradient`, `MeshGradient`) — instantané,
gratuit, infiniment paramétrable.

### Catégories ciblées

- **Unis** : couleur plate (déjà couvert).
- **Gradients** : linéaire, radial, conique, mesh (iOS 18+, déjà partiellement
  couvert).
- **Patterns géométriques** :
  - Grid (quadrillage cahier, points d'intersection optionnels)
  - Dots (bayer / square / hex)
  - Lines / stripes (verticales, horizontales, diagonales)
  - Cross-hatching
  - Checkerboard
  - Isometric grid
  - Hexagons
  - Halftone (gradient de tailles de dots)
- **Patterns texturés (procéduraux)** :
  - Noise / grain (overlay sur unie ou gradient)
  - Waves / squiggles
  - Blueprint (grid bleu + lignes fines)

### Paramètres communs

- Couleur de fond
- Couleur du pattern + opacité
- Taille / espacement de la maille
- Rotation
- (Selon pattern) épaisseur de trait, taille de point, etc.

### Modèle de données

À écrire dans `Model/ProceduralBackground.swift` :

```swift
enum ProceduralBackground: Identifiable, Codable {
    case solid(SolidParams)
    case linearGradient(LinearParams)
    case radialGradient(RadialParams)
    case mesh(MeshParams)
    case grid(GridParams)
    case dots(DotsParams)
    case stripes(StripesParams)
    // …
}
```

Chaque `*Params` est un struct `Codable` avec ses sliders. Un
`ProceduralBackground` est sérialisable dans `IconProject` (remplace l'image
bg actuelle).

### UI

- Picker plein écran dans l'éditeur (remplace le sheet de bg AI).
- Grille de previews live (un mini-render de chaque pattern avec params par
  défaut).
- Tap → applique → l'inspecteur de droite affiche les sliders du pattern
  choisi (couleur, taille, rotation, etc.).

### Skills à invoquer

- `swiftui-layout-components`, `swiftui-animation`, `swift-language`,
  `swiftdata` (pour la persistance des params dans `IconProject`).

### Ordre de chantier

1. Modèle `ProceduralBackground` + 3 patterns de base (solid, grid, dots) +
   renderer en `Canvas`.
2. Picker UI + inspecteur de sliders.
3. Migration : `IconProject.background` passe de `UIImage` à
   `ProceduralBackground` (ou union si on garde la possibilité d'une image
   personnalisée). Plan de migration SwiftData à prévoir.
4. Étendre le catalogue (stripes, hex, halftone, noise…).

---

## TODO

### Export `AppIcon.appiconset` / `.icon`
- Générer toutes les tailles iOS (`@2x`, `@3x`, marketing 1024×1024) zippées en `AppIcon.appiconset`.
- Drop direct dans `Assets.xcassets`.
- Variantes light / dark / tinted iOS 18+ (3 versions de l'icône).
- Supporter le format Icon Composer multi-layers (`.icon`) pour iOS 26.

### Migration `Secrets.swift` → Keychain
- Stockage de la clé OpenAI dans le Keychain.
- Écran Settings dédié pour saisir / mettre à jour la clé.
- Prérequis avant soumission App Store.

---

## Idées à étudier

### Galerie en ligne communautaire
- Les utilisateurs peuvent publier leur icône sur une galerie publique avec :
  - Nom de l'app
  - Lien App Store
  - Vignette de l'icône (et idéalement le projet IconAtelier réutilisable, si on veut aller plus loin)
- Backend probable : Cloudflare Workers + D1 + R2 pour le storage des images.
- Modération à prévoir (signalement, blocklist).
- Aspect viral / acquisition : chaque app dans la galerie = un backlink vers IconAtelier.
- À border App Store guideline 1.2 (UGC : modération, signalement, blocage utilisateur, EULA).

### Variantes en 1 clic
- Bouton « régénérer » qui relance le même prompt 3-4 fois en parallèle.
- Affichage en grille pour comparer.
- Pin / drop des candidats.

### Édition de zone sur un calque (inpainting)
- `gpt-image-1.5` via `images.edit` avec masque.
- Re-générer **une partie** d'un overlay sans tout refaire.
- UI : sélection de zone à la main / lasso / rectangle.

### Effets par calque
- Drop shadow, glow, tint configurables par calque.
- À intégrer dans la sheet d'édition existante.

### Mask iOS / squircle preview
- Toggle « voir avec / sans masque ».
- Implémentation : `RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)` — `style: .continuous` est **indispensable** (squircle / continuous curve, pas un rounded rect classique).
- Le mask est uniquement pour la preview en contexte ; **ne pas pré-masquer** le 1024×1024 exporté (iOS applique le mask automatiquement).
- Preview en contexte App Store listing (en plus du home screen déjà présent).

### Prompts assistés
- Sélecteurs guidés : style (flat / 3D / glossy / line art), couleur dominante, objet central.
- L'app construit le prompt complet en arrière-plan.
- Le prompt brut reste éditable.

### Prompts à trous (fill-in-the-blank)
- Templates de prompts prêts à l'emploi avec des champs à remplir, façon Mad Libs.
- Ex : « A [style] icon of a [object] on a [color] background, [mood] mood ».
- Chaque trou propose un picker / liste de suggestions (style, objet, couleur, ambiance…) tout en restant librement éditable.
- Le prompt final reste modifiable à la main avant envoi.
- Plusieurs templates par catégorie (background, overlay, full icon) pour couvrir les cas courants.

### Bibliothèque de presets
- Presets par catégorie : Productivité, Jeu, Finance, Santé, Météo, Voyage, etc.
- Chaque preset = combo (style de fond + style d'overlay + palette).

### Bibliothèque d'assets IA générés (réutilisation)
- Conserver l'historique des images IA générées (backgrounds + overlays) dans le projet ou globalement.
- Les exposer sur la Home (galerie d'assets) et au moment d'ajouter un élément (« choisir parmi mes images IA »), pour éviter de relancer un appel API quand on a déjà l'image qu'il faut.
- À décider : portée (par projet vs global), purge / quota, dedup par prompt+seed, miniatures persistées.
- Stockage probable : SwiftData + fichiers sur disque (`Application Support`), pas tout en base.

### Couleur de fond extraite d'un calque
- Une fois un calque généré, proposer un fond avec sa couleur dominante / palette complémentaire.
- Bypass API pour le fond → instantané.

### Picker de palettes
- Material, Tailwind, Apple HIG.
- À évaluer : utile ou bruit ? Pertinent surtout si on l'expose dans
  l'inspecteur des backgrounds procéduraux et dans le picker de couleur des
  calques.

### Formats supplémentaires
- Watch icons, Mac icons, visionOS, tvOS.
- Mac Catalyst pour bosser sur Mac.

## Idée spin-off — App dédiée "AI iMessage Stickers"

App séparée, **pas** dans IconAtelier, qui réutilise le moteur de génération AI
+ édition pour produire des stickers iMessage cohérents.

### Pourquoi
La concurrence (Sticker Drop, Sticker Maker Studio, StickerX, Sticker Maker +
Stickers, etc.) fait **exclusivement** du découpage de photos existantes
(subject lifting iOS 16+ + bg removal + texte). **Personne ne génère de sticker
from scratch via prompt.** Trou réel dans le marché segment sticker maker iOS.

### Différenciants potentiels
- **Generate from prompt** : "a tiny astronaut waving" → image générée + fond
  transparent natif → directement utilisable comme sticker.
- **Pack visuellement cohérent** : générer 12 stickers dans le même style
  (mascot, flat, sketch…), pas un patchwork — argument de vente fort vs la
  concurrence où chaque sticker est isolé.
- **Édition vectorielle propre** : contour "puffy" Apple-style, contour blanc,
  ombre portée, en SwiftUI Canvas.
- **Mad Libs / templates** pour non-designers.

### Architecture technique
- Cible iOS 17+ (Live Stickers + Messages app extension).
- 3 cibles Xcode : app principale + Messages app extension + App Group partagé.
- Flow : génération AI dans l'app → écriture PNG transparent dans le container
  App Group → la Messages extension (`MSStickerBrowserViewController`) lit
  dynamiquement les fichiers → apparaît dans l'onglet de l'app dans Messages.
- **Limitation Apple confirmée** : impossible de pousser au tiroir système
  universel (celui partagé partout dans iOS). Le sticker reste dans **notre**
  onglet dans Messages. Seul Apple peut alimenter le tiroir universel (via
  Photos appui long → Add Sticker). Pas de hack via share extension non plus
  (vérifié).
- Fallback "tiroir universel" pour l'utilisateur : bouton "Save to Photos" +
  tip "long-press in Photos to add as sticker".

### Risques
- **App Store review 4.2** (minimum functionality) : doit être suffisamment
  riche en édition pour ne pas être perçue comme un wrapper de générateur.
- **Coût API** : la concurrence est gratuite/freemium très peu cher. Pricing à
  réfléchir (BYOK ? abo ? crédits ?).
- **Risque WWDC** : si Apple sort un "Genmoji-like" pour stickers dans iOS 27,
  ça peut tuer ce segment. À surveiller WWDC juin 2026.

### À vérifier avant d'investir
- Confirmer que `MSStickerBrowserViewController` peut bien être alimenté
  dynamiquement depuis un App Group (validé par cas Sticker Drop / Stickerboard
  en prod, mais à reproduire en POC).
- Tester la qualité du fond transparent de `gpt-image-1.5` sur du sticker
  (différent du fond transparent d'une icône d'app).
- Tester l'effet "puffy / outline" SwiftUI sur PNG transparent.
