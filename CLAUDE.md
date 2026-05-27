# IconAtelier — Instructions projet

## Skills d'abord

Avant toute édition SwiftUI/iOS, invoquer le ou les skills `all-ios-skills:*`
pertinents (`swiftui-patterns`, `swiftui-layout-components`, `swiftui-gestures`,
`swiftui-animation`, `swiftui-navigation`, `swiftdata`, `swift-concurrency`,
`swift-language`, `app-store-review`…). Skill d'abord, code ensuite — même
pour 3 lignes.

## Langue de l'app

UI **100 % anglaise** (labels, boutons, titres, messages, placeholders).
Communication avec l'utilisateur dans Claude Code reste en français.

## Cible technique

- iOS 18 minimum, pas de Liquid Glass
- SwiftUI + `@Observable`
- Architecture MV (pas MVVM)
- Positionnement actuel : design tool paramétrique **+** génération AI
  overlay text-to-image (`AIPromptSheet`, `AIStyle`, `OpenAIImageService`).
  Pas de drawing-to-AI, pas de photo flow, pas d'AI-background.
  (cf. memory `project-non-ai-pivot`, `project-ai-first-plan`)

## Composants natifs vs custom

Toujours privilégier les composants natifs SwiftUI/iOS. Basculer en custom
seulement si le design l'exige.

**Exception assumée : la sheet d'édition (EditSheet)** est intentionnellement
custom (`DialSliderRow`, `PanelSection`, `SectionDivider`, pas de
`NavigationStack` / `Form` / `List`). Ne pas la « renativiser » sans demande
explicite.

## Build / device

- Cible iPhone 15 Pro (`device ID 00008130-000479320AA2001C`)
- Build : `xcodebuild -project IconAtelier.xcodeproj -scheme IconAtelier -destination 'generic/platform=iOS' -configuration Debug build`
- Install : `xcrun devicectl`

## Schéma de persistance (Codable + filesystem)

Les projets sont stockés en JSON via `ProjectStore` (un `project.json` par
projet, PNG des layers à côté). Le décodage est **lenient** : un fichier qui ne
décode pas est **skippé silencieusement** → le projet disparaît de la galerie.
Tenir compte de la base déjà en prod sur les iPhones des users.

`IconProject` porte un `schemaVersion` (`currentSchemaVersion`). À bumper +
brancher dessus dans `init(from:)` uniquement pour les migrations **sémantiques**
(un champ qui change d'unité/de sens — décodage silencieusement corrompu sinon).

**Règles d'évolution du schéma :**

- ✅ **Sûr** : ajouter un champ `Optional`, ajouter un `case` d'enum, supprimer
  un champ. Pour un champ déjà dans un type à `init(from:)` défensif
  (`IconProject`, `Background`, `LayerFill`, `LayerBorder`, `ImageContent`,
  `Paint`), ajouter une ligne `decodeIfPresent ?? défaut`.
- 🔴 **Casse le décodage** (projet skippé) : ajouter un champ **non-`Optional`**
  à un type auto-synthétisé (`TextContent`, `ShapeContent`, `Layer`, etc.) ;
  renommer un champ ; renommer ou supprimer un `case` d'enum encore utilisé.
- 🟠 **Corruption silencieuse** : changer l'unité/le sens d'un champ existant →
  passer par `schemaVersion`.

**Règle par défaut : tout nouveau champ se déclare `Optional`.** Swift génère
alors `decodeIfPresent` automatiquement, aucun `init` custom requis. Ne jamais
renommer/supprimer un `case` d'enum sorti en prod (rétro **et** forward-compat
via `LibraryImport`/galerie).

## TODO technique

Voir `TODO.md` à la racine.
