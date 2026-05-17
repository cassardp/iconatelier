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

## TODO technique

Voir `TODO.md` à la racine.
