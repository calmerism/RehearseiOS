---
name: Alabaster Precision
colors:
  surface: '#fbf8ff'
  surface-dim: '#dad9e3'
  surface-bright: '#fbf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f2fd'
  surface-container: '#eeedf7'
  surface-container-high: '#e8e7f1'
  surface-container-highest: '#e3e1ec'
  on-surface: '#1a1b22'
  on-surface-variant: '#5a4138'
  inverse-surface: '#2f3038'
  inverse-on-surface: '#f1effa'
  outline: '#8e7166'
  outline-variant: '#e2bfb2'
  surface-tint: '#a73a00'
  primary: '#a33900'
  on-primary: '#ffffff'
  primary-container: '#cc4900'
  on-primary-container: '#fffbff'
  inverse-primary: '#ffb599'
  secondary: '#5f5e60'
  on-secondary: '#ffffff'
  secondary-container: '#e5e1e4'
  on-secondary-container: '#656466'
  tertiary: '#005da8'
  on-tertiary: '#ffffff'
  tertiary-container: '#0076d2'
  on-tertiary-container: '#fdfcff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbce'
  primary-fixed-dim: '#ffb599'
  on-primary-fixed: '#370e00'
  on-primary-fixed-variant: '#7f2b00'
  secondary-fixed: '#e5e1e4'
  secondary-fixed-dim: '#c8c6c8'
  on-secondary-fixed: '#1c1b1d'
  on-secondary-fixed-variant: '#474649'
  tertiary-fixed: '#d4e3ff'
  tertiary-fixed-dim: '#a4c9ff'
  on-tertiary-fixed: '#001c39'
  on-tertiary-fixed-variant: '#004883'
  background: '#fbf8ff'
  on-background: '#1a1b22'
  surface-variant: '#e3e1ec'
typography:
  display:
    fontFamily: Geist
    fontSize: 3.5rem
    fontWeight: '600'
    lineHeight: '1.1'
    letterSpacing: -0.035em
  headline-xl:
    fontFamily: Geist
    fontSize: 2.25rem
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: -0.025em
  headline-xl-mobile:
    fontFamily: Geist
    fontSize: 1.75rem
    fontWeight: '600'
    lineHeight: '1.25'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Geist
    fontSize: 1.5rem
    fontWeight: '600'
    lineHeight: '1.3'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Geist
    fontSize: 1.25rem
    fontWeight: '500'
    lineHeight: '1.4'
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Geist
    fontSize: 1rem
    fontWeight: '500'
    lineHeight: '1.4'
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Geist
    fontSize: 1.125rem
    fontWeight: '400'
    lineHeight: '1.6'
    letterSpacing: -0.01em
  body-md:
    fontFamily: Geist
    fontSize: 0.9375rem
    fontWeight: '400'
    lineHeight: '1.55'
    letterSpacing: -0.005em
  body-sm:
    fontFamily: Geist
    fontSize: 0.8125rem
    fontWeight: '400'
    lineHeight: '1.5'
    letterSpacing: 0em
  label-md:
    fontFamily: Geist
    fontSize: 0.8125rem
    fontWeight: '500'
    lineHeight: '1'
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Geist
    fontSize: 0.6875rem
    fontWeight: '600'
    lineHeight: '1'
    letterSpacing: 0.05em
  code-md:
    fontFamily: JetBrains Mono
    fontSize: 0.875rem
    fontWeight: '400'
    lineHeight: '1.6'
    letterSpacing: -0.01em
  code-sm:
    fontFamily: JetBrains Mono
    fontSize: 0.75rem
    fontWeight: '400'
    lineHeight: '1.5'
    letterSpacing: 0em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  space-3xs: 0.125rem
  space-2xs: 0.25rem
  space-xs: 0.5rem
  space-sm: 0.75rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
  space-2xl: 3rem
  space-3xl: 4rem
  gutter-mobile: 1rem
  gutter-desktop: 1.5rem
  sidebar-width: 16rem
  terminal-min-height: 14rem
---

