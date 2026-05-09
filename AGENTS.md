# IconLab / IconAtelier — Instructions projet

## Règle absolue : utiliser les skills AVANT de coder

À chaque tâche d'implémentation, de revue ou de design technique sur ce projet,
**je dois invoquer les skills pertinents AVANT d'écrire la moindre ligne de code**,
pas après pour valider.

Les skills (notamment `all-ios-skills:*`) contiennent la doc à jour et les patterns
officiels Apple pour iOS 26.2. Coder « de mémoire » mène à du code sous-optimal,
à des APIs dépassées, et à louper les nouveautés (Liquid Glass, gestures iOS 26+,
@Observable patterns récents, etc.).

### Procédure obligatoire

1. **Identifier les skills pertinents** parmi ceux disponibles avant de commencer.
2. **Invoquer chaque skill** via l'outil `Skill` pour charger les bonnes pratiques
   dans le contexte.
3. **Seulement ensuite** écrire le code, en s'appuyant sur ce que les skills ont
   apporté.
4. Si plusieurs domaines sont touchés (layout, gestures, animation, persistance…),
   invoquer **plusieurs** skills, pas juste un.

### Skills typiquement pertinents pour ce projet

- `all-ios-skills:swiftui-patterns` — `@Observable`, ownership, composition MV
- `all-ios-skills:swiftui-layout-components` — stacks, sheets, panneaux flottants
- `all-ios-skills:swiftui-gestures` — drag/magnify/rotate, composition, conflits
- `all-ios-skills:swiftui-animation` — transitions, springs, matchedGeometry
- `all-ios-skills:swiftui-navigation` — sheets, NavigationStack, bottom sheets
- `all-ios-skills:swiftdata` — quand on branchera la persistance des projets
- `all-ios-skills:ios-networking` — pour l'appel à l'API OpenAI (URLSession + async/await)
- `all-ios-skills:swift-concurrency` — Task, MainActor, isolation
- `all-ios-skills:swift-language` — patterns Swift modernes
- `all-ios-skills:photokit` — si on ajoute la sauvegarde dans Photos
- `all-ios-skills:app-store-review` — avant soumission (BYOK + 4.2 minimum functionality)
- `all-ios-skills:storekit` — quand on implémentera le one-shot payment
- `all-ios-skills:tipkit` — pour les tips d'onboarding éventuels

⚠️ `all-ios-skills:swiftui-liquid-glass` n'est **pas** pertinent ici : Liquid
Glass nécessite iOS 26+ et la cible est iOS 18. Utiliser `.regularMaterial`,
`.thinMaterial`, etc. à la place.

### Anti-pattern interdit

❌ Coder d'abord, invoquer les skills après pour « vérifier ».
❌ Se dire « je connais SwiftUI, pas besoin du skill ».
✅ Skill d'abord, code ensuite. Toujours.

## Cible technique

- **iOS 18 minimum** (mesh gradients, `MagnifyGesture`, `RotateGesture`,
  `@Observable`/`@Bindable`, `ScrollPosition`, `.scrollTargetBehavior`, etc.)
- ❌ **Pas** de Liquid Glass / `.glassEffect` (iOS 26+ uniquement) → utiliser
  `.regularMaterial`, `.thinMaterial`, `.ultraThinMaterial`
- ⚠️ Le Xcode project a actuellement `IPHONEOS_DEPLOYMENT_TARGET=26.2`. À baisser
  à `18.0` dans les build settings avant de coder.
- SwiftUI + `@Observable`
- Architecture MV (pas MVVM)
- BYOK via `Secrets.swift` aujourd'hui, à migrer vers Keychain + écran Settings

## Roadmap & vision

Voir `~/Desktop/IconLab_roadmap.md` pour la vision produit, le positionnement
(BYOK, devs iOS indé), et la priorisation (fonds natifs → export appiconset → calques N).

## Build / test

- Cible iPhone 15 Pro (`device ID 00008130-000479320AA2001C`)
- Build CLI : `xcodebuild -project IconAtelier.xcodeproj -scheme IconAtelier -destination 'generic/platform=iOS' -configuration Debug build`
- Install device : `xcrun devicectl`
