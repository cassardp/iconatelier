# NEXT_STEPS — Refactor architecture IconAtelier

Document de reprise après les étapes 1, 2, 4a, 4b et 5. Permet de clear la
session Claude et repartir sans perdre le contexte.

Daté du 2026-05-20 (mis à jour après étape 5).

---

## Contexte

L'app `IconAtelier` est un design tool paramétrique iOS (SwiftUI, iOS 18+,
architecture MV, `@Observable`) avec en parallèle un flow AI overlay
(text-to-image via OpenAI). ~12k LoC, 61 fichiers Swift.

Objectif déclaré : **ajouter des features** (resize handles au doigt, plus
d'effets, plus de formes) sans laisser le code se transformer en plat de
spaghettis.

Une discussion d'architecture a établi qu'une réécriture intégrale n'était
pas nécessaire, mais qu'un refactor progressif débloquerait l'ajout de
features. Le plan retenu (re-priorisé pour "ajouter features rapidement") :

1. **Extraire `CanvasGestureCoordinator` + `HitTester`** de `IconCanvasView` ✅
2. **Centraliser `baseUnitFraction(for: LayerKind)`** dans un seul fichier ✅
3. ~~Ajouter les handles (feature directe)~~ — **skip pour l'instant**
4. **`Layer` class → struct + `LayerContent` enum**
   - 4a — Layer class → struct (compat JSON préservée) ✅
   - 4b — `LayerContent` enum (image/text/shape) ✅
5. **`[LayerEffect]` stackable** (refactor des shadow existants en `.dropShadow(...)`) ✅
6. Ajouter les nouveaux effets un par un

**Étapes complétées : 1, 2, 4a, 4b, 5.**

---

## Étape 5 — résumé

`[LayerEffect]` stackable en place. Les drop shadows sont désormais un
effet parmi d'autres dans `appearance.effects`, et le rendu itère sur le
tableau.

**Nouveau fichier** :
- `IconAtelier/Model/LayerEffect.swift` — `struct DropShadow` (opacity,
  radius, offsetX/Y, color), `enum LayerEffect { case dropShadow(DropShadow) }`,
  et helper `View.applying(effects:side:scale:)` qui chaîne les modifiers
  via `reduce`+`AnyView` (data-driven composition).

**Changements modèle** :
- `LayerAppearance` gagne `var effects: [LayerEffect] = []`.
- `LayerShadow` struct supprimée, ainsi que `var shadow: LayerShadow`
  sur `Layer` (et son entrée dans `CodingKeys` / l'init).
- Les bridges `shadowOpacity/Radius/OffsetX/OffsetY/Color` sur `Layer`
  ciblent désormais le premier `.dropShadow` de `effects` (création
  paresseuse à la première écriture via `updateFirstDropShadow`).

**Rendu adapté** :
- `OverlayLayerRender` (LayerContentView.swift) et `IconRenderer.render`
  (ProjectPersistence.swift) remplacent leur `.shadow(...)` unique par
  `.applying(effects: layer.appearance.effects, side: side, scale: s)`.
- `EffectPanels.ShadowPanelContent` est inchangé — les bridges
  `shadow*` font tout le travail.

**Décisions actées** :
- **Compat JSON cassée** à nouveau (suite logique du choix de 4b). Le
  champ `shadow` disparaît du JSON ; à la place, `appearance.effects`.
- **Bridges conservés** sur `Layer` pour ne pas toucher aux call sites
  (`EffectPanels`, `IconProject.applyMaskPath`, etc.). À nettoyer au fil
  de l'eau, mais pas urgent.
- **`AnyView` accepté dans `applying(effects:...)`** : c'est le pattern
  data-driven legitime (la longueur de la chaîne dépend de la donnée),
  pas dans une boucle de rendu de liste — coût négligeable.

**Build** : `xcodebuild ... build` ⇒ **BUILD SUCCEEDED** pour iPhone.

---

## Étape 4b — résumé

`LayerContent` enum introduit. `Layer` est recomposé autour de sous-types.

**Nouveaux fichiers** :
- `IconAtelier/Model/LayerContent.swift` — sous-types `LayerTransform`,
  `LayerAppearance`, `LayerShadow`, `LayerFill`, `LayerBorder`,
  `ImageContent`, `TextContent`, `ShapeContent`, et l'enum `LayerContent`
  à 3 cas (`.image`, `.text`, `.shape`).

**Layer recomposé** :
```swift
struct Layer: Codable, Identifiable {
    var uuid: UUID
    var name: String
    var transform: LayerTransform
    var appearance: LayerAppearance
    var shadow: LayerShadow
    var content: LayerContent
    var imagePNGDirty: Bool  // non persisté (CodingKeys explicit)
}
```

**Décisions actées en passant** :
- **Compat JSON cassée** : projets sauvegardés ne se chargent plus
  (utilisateur a explicitement renoncé à la rétro-compat).
- **`RadialRepeatParams` rendu `Codable`** (ajout simple : 3 fields).
  Sur `TextContent`, désormais un champ direct (`radialRepeat:
  RadialRepeatParams?`) au lieu de squatter un `ShapeSpec`.
- **Factories typées** : `Layer.image(...)`, `Layer.text(...)`,
  `Layer.shape(...)` remplacent `Layer(kind:...)`. L'init principal ne
  prend plus `kind` mais `content`.
- **Bridges conservés sur `Layer`** : pour minimiser le scope de
  migration des ~80 call sites, beaucoup de propriétés calculées
  forwardent vers le bon case (`text`, `imagePNG`, `shapeSpec`,
  `tintColor`, `borderWidth`, `shadowOpacity`, etc.). Le modèle interne
  reste typé ; le code utilisateur n'a pas eu à changer partout.

**Simplifications glanées** :
- `LayerClipboard` ne dédouble plus `imagePNG` (déjà dans le content).
- `ContentView.exportSignature` passe par un encode JSON au lieu
  d'énumérer manuellement chaque field.
- `RadialRepeatPanelContent` n'a plus besoin des closures
  `wrapBase`/`disabledShapeSpec` — il opère via le bridge
  `radialRepeatParams` (text + shape unifiés).

**Build** : `xcodebuild ... build` ⇒ **BUILD SUCCEEDED** pour iPhone.

---

## Étape 4a — résumé (commit `687efb2`)

`Layer` est passé d'`@Observable final class` à `struct Codable, Identifiable`.

**Ce qui change** :
- `Layer.swift` : 397 → 263 lignes. `LayerSnapshot`, `snapshot()`, `apply()`
  supprimés. Custom `init(from:)` conservé pour la rétro-compat des
  projets sauvegardés (mêmes `CodingKeys`, mêmes raw values).
- `IconProject` : `IconProjectSnapshot.layers` est maintenant `[Layer]`
  direct (plus de `[LayerSnapshot]`). `apply(_:)` ne fait plus de
  reconciliation par UUID — un simple `layers = snapshot.layers`.
- Nouveaux helpers sur `IconProject` :
  - `mutate(id: UUID, _ block: (inout Layer) -> Void)`
  - `mutateLayers(ids: Set<UUID>, _ block: (inout Layer) -> Void)`
  - `layerBinding(id: UUID) -> Binding<Layer>?`
- `toggleLock(_ layer:)` devient `toggleLock(id:)`.
- 8 sites `@Bindable var layer: Layer` → `@Binding var layer: Layer`
  (`EffectPanels`, `LayerKindSections`, `ShapeContentSection`,
  `LayerEditorContent.OpacitySlider`).
- Les statics `enabledBinding(layer: Layer, ...)` prennent
  `Binding<Layer>` et mutent via `layer.wrappedValue.foo = …`.
- `LayerEditorContent` dérive un `Binding<Layer>` via
  `project.layerBinding(id:)` et le passe aux enfants.
- `IconCanvasView` (drag/magnify/rotate), `LayerActions`,
  `LayerClipboard`, `ProjectStore`, `LibraryImport`, `GalleryView` :
  mutations adaptées (par index ou via `project.mutate`).

**Compat persistance préservée** : aucune migration nécessaire pour les
projets existants — JSON byte-pour-byte identique en encode/decode.

**Décisions actées en passant** :
- Scale **isotrope** (pas de `scaleX`/`scaleY` distincts).
- `IconProject` reste `@Observable final class` (pas de pivot vers
  struct `Document` + `DocumentStore` — coût trop élevé pour le gain).
- Compat persistance via custom `init(from:)` + `decodeIfPresent ?? x`
  (cf. memory `feedback_swiftdata_migration`).

---

## Ce qui a été fait dans la session précédente (étapes 1-2)

### Nouveaux fichiers (3)

- `IconAtelier/Editor/LayerGeometry.swift`
  - `LayerGeometry.baseUnitFraction(for: LayerKind) -> CGFloat`
    (0.7 image, 0.6 text, 0.5 parametricShape)
  - `LayerGeometry.frameSide(for: Layer, canvasSide: CGFloat) -> CGFloat`
    (helper : `canvasSide * baseUnitFraction * layer.scale`)
- `IconAtelier/Editor/CanvasSnapping.swift`
  - Types top-level (sortis de `IconCanvasView`) :
    `SnapGuide`, `DragSnapState`, `RotationSnapState`
  - Constantes : `rotationSnapThresholdDegrees`, `objectSnapThresholdPoints`
  - Statics : `layerNormalizedBounds`, `snappedToLayerGuides`,
    `normalized(_: Angle)`, `snappedRotation`
- `IconAtelier/Editor/CanvasHitTester.swift`
  - Statics : `hitTestLayer(in:at:side:canvasSize:)`,
    `parametricShapeContains`, `imageHasOpaquePixel`, `sampleAlpha`

### Fichiers refactorés (4)

- `IconCanvasView.swift` : ~700 → ~395 lignes. Plus que rendu + gesture
  wiring. Tous les calculs (snap, hit-test) délégués aux nouveaux fichiers.
  `Self.foo(...)` → `CanvasSnapping.foo(...)` / `CanvasHitTester.foo(...)`.
- `LayerContentView.swift` : `0.7 / 0.6 / 0.5` → `LayerGeometry.baseUnitFraction(for:)`.
- `BooleanOpRenderer.swift` : pareil dans `vectorPath(for:canvasSide:)`.
- `ContentView.swift` : suppression de `layerBaseFraction(_:)` (privé),
  `lassoHitTest` utilise `LayerGeometry.frameSide(for:canvasSide:)`.

### Changement comportemental noté

`ContentView.layerBaseFraction(_:)` retournait `0.5` pour `.text` (alors
que le rendu utilise `0.6`). Cette divergence rendait le lasso plus
restrictif que ce que voit l'œil pour les layers texte. **Unifié sur
`0.6`** dans cette session ; donc le lasso accroche maintenant les texts
sur leur vraie bbox de rendu. Si ce n'était pas le comportement souhaité,
voir l'historique git de `ContentView.swift`.

### Build

`xcodebuild -project IconAtelier.xcodeproj -scheme IconAtelier -destination 'generic/platform=iOS' -configuration Debug build` ⇒ **BUILD SUCCEEDED**.

⚠️ SourceKit a affiché des faux positifs pendant cette session ("No such
module 'UIKit'", "Cannot find type 'Layer'"). Ce sont des artefacts
d'indexation, pas des erreurs de compilation — le build passe.

---

## État de la base de code après l'étape 4a

### Architecture actuelle

```
IconAtelier/
  Model/
    IconProject.swift            (483 l. — @Observable class, undo simplifié)
    Layer.swift                  (263 l. — struct Codable, flat fields)
    Background.swift, ProjectSession.swift, StoredTypes.swift, …
  Editor/
    IconCanvasView.swift         (~400 l. — gestures via project.mutate)
    CanvasSnapping.swift, CanvasHitTester.swift, LayerGeometry.swift
    ContentView.swift            (627 l. — encore lourd, à découper)
    LayerEditorContent.swift     (builds Binding<Layer> from project)
    EffectPanels.swift           (panels avec @Binding var layer: Layer)
    LayerContentView.swift, BooleanOpRenderer.swift, EditSheet.swift, …
  Shapes/, Paint/, AI/, Export/, Persistence/, Gallery/, UI/
```

### Ce qui n'a PAS encore été fait

Dettes structurelles restantes :

- `Layer` expose de nombreux **bridges computed** (~30 props) qui
  forwardent vers le bon case de `content`. Pratique pour limiter le
  scope de la migration ; à nettoyer progressivement (notamment les
  bridges `shadow*` qui disparaîtront avec l'étape 5
  `[LayerEffect]`).
- `Codable` manuel pour `IconProject` (decodeIfPresent), `Paint`,
  `ShapeSpec` (custom). Pas urgent.
- `ContentView` (627 l.) gère encore layout + sheets + lasso + AI flow +
  import + export + persist + thumbnail.
- Rendu dupliqué : `LayerContentView` (écran) vs `LayerForBooleanRender`
  (dans `BooleanOpRenderer.swift`) vs `IconRenderer` (thumbnail).
- `ShapeSpec` importe SwiftUI (`anyShape()`), pas testable hors UI.

---

## La suite (chronologique)

### Étape 3 — Resize handles au doigt (feature directe)

C'est ce qu'on a maintenant débloqué. Approche recommandée :

- Pour le layer sélectionné, **overlay au-dessus du canvas** avec des
  handles (4 coins + 4 milieux + 1 handle rotation au-dessus).
- Chaque handle = sa propre `View` avec sa propre `DragGesture`.
  Évite de toucher au gesture composé du canvas.
- Positionner les handles sur la bbox normalisée du layer ⇒ utiliser
  `CanvasSnapping.layerNormalizedBounds(layer)` (déjà disponible !) puis
  convertir en points écran via `side`.
- Le handle de coin NW agit sur `layer.scale` ET `layer.offset` pour
  garder le coin opposé fixe. Math : nouveau scale = `dist(NW, SE) / dist_initial`,
  nouveau offset = mid(NW, SE).
- Handles de milieu = scale uniforme (ou non-uniforme si tu introduis
  `scaleX` / `scaleY` distincts — décision à prendre).
- Si tu veux du scale non-uniforme, il faudra étendre `Layer` :
  - **Option A (rapide)** : ajouter `var scaleY: Double` + `scaleX`
    aliasé sur `scaleValue`. Marche mais ajoute du boilerplate Codable.
  - **Option B (propre)** : passer d'abord par l'étape 4 (Layer → struct)
    pour rendre l'extension triviale.
  - **Recommandation** : si tu n'as pas besoin de scale non-uniforme au
    MVP des handles, garde scale isotrope et fais l'étape 4 plus tard.
    Sinon, fais l'étape 4 avant les handles non-uniformes.

Inspiration de fichier à créer : `IconAtelier/Editor/SelectionHandles.swift`
qui s'ajoute en overlay dans `IconCanvasView.squircleIcon(side:)` quand
`session.selectedLayerUUID != nil`.

À garder en tête :
- Hit-test du handle a priorité sur hit-test du layer (la gesture du
  handle est un `.highPriorityGesture` dans son overlay).
- Cohérence avec la rotation : les handles tournent avec le layer.
  Application : positionner chaque handle local-puis-rotate.
- Snap des handles : appliquer `CanvasSnapping.snappedToLayerGuides` sur
  la nouvelle bbox calculée, idem que pour la translation aujourd'hui.

### Étape 5 — `[LayerEffect]` stackable

Maintenant que l'étape 4b est en place :

```swift
struct LayerAppearance: Codable, Equatable {
    var opacity: Double
    var effects: [LayerEffect]
}

enum LayerEffect: Codable, Equatable {
    case dropShadow(DropShadow)      // remplace shadowOpacity/Radius/Offset/Color actuels
    case innerShadow(InnerShadow)
    case glow(Glow)
    case blur(radius: Double)
    case stroke(Stroke)
    case colorOverlay(Paint)
    // ajouter un effet = ajouter un case + son panneau editor
}
```

Bénéfice :
- Tu peux empiler deux drop shadows (impossible aujourd'hui).
- Ajouter un nouvel effet = 1 case + 1 panneau (vs 9 endroits aujourd'hui).
- Rendu : `ForEach(effects) { effect in modifier(for: effect) }`.

Migration : refactorer les 5 props `shadowOpacity`/`shadowRadius`/
`shadowOffsetX`/`shadowOffsetY`/`storedShadowColor` du Layer existant en
un seul `effects: [.dropShadow(...)]`. Garder la rétro-compat au décodage
via `decodeIfPresent` sur les anciens champs.

### Plus tard (non bloquant)

- **Sortir `AIFlowController` de `ContentView`** : déplacer toute la
  logique `handlePromptSubmitted`, `generationTask`, timer, alerts dans
  un `@Observable` controller dédié. ~½ j.
- **Sortir `LassoController` de `ContentView`** : gesture + état lasso.
  ~½ j.
- **Unifier le rendu** : un seul `LayerView: View` consommé par écran +
  `ImageRenderer` (thumbnail, boolean, export). Suppression de
  `LayerForBooleanRender`. ~1 j.
- **Sortir SwiftUI de `ShapeSpec`** : `ShapeSpec` reste pure data, un
  `ShapeRenderer.path(for:in:) -> Path` vit côté render. Permet de
  prototyper des formes dans un Playground.
- **Asset store séparé** : `AssetStore.save(uuid → Data)` ; le Layer
  porte juste l'AssetID. Supprime `imagePNGDirty` et le re-decoding au
  load. À combiner avec l'étape 4.

---

## Décisions actées (étape 4a)

- [x] **Scale isotrope** (`scale` unique). Non-uniforme reportée à plus
      tard, viendrait avec les resize handles non-uniformes (étape 3).
- [x] **`IconProject` reste `@Observable final class`**. `layers` est
      maintenant `[Layer]` (value type). Undo trivial via
      `IconProjectSnapshot(background:, layers:)`.
- [x] **Migration persistence préservée** : custom `init(from:)`
      conservé, `decodeIfPresent ?? default` partout, JSON inchangé.

## Décisions actées (étape 4b)

- [x] **Compat JSON cassée** (choix utilisateur). Les projets
      sauvegardés en local doivent être supprimés ; pas de plumbing
      hybride.
- [x] **Bridges conservés sur `Layer`** plutôt que migration franche
      des ~80 call sites. Modèle interne propre, surface API
      progressive.
- [x] **Asset store séparé reporté** au step dédié plus bas.

---

## Comment reprendre

1. Lire ce fichier (`NEXT_STEPS.md`).
2. Lire `CLAUDE.md` (consignes projet : skills d'abord, UI anglaise, etc.).
3. Pour l'étape 5 (`[LayerEffect]` stackable) : ajouter
   `var effects: [LayerEffect]` à `LayerAppearance`, définir l'enum
   `LayerEffect` (commencer par `.dropShadow`), migrer les bridges
   `shadow*` actuels de `Layer` vers un premier effet `.dropShadow`,
   adapter le rendu (`OverlayLayerRender.shadow(...)`) pour itérer sur
   `effects`. Les bridges peuvent ensuite disparaître.
4. Pour l'étape 3 (handles) : commencer par
   `IconAtelier/Editor/SelectionHandles.swift`, greffé en overlay sur
   `IconCanvasView.squircleIcon`. Utiliser
   `CanvasSnapping.layerNormalizedBounds` et `LayerGeometry` qui sont
   déjà en place.

---

## Build & install (rappel)

```bash
xcodebuild -project IconAtelier.xcodeproj -scheme IconAtelier \
  -destination 'generic/platform=iOS' -configuration Debug build
# install sur iPhone 15 Pro (device ID 00008130-000479320AA2001C) :
xcrun devicectl …
```
