# IconAtelier — TODO

## À faire

- Export `AppIcon.appiconset` / `.icon` (toutes tailles iOS + light/dark/tinted + format Icon Composer iOS 26).
- Migration `Secrets.swift` → Keychain + écran Settings (prérequis App Store).
- Bibliothèque de backgrounds procéduraux (grid, dots, stripes, hex, halftone, noise…) avec params éditables.

## Idées à étudier

- Galerie en ligne communautaire (CF Workers + D1 + R2, modération App Store 1.2).
- Variantes en 1 clic (relancer même prompt en parallèle, grille de comparaison).
- Édition de zone (inpainting via `images.edit`).
- Effets par calque (drop shadow, glow, tint).
- Toggle preview avec/sans masque iOS (squircle ratio 0.2237, `style: .continuous`).
- Picker de palettes (Material, Tailwind, HIG).
- Formats supplémentaires (Watch, Mac, visionOS, tvOS, Mac Catalyst).

## Spin-off potentiel — AI iMessage Stickers

App séparée, pas dans IconAtelier. Trou de marché : la concurrence fait
seulement du découpage de photos, personne ne génère from scratch.
Différenciants : génération from prompt, pack visuellement cohérent (12
stickers même style), édition puffy/outline Apple-style, templates Mad Libs.

Contraintes techniques : `MSStickerBrowserViewController` alimenté
dynamiquement depuis App Group (validé en prod chez concurrents). Impossible
de pousser au tiroir système universel d'iOS — seul Apple le fait.
Risque WWDC 2026 : Apple peut sortir un Genmoji-stickers et tuer le segment.
