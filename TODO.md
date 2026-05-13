# IconAtelier — TODO technique

## Plan en cours — Création AI-first (Mad Libs templates)

**Problème** : aujourd'hui la création AI est branchée via `AIPromptBar` en bas
de l'éditeur, contextuelle à la sélection. Lien implicite, friction à l'entrée,
canvas vide intimidant. La création AI doit devenir le geste **par défaut** au
tap sur le « + » de la galerie, tout en laissant possible la création
text/symbol pur.

### Vision UX

1. Galerie → tap « + »
2. Sheet `CreateIconSheet` (.presentationDetent .large) avec :
   - Header « Create an icon »
   - Carousel **cartes empilées** swipeables (deck façon Arc Search / Raycast,
     pas un grid Canva). Chaque carte = un `PromptTemplate`.
   - Sur la carte : `previewGradient`, `name`, `tagline`, list de slots
     tappables (Menu natif avec choices prédéfinis + entrée « Custom… » pour
     text libre).
   - Bouton primaire « Generate ».
   - **Lien discret en dessous** : « Start from scratch → » (qui shortcut vers
     le flow blank actuel). ⚠️ Surtout PAS en première carte du carousel,
     sinon 90 % des users tapent dessus.
3. Tap Generate → `GeneratingOverlay` plein écran sur la sheet :
   - Spinner + 2 dots de progression (background ● overlay ●)
   - Compteur « 0:42 »
   - Message « Generating your icon — keep the app open »
   - Cancel button
4. Les deux calls réussissent → nouveau `IconProject` créé, navigation push
   vers `ContentView` avec bg AI + overlay AI déjà posés et éditables.

### Modèle de données (à créer dans `PromptTemplate.swift`)

```swift
struct PromptSlot: Identifiable, Hashable {
    let id: String           // "style", "subject", "palette"
    let label: String        // affiché en UI
    let choices: [String]    // suggestions
    let defaultChoice: String
}

struct PromptTemplate: Identifiable {
    let id: String
    let name: String
    let tagline: String?
    let previewGradient: [Color]
    let backgroundPromptTemplate: String  // "A {palette} gradient background…"
    let overlayPromptTemplate: String     // "A {subject} in {style} style…"
    let slots: [PromptSlot]                // partagés entre les 2 prompts
}
```

Slots référencés par `{slot_id}` dans les chaînes, résolus au submit. **Les
slots sont partagés entre les deux prompts** (un slot `{subject}` peut
apparaître dans le bg ET dans l'overlay — c'est le point d'unité de la carte).

### Catalogue initial — 5 templates à écrire

1. **Bold Subject** — `{subject}`, `{style}` (flat/3D/line/glossy), `{palette}`
2. **Material World** — `{material}` (marble/velvet/paper/glass), `{subject}`,
   `{accent_color}`
3. **Cosmic** — `{cosmic_theme}` (nebula/aurora/void/galaxy), `{subject}`
4. **Retro / Synthwave** — `{era}` (synthwave/risograph/vintage-print),
   `{subject}`
5. **Minimal Mono** — `{base_color}`, `{subject}`

3-5 choices par slot suffisent au début. Champ libre toujours dispo.

### Logique de génération

Dans `IconCreationModel` (`@Observable`) :

- `async let bg = service.generateBackground(…)`
- `async let ov = service.generateOverlay(…)`
- Wrap tout le bloc dans
  `UIApplication.shared.beginBackgroundTask(withName: "icon-gen") { … }` puis
  `endBackgroundTask` en `defer`. Couvre lock screen accidentel + brief switch
  d'app. **NE PAS** partir sur `URLSessionConfiguration.background` :
  sur-engineering (refacto delegate-based pour gain marginal).
- **Erreur partielle** : si bg OK et overlay KO (ou inverse), proposer un
  bouton **Retry overlay** / **Retry background** qui rejoue uniquement la
  branche échouée. Économie de call BYOK.
- Stocker la `Task` pour permettre le cancel button.

### Création du projet final

Étendre `IconProject` avec :
```swift
@MainActor
static func createWithAI(
    bgImage: UIImage, bgPrompt: String,
    overlayImage: UIImage, overlayPrompt: String,
    in context: ModelContext
) -> IconProject
```

→ Pré-remplit le project avec background AI + un calque `aiOverlay`, puis on
navigue dessus.

### Fichiers à créer

- `PromptTemplate.swift` — modèle + catalogue statique
- `CreateIconSheet.swift` — sheet + carousel
- `TemplateCard.swift` — vue d'une carte
- `IconCreationModel.swift` — `@Observable` orchestrant les 2 calls
- `GeneratingOverlay.swift` — UI d'attente

### Fichiers à modifier

- `GalleryView.swift` — le « + » présente `CreateIconSheet` au lieu de créer
  direct un blank `IconProject`.
- `IconProject.swift` — convenience factory `createWithAI(…)`.
- ⚠️ NE PAS toucher `ContentView` / `AIPromptBar` : ils restent utiles pour
  l'édition contextuelle d'un calque AI existant.

### Skills à invoquer AVANT chaque morceau (strict, cf. CLAUDE.md)

- Étape 1 (`PromptTemplate.swift`) : `swift-language`
- Étape 2 (`IconCreationModel` + parallélisation) : `swift-concurrency`,
  `swiftui-patterns`
- Étape 3 (`GeneratingOverlay`) : `swiftui-animation`,
  `swiftui-layout-components`
- Étape 4 (`CreateIconSheet` + `TemplateCard` + carousel) :
  `swiftui-layout-components`, `swiftui-navigation`, `swiftui-animation`
- Étape 5 (branchement `GalleryView` + factory `IconProject`) :
  `swiftdata`, `swiftui-navigation`

### Ordre de chantier

1. `PromptTemplate.swift` + catalogue (pure data, vite itérable)
2. `IconCreationModel` + génération parallèle + `beginBackgroundTask` (cœur
   métier, à valider tôt avec test sur device)
3. `GeneratingOverlay` (UI minimal)
4. `CreateIconSheet` + `TemplateCard` + carousel (le plus visuel, peaufiné en
   dernier)
5. Branchement dans `GalleryView` + factory `IconProject.createWithAI`

### Nettoyage déjà fait

- `AIPromptPreset` struct + `aiPrompts` + `overlayPrompts` retirés de
  `BackgroundPresets.swift` (code mort, restes d'une version précédente).
- `linear`, `radial`, `mesh` presets conservés (toujours utilisés).

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

### Génération de raccourcis Shortcuts (grand public)
- Voie unique pour « customiser » l'icône d'une app tierce (sandbox iOS).
- iOS 26 : lancement instantané, bandeau résiduel ~3s.
- À évaluer comme mode secondaire si pivot grand public.
- Risque App Store guideline 2.3 / 4.2 à border.

### Fonds natifs étendus
- Vérifier l'état actuel des dégradés (linéaires, radiaux, coniques, mesh iOS 18+).
- Patterns simples à ajouter ? (grain, noise, lignes)
- Picker de palettes (Material, Tailwind, Apple HIG) — utile ou bruit ?

### Formats supplémentaires
- Watch icons, Mac icons, visionOS, tvOS.
- Mac Catalyst pour bosser sur Mac.