## Brand & Style

This design system serves as the disciplined, light-mode counterpart for an elite AI technical interview preparation platform. It conveys the quiet confidence, high-stakes clarity, and clinical exactitude of senior engineering assessments.

The design philosophy combines Swiss modernism with developer-grade technical tooling:
- **Personality:** Authoritative, razor-sharp, distraction-free, and analytically calm.
- **Aesthetic Movement:** High-density technical minimalism. It avoids whimsical decorations, skeuomorphic noise, emojis, and playful microcopy in favor of functional precision, structural clarity, and deliberate typographic pacing.
- **Emotional Response:** Empowers the candidate with mental focus and an uncompromising sense of professional competence.

## Colors

The palette is engineered for prolonged sessions of cognitive concentration, pairing high-contrast structural monochrome with an energetic safety-orange focal accelerator.

### Color Tokens & Roles
- **Primary Accent (`#ea580c`):** Vibrant safety orange. Reserved strictly for primary intent actions, critical indicators, real-time audio/recording telemetry, and active states. Never used as large background fills or decorative washes.
- **Secondary (`#09090b`):** Deep charcoal ink. Used for high-emphasis typography, primary interface icons, terminal-level structural elements, and solid contrasting controls.
- **Neutral (`#71717a`):** Muted zinc slate. Governs secondary annotations, parameter metadata, placeholder values, deactivated elements, and passive icons.

### Surface Tiers & Boundaries
- **Base Canvas (`#ffffff`):** Pure unblemished white ground layer across main editorial viewports, document readers, and coding canvases.
- **Surface Level 1 (`#fafafa`):** Soft foundational offset used for sidebars, structural cards, and inactive panes.
- **Surface Level 2 (`#f4f4f5`):** Crisp recessed zinc surface for input wells, data table headers, code blocks, and metrics modules.
- **Border Subtle (`#e4e4e7`):** Hairline interface separators, grid divisions, and passive container bounds.
- **Border Strong (`#d4d4d8`):** Interactive element perimeters, hovered surfaces, and focused viewport splits.

### Semantic Status Colors
- **Success (`#15803d` / `#f0fdf4`):** Test cases passed, valid syntax, operational confirmation.
- **Warning (`#b45309` / `#fffbeb`):** Non-fatal algorithmic complexity alerts, latency warnings.
- **Critical / Failure (`#b91c1c` / `#fef2f2`):** Syntax exceptions, failing test runs, session disconnection.

## Typography

The typographic engine pairs Geist for all administrative, conversational, and analytical UI text with JetBrains Mono for execution environments, system metrics, and variable breakdowns.

### Hierarchy & Style Rules
- **Numerical Formatting:** All numeric indicators, timers, telemetry metrics, and test output columns utilize tabular lining figures (`font-feature-settings: "tnum" on, "cv05" on`) to maintain strict vertical alignment across continuous data streams.
- **Headlines:** Display and XL titles enforce negative tracking to maintain tight, editorial density without feeling cramped.
- **Labels:** Small labels (`label-sm`) default to uppercase tracking with `letterSpacing: 0.05em` when denoting system tags, run states, or protocol breadcrumbs.

## Layout & Spacing

The layout is built upon an uncompromising, rigid 4px base module, scaling up to an 8px grid for layout compositions. Spatial distribution favors generous breathing room surrounding dense, structured information blocks.

### Viewport Structures
- **Workspace Layout (Split-Pane Engine):** Standard interview screen utilizes a horizontal multi-column division consisting of a collapsible 256px contextual sidebar, a flexible AI interviewer transcript viewport (minimum 380px), and an interactive code editor/workspace viewport (flex-1).
- **Responsive Adaptation:**
  - **Desktop (>= 1280px):** Simultaneous three-pane layout with persistent real-time diagnostic bar.
  - **Tablet (768px - 1279px):** Split-view with transcript and coding workspace toggleable via tabbed segmented controls. Sidebar condenses to an icon-rail.
  - **Mobile (< 768px):** Single-pane sequential workflow. Full-bleed editor view with bottom-sheet access to AI interviewer dialogue and runtime execution output.

