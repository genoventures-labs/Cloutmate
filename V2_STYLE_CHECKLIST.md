## V2 Glassmorphic Checklist

- **Foundational systems**
  - Use `GlassColorSystem` to source `backgroundColor()`, `backgroundElevated()`, `cardColor()`, and `textPrimary()`; avoid hard-coded `Color` values except for semantic accents (`.kosmicBlue`, `.kosmicPurple`).
  - Drive gradients and highlights with `AuroraPalette.linearGradient` / `.radialGradient`; keep opacity ≤ 0.18 for overlays.
  - Apply `GlassMotion` easing helpers (`GlassMotion.Easing.spring`, `.modalOpen`, `.tabSwitch`) and respect `Duration.modulated` for Reduce Motion compatibility.

- **Layout scaffolding**
  - Wrap multi-column layouts with `V2DrawerScaffold` (or sibling scaffolds) to gain accent rails, glass header blocks, and optional sidebars.
  - Encapsulate section groupings inside `DrawerSection` for consistent padding (22 px horizontal, 18 px vertical) and icon/title typography (`.headline`, `.caption`).

- **Surface treatments**
  - Prefer `glassPanel(tier:cornerRadius:)` or `GlassPanel` for cards, drawers, and search bars; tiers (`.background`, `.sidebar`, `.contentCard`, `.overlay`, `.floatingAction`) define tint, border, and shadow levels.
  - Use 12–22 px corner radii; reserve 22 px for structural shells (sidebars/drawers), 12 px for cards.
  - Maintain 20–24 px horizontal spacing between major columns; 16–20 px vertical rhythm inside stacks.

- **Typography & controls**
  - Titles: `.system(size: 24–28, weight: .bold)` for primary headers, `.title3` or `.headline` for section labels; subtitles `.subheadline` with `.secondary` foreground.
  - Buttons: adopt `GlassButton` (role `.primary` for gradient accents, `.surface` for neutral) or minimal capsule buttons with gradients capped at 0.18 opacity glows.
  - Apply `glassHoverEffect()` or `floatLift()` on interactive cards; ensure hover scale ≤ 1.015.

- **Theming & state**
  - Respect ARTE state: blend backgrounds via `glassColorSystem.applyEmotionalModulation` and fetch accent hue with `emotionalAccent()`.
  - When showing focus/selection, reuse `drawerFocusGlow()` or mirrored stroke styles (1 px base, 1.8 px when focused).
  - Avoid drop shadows darker than 12 % opacity; prefer `glassColorSystem.emotionalShadowTone()` if additional depth is needed.

- **Compositional guidelines**
  - Replace `Divider()` + `Color.clear` backgrounds with glass surfaces (`GlassDivider`, `GlassPanel` shadows) to prevent flat seams.
  - Use ScrollView coordinate spaces with `ScrollOffsetPreferenceKey` to fade headers rather than removing them abruptly.
  - Limit timelines/charts to layered glass tracks with contextual cards; baseline lines alone should include gradient fills or motion glows to read as V2.

- **Accessibility**
  - Honor `.accessibilityReduceMotion` by disabling shimmer/aurora animations (`AuroraShimmerView`, `.auroraShimmer()`) when true.
  - Maintain readable contrast: secondary text ≥ 60 % opacity, tertiary ≥ 40 %; elevate backgrounds when contrast drops in light mode.


