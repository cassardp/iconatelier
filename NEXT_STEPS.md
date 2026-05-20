# NEXT_STEPS — Refactor architecture IconAtelier

Document de reprise après les étapes 1 et 2. Permet de clear la session
Claude et repartir sans perdre le contexte.

Daté du 2026-05-20.

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

1. **Extraire `CanvasGestureCoordinator` + `HitTester`** de `IconCanvasView`
2. **Centraliser `baseUnitFraction(for: LayerKind)`** dans un seul fichier
3. Ajouter les handles (feature directe)
4. **`Layer` class → struct + `LayerContent` enum**
5. **`[LayerEffect]` stackable** (refactor des shadow existants en `.dropShadow(...)`)
6. Ajouter les nouveaux effets un par un

**Cette session a complété les étapes 1 et 2.**

---

## Ce qui a été fait dans cette session

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

## État de la base de code après cette session

### Architecture actuelle

```
IconAtelier/
  Model/                         (@Observable final class — toujours en place)
    IconProject.swift            (473 l. — Codable manuel + undo snapshot)
    Layer.swift                  (397 l. — God-class, ~30 props)
    Background.swift, ProjectSession.swift, StoredTypes.swift, …
  Editor/
    IconCanvasView.swift         (~395 l. — beaucoup mieux)
    CanvasSnapping.swift         ← nouveau
    CanvasHitTester.swift        ← nouveau
    LayerGeometry.swift          ← nouveau, source unique des base fractions
    ContentView.swift            (627 l. — encore lourd, à découper)
    LayerContentView.swift, BooleanOpRenderer.swift, EditSheet.swift, …
  Shapes/, Paint/, AI/, Export/, Persistence/, Gallery/, UI/
```

### Ce qui n'a PAS encore été fait

Toutes les dettes structurelles identifiées dans la discussion d'archi
restent en place :

- `Layer` est toujours une `@Observable final class` portant les ~30
  propriétés de tous les kinds confondus.
- `LayerSnapshot` (struct parallèle pour undo) existe toujours.
- `Codable` manuel dans `Layer`, `IconProject`, `Paint`.
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

### Étape 4 — `Layer` class → struct + `LayerContent` enum

Plus gros refactor. À faire avant l'étape 5.

Modèle cible :

```swift
struct Layer: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var transform: LayerTransform    // offset, scale, rotation, flips
    var appearance: LayerAppearance  // opacity (et plus tard les effects)
    var isLocked: Bool
    var content: LayerContent
}

enum LayerContent: Codable, Equatable {
    case image(ImageContent)         // assetID, tint
    case text(TextContent)           // string, weight, design, fill, border…
    case shape(ShapeContent)         // spec, fill, border…
}
```

Gains :

- `Codable` 100% synthétisé. Suppression des ~150 lignes de boilerplate
  encode/decode dans `Layer.swift`.
- `LayerSnapshot` supprimé : `Layer` est value type donc snapshot gratuit.
- `undoStack: [Document]` (au lieu de `[IconProjectSnapshot]`).
- Un text layer n'a plus de champ `imagePNG`. Modèle plus propre.

Migration :
- `IconProject` doit alors devenir `Document` (struct) ou rester class
  mais avec `var layers: [Layer]` en value. **Recommandation** : garder
  `IconProject` comme `@Observable final class` enveloppe (pour `@Bindable`
  dans les sheets), mais ses `layers` deviennent `[Layer]` value.
  L'undo devient `[layers snapshot, background snapshot]`.
- Les `@Bindable var layer` dans les panneaux d'édition deviennent des
  `Binding<Layer>` dérivés de `project.layers[index]`. Verbose mais propre.
- **Migration de persistence** : aucune migration nécessaire si on garde
  les mêmes `CodingKeys` (rawValue des cases LayerContent à choisir
  pour matcher `kind: "image" | "text" | "parametricShape"`). À tester.
- **Asset store** : les `imagePNG: Data` doivent migrer vers un
  `AssetStore` indexé par `AssetID`. Voir aussi la discussion archi
  (le `Layer` contient juste un UUID asset, pas les bytes).

### Étape 5 — `[LayerEffect]` stackable

Dès que l'étape 4 est en place :

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

## Décisions à acter avant l'étape 4

- [ ] **Scale non-uniforme (`scaleX/scaleY`)** ou isotrope (`scale`) ?
      Conditionne la modélisation et l'UI des handles.
- [ ] **`IconProject` reste `@Observable final class` ou devient struct
      `Document` + `@Observable DocumentStore` enveloppe ?**
      Recommandation : DocumentStore enveloppe (plus testable, undo
      trivial `[Document]`).
- [ ] **Migration persistence : compat descendante des projets existants
      après changement de modèle ?** À tester avec un projet sauvegardé
      avant la migration.

---

## Comment reprendre

1. Lire ce fichier (`NEXT_STEPS.md`).
2. Lire `CLAUDE.md` (consignes projet : skills d'abord, UI anglaise, etc.).
3. Pour l'étape 3 (handles) : commencer par `IconAtelier/Editor/SelectionHandles.swift`,
   greffé en overlay sur `IconCanvasView.squircleIcon`. Utiliser
   `CanvasSnapping.layerNormalizedBounds` et `LayerGeometry` qui sont déjà
   en place.
4. Pour l'étape 4 (Layer → struct) : commencer par dupliquer `Layer.swift`
   en `LayerV2.swift` (struct), faire compiler en parallèle, basculer les
   appelants un par un, supprimer l'ancien à la fin. Chemin long mais
   permet de mergeable par incréments.

---

## Build & install (rappel)

```bash
xcodebuild -project IconAtelier.xcodeproj -scheme IconAtelier \
  -destination 'generic/platform=iOS' -configuration Debug build
# install sur iPhone 15 Pro (device ID 00008130-000479320AA2001C) :
xcrun devicectl …
```