## Elevation & Depth

This system intentionally eliminates traditional heavy drop shadows and blurred colorful ambient lights. Depth is conveyed strictly through tonal stepping, structural wire-borders, and tactile hair-thin inner edges.

### Layer Hierarchy
- **Level 0 (Floor Canvas):** Pure white `#ffffff`. Backing surface for raw code and conversation streams.
- **Level 1 (Panels & Cards):** `#fafafa` bounded by a 1px solid `#e4e4e7` border. Provides structural isolation for question prompts, context documents, and analytical report sections.
- **Level 2 (Active Wells & Popovers):** `#ffffff` layered over recessed `#f4f4f5` regions, utilizing an ultra-subtle grounding shadow: `0 1px 2px 0 rgba(9, 9, 11, 0.04), 0 0 0 1px #d4d4d8`.
- **Modals & Overlays:** `#ffffff` surface with a clean, low-diffusion ambient boundary: `0 12px 32px -4px rgba(9, 9, 11, 0.08), 0 0 0 1px #d4d4d8`. Backdrop uses an ultra-subtle wash: `rgba(244, 244, 245, 0.8)` with a 4px blur.

## Shapes

The geometry adheres strictly to subtle, micro-rounded corners. Massive pill radii, organic blobs, and circular buttons are forbidden outside of avatar shapes.

### Corner Radii Definitions
- **Structural Containers (Panels, Drawers, Code Windows):** 6px (`0.375rem`).
- **Interactive Form Controls (Buttons, Inputs, Selectors):** 4px (`0.25rem`).
- **Data Badges & Status Chips:** 4px (`0.25rem`).
- **Inline Code Blocks:** 3px (`0.1875rem`).

## Components

### Buttons
- **Primary CTA:** Background `#ea580c`, label `#ffffff`, 4px radius, 0.5px subtle border `#c2410c`. Hover state transitions to `#c2410c`. Focus ring features an offset 2px `#ea580c` highlight.
- **Secondary Action:** Background `#ffffff`, label `#09090b`, 1px border `#d4d4d8`. Hover state applies `#f4f4f5`.
- **Tertiary / Ghost:** Background transparent, label `#71717a`. Hover state applies `#f4f4f5` with text `#09090b`.
- **Sizing:** Fixed height tiers of 32px (compact workspace action) and 40px (standard modal/form action) with horizontal padding of 12px and 16px respectively.

### Input Fields & Controls
- **Text Inputs:** Solid `#ffffff` fill, 1px border `#d4d4d8`, height 36px, typography `body-md`. Focus state transitions border to `#09090b` with no fuzzy outer rings.
- **Checkboxes & Radios:** 16px square/circle, 1px border `#d4d4d8`. Selected state fills `#09090b` with pure white check glyph.

### Status Chips & Badges
- Compact indicators (20px height) using uppercase `label-sm`.
- **Active / Interview In Progress:** Background `#fff7ed`, text `#ea580c`, 1px border `#ffedd5`. Includes a 6px pulsing safety-orange indicator dot.
- **Neutral Metric:** Background `#f4f4f5`, text `#09090b`, 1px border `#e4e4e7`.

### Cards & Code Execution Panels
- **Problem Statement Card:** Crisp white `#ffffff` body, enclosed in 1px `#e4e4e7` border. Header strip utilizes `#f4f4f5` with 8px vertical padding, separating meta properties (difficulty, runtime limits, category) via mono labels.
- **Console / Terminal Strip:** Recessed `#f4f4f5` container, JetBrains Mono font, 1px top border `#e4e4e7`. Output lines render `#71717a` for info, `#09090b` for standard output, and `#b91c1c` for stack traces.

### Audio & AI Telemetry Waveform
- Live voice activity representation consists of a series of 2px wide vertical bars with 2px gaps.
- Inactive bars render `#e4e4e7`; active AI/Candidate speech dynamically illuminates bars in `#ea580c`.