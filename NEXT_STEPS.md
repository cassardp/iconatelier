# NEXT_STEPS — Refactor architecture IconAtelier

Document de reprise après les étapes 1, 2, 4a, 4b et 5. Permet de clear la
session Claude et repartir sans perdre le contexte.

Daté du 2026-05-20 (mis à jour après l'étape 7.1 — découpage de `ContentView`).

---

## Contexte

L'app `IconAtelier` est un design tool paramétrique iOS (SwiftUI, iOS 18+,
architecture MV, `@Observable`) avec en parallèle un flow AI overlay
(text-to-image via OpenAI). ~12k LoC, 61 fichiers Swift.

Objectif déclaré : **ajouter des features** (resize handles au doigt, plus
d'effets, plus de formes) sans laisser le code se transformer en plat de
spaghettis.

Plan retenu, re-priorisé pour « ajouter features rapidement » :

1. **Extraire `CanvasGestureCoordinator` + `HitTester`** de `IconCanvasView` ✅
2. **Centraliser `baseUnitFraction(for: LayerKind)`** dans un seul fichier ✅
3. **Resize handles au doigt** — feature directe, **à faire**
4. **`Layer` class → struct + `LayerContent` enum**
   - 4a — Layer class → struct ✅
   - 4b — `LayerContent` enum (image/text/shape) ✅
5. **`[LayerEffect]` stackable** (drop shadow extrait en `.dropShadow`) ✅
6. **Ajouter de nouveaux effets** un par un (innerShadow, glow, blur,
   stroke, colorOverlay…) — **à faire**
7. **Nettoyage structurel** (découper ContentView, unifier le rendu…)
   - 7.1 — Découper `ContentView` (AIFlowController + LassoController) ✅
   - 7.2 — Unifier le rendu (LayerContentView + BooleanOpRenderer + IconRenderer
     → un seul LayerView) — **à faire, prochain**
   - 7.3 — Sortir SwiftUI de `ShapeSpec` — à faire
   - 7.4 — Asset store séparé pour les PNG — *skippé tant que pas un goulet*

**Étapes complétées : 1, 2, 4a, 4b, 5, 7.1.**
**À faire : 7.2 (rendu unifié — prochain), 7.3, 3 (handles), 6 (effets).**

---

## État de la base de code (post-étape 7.1)

```
IconAtelier/
  Model/
    IconProject.swift            (470 l. — @Observable class, undo simplifié)
    Layer.swift                  (550 l. — struct Codable, bridges flat fields
                                  vers LayerContent + LayerAppearance.effects)
    LayerContent.swift           (enum LayerContent + sous-types)
    LayerEffect.swift            (enum LayerEffect + helper applying(effects:))
    Background.swift, ProjectSession.swift, StoredTypes.swift, …
  Editor/
    IconCanvasView.swift         (409 l. — gestures via project.mutate)
    CanvasSnapping.swift, CanvasHitTester.swift, LayerGeometry.swift
    ContentView.swift            (435 l. — layout root + sheets + wiring)
    AIFlowController.swift       (91 l. — @Observable @MainActor, prompt+gen flow)
    LassoController.swift        (136 l. — @Observable @MainActor, drag/tap gestures
                                  + canvas/bar/row frames + boolean ops)
    LayerEditorContent.swift     (Binding<Layer> from project)
    EffectPanels.swift           (ShadowPanelContent + Border + Transform)
    LayerContentView.swift, BooleanOpRenderer.swift, EditSheet.swift, …
  Shapes/, Paint/, AI/, Export/, Persistence/, Gallery/, UI/
```

### Dette structurelle restante

- `Layer` expose **~30 bridges computed** qui forwardent vers le bon case
  de `content` ou vers `appearance.effects`. Pratique pour limiter le
  scope ; à nettoyer progressivement quand les call sites disparaissent.
- `Codable` manuel pour `IconProject` (decodeIfPresent), `Paint`,
  `ShapeSpec`. Pas urgent.
- Rendu dupliqué : `LayerContentView` (écran) vs `LayerForBooleanRender`
  (`BooleanOpRenderer.swift`) vs `IconRenderer` (thumbnail/export).
  → étape 7.2.
- `ShapeSpec` importe SwiftUI (`anyShape()`), pas testable hors UI.
  → étape 7.3.

---

## Étape 7.1 — résumé

`ContentView` découpé : 608 → 435 lignes. Le flow AI et le lasso sont
extraits dans deux controllers `@Observable @MainActor` injectés en
`@State`.

**Nouveaux fichiers** :
- `IconAtelier/Editor/AIFlowController.swift` (91 l.) — owns
  `showPromptSheet`, `isGenerating`, `generationStartDate`,
  `generationError`, `showNoAPIKeyAlert`. Expose `submit(...)` qui
  encapsule appel `OpenAIImageService`, timeout 90 s, animation et
  callback `onSuccess` (utilisé par ContentView pour
  `presentEditSheet()`).
- `IconAtelier/Editor/LassoController.swift` (136 l.) — owns
  `canvasFrame`, `layersBarFrame`, `layerRowFrames`, `lassoRect`. Expose
  `dragGesture(project:session:spaceName:)`,
  `clearTapGesture(session:spaceName:)`, `performBooleanOperation(...)`.
  Le hit-test interne reste privé.

**Pattern** :
- Les gestures sont retournées par méthodes (`some Gesture`).
- Callbacks `onChanged`/`onEnded` utilisent `MainActor.assumeIsolated`
  car les closures SwiftUI ne sont pas isolées par défaut.
- ContentView déclare `@Bindable var ai = ai` en tête de `body` pour
  obtenir des bindings sur les propriétés du controller (sheet/alert
  drivers).

**Décisions actées** :
- Controllers en `@State` (pas en environnement) — usage local à
  ContentView, pas de partage profond.
- `editorSpaceName` reste sur `ContentView` et passé en paramètre aux
  méthodes du controller (constante statique).
- `presentEditSheet`, `addShapeLayer`, `addTextLayer`,
  `handleImportResult`, `closeProject`, `deleteCurrentProject`,
  `persistSnapshotInBackground`, `exportSignature` restent dans
  ContentView (couplés au wiring layout/sheet, pas justifiable de les
  déplacer).

---

## Étape 5 — résumé (commit `4bcbafd`)

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
- `EffectPanels.ShadowPanelContent` inchangé — les bridges absorbent.

**Note revert blur (commit `f216a43`)** : un effet `.blur` avait été
ajouté dans `cca63b6` (« step 6 »), puis annulé par retour en arrière
dans la conversation. Le pipeline est prêt à accueillir d'autres effets
(le pattern « 1 case + 1 panel » est validé), mais aucun effet
supplémentaire n'est implémenté pour l'instant.

**Décisions actées** :
- **Compat JSON cassée** à nouveau (suite logique du choix de 4b). Le
  champ `shadow` disparaît du JSON ; à la place, `appearance.effects`.
- **Bridges conservés** sur `Layer`.
- **`AnyView` accepté dans `applying(effects:...)`** : pattern
  data-driven légitime, pas dans une boucle de rendu de liste.

---

## Étape 4b — résumé (commit `be74d93`)

`LayerContent` enum introduit. `Layer` est recomposé autour de sous-types.

**Nouveaux fichiers** :
- `IconAtelier/Model/LayerContent.swift` — sous-types `LayerTransform`,
  `LayerAppearance`, `LayerFill`, `LayerBorder`, `ImageContent`,
  `TextContent`, `ShapeContent`, et l'enum `LayerContent` à 3 cas
  (`.image`, `.text`, `.shape`).
  *(Note : `LayerShadow` initialement défini ici a été retiré en
  étape 5.)*

**Layer recomposé** :
```swift
struct Layer: Codable, Identifiable {
    var uuid: UUID
    var name: String
    var transform: LayerTransform
    var appearance: LayerAppearance  // gagne `effects: [LayerEffect]` en étape 5
    var content: LayerContent
    var imagePNGDirty: Bool  // non persisté (CodingKeys explicit)
}
```

**Décisions actées** :
- **Compat JSON cassée** : projets sauvegardés ne se chargent plus.
- **`RadialRepeatParams` Codable** ; sur `TextContent`, désormais
  un champ direct (`radialRepeat: RadialRepeatParams?`).
- **Factories typées** : `Layer.image(...)`, `Layer.text(...)`,
  `Layer.shape(...)` remplacent `Layer(kind:...)`.
- **Bridges conservés sur `Layer`** : modèle interne typé, surface
  API progressive.

**Simplifications glanées** :
- `LayerClipboard` ne dédouble plus `imagePNG`.
- `ContentView.exportSignature` passe par un encode JSON.
- `RadialRepeatPanelContent` opère via le bridge unifié `radialRepeatParams`.

---

## Étape 4a — résumé (commit `687efb2`)

`Layer` est passé d'`@Observable final class` à `struct Codable, Identifiable`.

**Ce qui change** :
- `Layer.swift` : 397 → 263 lignes en 4a (puis ~550 l. après bridges 4b + 5).
  `LayerSnapshot`, `snapshot()`, `apply()` supprimés.
- `IconProject` : `IconProjectSnapshot.layers` est `[Layer]` direct,
  `apply(_:)` = simple `layers = snapshot.layers`.
- Nouveaux helpers : `mutate(id:)`, `mutateLayers(ids:)`,
  `layerBinding(id:)`, `toggleLock(id:)`.
- 8 sites `@Bindable var layer: Layer` → `@Binding var layer: Layer`.
- `IconCanvasView`, `LayerActions`, `LayerClipboard`, `ProjectStore`,
  `LibraryImport`, `GalleryView` : mutations par index ou via
  `project.mutate`.

**Décisions** :
- Scale **isotrope** (pas de `scaleX`/`scaleY` distincts).
- `IconProject` reste `@Observable final class`.
- Compat persistance préservée en 4a (cassée ensuite en 4b + 5).

---

## Étapes 1-2 — résumé (commit `d5e222c`)

### Nouveaux fichiers

- `IconAtelier/Editor/LayerGeometry.swift` — `baseUnitFraction(for:)`,
  `frameSide(for:canvasSide:)`.
- `IconAtelier/Editor/CanvasSnapping.swift` — `SnapGuide`,
  `DragSnapState`, `RotationSnapState`, `layerNormalizedBounds`,
  `snappedToLayerGuides`, `snappedRotation`.
- `IconAtelier/Editor/CanvasHitTester.swift` — `hitTestLayer`,
  `parametricShapeContains`, `imageHasOpaquePixel`, `sampleAlpha`.

### Fichiers refactorés

- `IconCanvasView.swift` : ~700 → ~395 lignes. Calculs (snap, hit-test)
  délégués aux nouveaux fichiers.
- `LayerContentView.swift`, `BooleanOpRenderer.swift`, `ContentView.swift` :
  utilisent désormais `LayerGeometry.*`.

### Changement comportemental noté

`ContentView.layerBaseFraction(_:)` retournait `0.5` pour `.text` alors
que le rendu utilise `0.6`. **Unifié sur `0.6`** : le lasso accroche les
texts sur leur vraie bbox de rendu.

---

## La suite

### Étape 3 — Resize handles au doigt (feature directe)

C'est le prochain gros chantier "feature" maintenant que le refactor
modèle est en place.

- Pour le layer sélectionné, **overlay au-dessus du canvas** avec des
  handles (4 coins + 4 milieux + 1 handle rotation au-dessus).
- Chaque handle = sa propre `View` avec sa propre `DragGesture` (évite
  de toucher au gesture composé du canvas).
- Positionner les handles sur la bbox normalisée du layer ⇒
  `CanvasSnapping.layerNormalizedBounds(layer)` (déjà disponible),
  conversion en points écran via `side`.
- Le handle de coin NW agit sur `layer.scale` ET `layer.offset` pour
  garder le coin opposé fixe. Math : nouveau scale =
  `dist(NW, SE) / dist_initial`, nouveau offset = mid(NW, SE).
- Handles de milieu = scale uniforme (ou non-uniforme si tu introduis
  `scaleX`/`scaleY` distincts — décision à prendre).
- Si scale non-uniforme : **Option A** ajouter `scaleY: Double` aliasé sur
  `scaleValue` (rapide, ajoute du Codable). **Option B** garder isotrope
  au MVP, étendre plus tard.

Fichier à créer : `IconAtelier/Editor/SelectionHandles.swift`, greffé
en overlay sur `IconCanvasView.squircleIcon(side:)` quand
`session.selectedLayerUUID != nil`.

À garder en tête :
- Hit-test du handle a priorité (`.highPriorityGesture`).
- Les handles tournent avec le layer : positionner local-puis-rotate.
- Snap des handles : appliquer `CanvasSnapping.snappedToLayerGuides`
  sur la nouvelle bbox.

### Étape 6 — Ajouter de nouveaux effets

Le pipeline `LayerEffect` est en place ; ajouter un effet =
**1 case enum + 1 panneau editor + 1 branch dans `applying(effects:...)`**.

Liste candidate (voir aussi `references/design-polish.md` HIG) :
- `case innerShadow(InnerShadow)` — ombre intérieure (technique :
  `mask` + inverse shadow).
- `case glow(Glow)` — variante shadow avec offset=0 et couleur claire.
- `case blur(radius: Double)` — c'est exactement ce qui avait été fait
  dans `cca63b6` puis annulé. Pattern de ref : `BlurPanelContent`,
  `blurRadius` bridge sur `Layer`, branch `.blur` dans le rendu.
- `case stroke(Stroke)` — bord post-rendu (différent de
  `LayerBorder` qui est intégré au shape).
- `case colorOverlay(Paint)` — superpose une couleur/gradient,
  pratique pour le tint dynamique.

Décision en suspens : **discriminator Codable**. L'enum à 1 case marche
en synthèse, mais à 5+ cases avec payloads différents, prévoir un
`type:` key explicite (cf. skill `swift-codable` § Heterogeneous arrays)
pour la robustesse au renommage.

### Étape 7 — Nettoyage structurel (prochain chantier décidé)

Décidé en session 2026-05-20 : faire ce nettoyage **avant** les étapes
3 (handles) et 6 (effets). Découper `ContentView` rend la suite plus
agréable à lire, unifier le rendu rend les nouveaux effets cohérents
écran/export du premier coup.

Ordre recommandé : **7.1 → 7.2 → 7.3 → (7.4 si besoin)**.

#### 7.1 — Découper `ContentView` (608 l.) ✅ — fait

Réalisé : `ContentView` 608 → 435 lignes. Voir résumé de l'étape 7.1
plus haut. `AIFlowController` et `LassoController` créés en
`@Observable @MainActor`, injectés en `@State`.

#### 7.2 — Unifier le rendu (3 chemins → 1)

Aujourd'hui trois chemins de rendu ont divergé :
- `LayerContentView` (écran, dans `Editor/LayerContentView.swift`)
- `LayerForBooleanRender` (booléennes, dans `BooleanOpRenderer.swift`)
- `IconRenderer.render` (thumbnail + export, dans `ProjectPersistence.swift`)

Plan : un seul `LayerView: View` consommé par les 3 contextes, paramétré
par ce qui diffère (background, application des effects, etc.).
Suppression de `LayerForBooleanRender`.

**Effort** : ~1 j. **Risque** : moyen — comparer pixel-à-pixel les
sorties avant/après sur les 3 cas (icône écran, masque booléen, export
PNG). **Gain** : ajouter un effet ou un type de layer = 1 seul chemin
à toucher. Les bugs « ça marche à l'écran mais pas à l'export »
disparaissent.

#### 7.3 — Sortir SwiftUI de `ShapeSpec`

`ShapeSpec` importe SwiftUI pour `anyShape()`. Extraire
`ShapeRenderer.path(for: ShapeSpec, in: CGRect) -> Path` côté Editor
rend `ShapeSpec` pure data : testable dans un Playground, sérialisable
proprement.

**Effort** : ~½ j. **Risque** : faible. **Gain** : modeste tant qu'il
n'y a pas de tests unitaires, mais débloque l'écriture de tests sur les
formes (utile si tu prototypes de nouvelles formes paramétriques).

#### 7.4 — Asset store séparé pour les PNG — *à faire seulement si la perf devient un problème*

Aujourd'hui chaque `ImageContent` porte ses bytes PNG dans le JSON, et
`imagePNGDirty` existe pour éviter le re-decoding. Avec
`AssetStore.save(uuid → Data)` + `Layer` qui porte un `AssetID`, le
JSON reste léger et le re-decoding disparaît.

**Effort** : ~1 j. **Risque** : casse la persistance encore une fois +
migration de fichiers à prévoir. **Gain** : perf au load des gros
projets — pas pertinent au volume actuel. **Recommandation** : skipper
tant que ce n'est pas un goulet.

---

## Décisions actées (récap)

- [x] Scale isotrope (4a). Non-uniforme reportée à plus tard.
- [x] `IconProject` reste `@Observable final class` (4a).
- [x] Compat JSON cassée par paliers (4b puis 5). Plus de plumbing
      hybride ; les vieux projets locaux doivent être supprimés.
- [x] Bridges sur `Layer` conservés plutôt que migration franche des
      ~80 call sites.
- [ ] Discriminator Codable explicite sur `LayerEffect` quand l'enum
      grossira (cf. étape 6).

---

## Comment reprendre

1. Lire ce fichier (`NEXT_STEPS.md`).
2. Lire `CLAUDE.md` (consignes projet : skills d'abord, UI anglaise, etc.).
3. **Étape 7.2 (unifier le rendu) — prochain chantier** : créer un `LayerView: View`
   commun, faire converger `LayerContentView`, `LayerForBooleanRender`,
   `IconRenderer.render` dessus. Vérifier pixel-à-pixel les 3 sorties.
4. **Étape 3 (handles)** : créer
   `IconAtelier/Editor/SelectionHandles.swift`, greffé en overlay sur
   `IconCanvasView.squircleIcon`. Utiliser
   `CanvasSnapping.layerNormalizedBounds` et `LayerGeometry` déjà en place.
5. **Étape 6 (effets)** : ajouter un case à `LayerEffect`, un
   `XxxPanelContent` dans `EffectPanels.swift`, son wiring dans
   `LayerEditorContent`, et une branch dans
   `View.applying(effects:side:scale:)`. Modèle de référence pour
   ré-ajouter le blur : commit `cca63b6` (annulé en `f216a43`).

---

## Build & install (rappel)

```bash
xcodebuild -project IconAtelier.xcodeproj -scheme IconAtelier \
  -destination 'generic/platform=iOS' -configuration Debug build
# install sur iPhone 15 Pro (device ID 00008130-000479320AA2001C) :
xcrun devicectl …
```

⚠️ SourceKit peut afficher des faux positifs (« No such module 'UIKit' »,
« Cannot find type 'Layer' »). Ce sont des artefacts d'indexation —
le build réel passe.
