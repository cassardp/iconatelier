# IconAtelier — TODO technique

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
