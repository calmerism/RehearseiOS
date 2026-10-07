---
name: Obsidian Precision
colors:
  surface: '#131315'
  surface-dim: '#131315'
  surface-bright: '#39393b'
  surface-container-lowest: '#0e0e10'
  surface-container-low: '#1c1b1d'
  surface-container: '#201f22'
  surface-container-high: '#2a2a2c'
  surface-container-highest: '#353437'
  on-surface: '#e5e1e4'
  on-surface-variant: '#e2bfb2'
  inverse-surface: '#e5e1e4'
  inverse-on-surface: '#313032'
  outline: '#a98a7e'
  outline-variant: '#5a4138'
  surface-tint: '#ffb599'
  primary: '#ffb599'
  on-primary: '#5a1c00'
  primary-container: '#f66018'
  on-primary-container: '#4f1700'
  inverse-primary: '#a73a00'
  secondary: '#ffb690'
  on-secondary: '#552100'
  secondary-container: '#ec6a06'
  on-secondary-container: '#4a1c00'
  tertiary: '#ffb77d'
  on-tertiary: '#4d2600'
  tertiary-container: '#d97707'
  on-tertiary-container: '#432100'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdbce'
  primary-fixed-dim: '#ffb599'
  on-primary-fixed: '#370e00'
  on-primary-fixed-variant: '#7f2b00'
  secondary-fixed: '#ffdbca'
  secondary-fixed-dim: '#ffb690'
  on-secondary-fixed: '#341100'
  on-secondary-fixed-variant: '#783200'
  tertiary-fixed: '#ffdcc3'
  tertiary-fixed-dim: '#ffb77d'
  on-tertiary-fixed: '#2f1500'
  on-tertiary-fixed-variant: '#6e3900'
  background: '#131315'
  on-background: '#e5e1e4'
  surface-variant: '#353437'
typography:
  headline-xl:
    fontFamily: Geist
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 38px
    letterSpacing: -0.025em
  headline-lg:
    fontFamily: Geist
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Geist
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 24px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Geist
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: -0.01em
  body-default:
    fontFamily: Geist
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: -0.005em
  body-strong:
    fontFamily: Geist
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: -0.005em
  body-compact:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0em
  code-default:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0em
  metric-display:
    fontFamily: JetBrains Mono
    fontSize: 28px
    fontWeight: '500'
    lineHeight: 32px
    letterSpacing: -0.03em
  label-caps:
    fontFamily: JetBrains Mono
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.08em
  headline-xl-mobile:
    fontFamily: Geist
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.02em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  space-2xs: 0.125rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
  space-2xl: 2rem
  space-3xl: 3rem
  gutter-default: 0.75rem
  margin-panel: 1rem
  sidebar-width: 15rem
---

## Brand & Style

This design system establishes an architectural, high-density environment engineered for mission-critical enterprise workflows. The visual identity draws from the discipline of industrial command-line interfaces, modern developer tooling (such as Linear and Raycast), and professional terminal workspaces.

The emotional target is extreme competence, calculated precision, and cognitive calm. The interface recedes into the background to prioritize data structure, state changes, and rapid keyboard-first navigation. 

### Core Tenets
- **Instrument-Grade Restraint:** Every pixel, border, and millisecond of motion must justify its presence through functional utility. Decorative flourishes, playful illustrations, soft gradients, and arbitrary rounded blobs are explicitly forbidden.
- **Architectural Planes:** Visual hierarchy is communicated through subtle shifts in luminance across flat structural planes, locked together by 1px precision hairline borders.
- **Controlled Warmth:** A focused, high-visibility amber/copper accent is applied sparingly to denote execution, active states, key focal points, and critical notifications.

## Colors

The palette is engineered for prolonged operational focus in low-ambient enterprise workspaces. Contrast ratios conform strictly to WCAG AAA standards for high-density information displays.

### Foundations & Surfaces
- **Canvas Base (`#09090b`):** The foundational viewport background. Deepest zinc, non-reflective.
- **Surface Elevation 1 (`#121215`):** Sidebars, grouped view panels, secondary toolbars.
- **Surface Elevation 2 (`#18181b`):** Cards, floating context menus, active table rows, modal overlays.
- **Surface Elevation 3 (`#202024`):** Tooltips, nested sub-panels, hover states on interactive containers.

### Outlines & Dividers
- **Hairline Subtle (`#27272a`):** Standard structural border for all cards, cells, splitters, and headers (1px solid).
- **Hairline Focus / Hover (`#3f3f46`):** Secondary state change border for interactive elements.
- **Hairline Accent (`#ea580c`):** High-priority focus rings and terminal active states.

### Typography & Content Tokens
- **Foreground High-Contrast (`#fafafa`):** Primary headings, critical data points, active icons.
- **Foreground Muted (`#a1a1aa`):** Standard body copy, labels, primary metadata.
- **Foreground Dim (`#71717a`):** Disabled states, breadcrumb delimiters, helper hints, empty states.

### Functional Accents
- **Accent Primary (`#ea580c`):** Primary action triggers, active tabs, progress indications.
- **Accent Interactive Hover (`#f97316`):** Hover states on primary interactive elements.
- **Warning Amber (`#d97706`):** Non-blocking operational states and alerts.
- **Success Emerald (`#10b981`):** Verified deployment, test-pass confirmation (desaturated, utilitarian).
- **Destructive Crimson (`#ef4444`):** Non-recoverable deletion, compile failure, operational block.

## Typography

The typographic system is built on precision, compact line heights, and dense horizontal layouts. It relies on Geist for structural prose and interface chrome, paired with JetBrains Mono for metrics, code snippets, keyboard shortcuts, and categorized table data.

### Typographic Rules
- **Tabular Numerics:** All dynamic counters, performance telemetry, data grids, and monetary values must enforce OpenType `tnum` (tabular numbers) to prevent horizontal jitter during updates.
- **Tight Vertical Tracking:** Headings use negative letter-spacing (`-0.015em` to `-0.025em`) paired with dense leading to maintain structural cohesion within tight multi-column dashboards.
- **Micro-Labels:** Metadata categories, column sort headers, and keyboard triggers use `label-caps` set in JetBrains Mono with explicit letter spacing (`0.08em`) and uppercase transformation.

## Layout & Spacing

The layout model is predicated on an ultra-dense, multi-pane structural dock. The workspace utilizes a fluid container architecture with fixed vertical utility bars and split view panes.

### Rhythm & Alignment
- **Base Grid:** Strict 4px incremental scaling, prioritizing 8px and 12px steps for internal container padding to preserve compact density.
- **Structural Gutters:** Panes, inspector drawers, and split-code editors operate with unified 12px (`0.75rem`) internal margins and hairline boundary lines.
- **Reflow & Responsiveness:**
  - **Desktop (>= 1280px):** 3-column split view (Collapsible Navigation: 240px, Master Data Workspace: flexible, Inspector Drawer: 320px).
  - **Tablet (768px - 1279px):** Inspector drawer converts to an anchored right overlay sheet; sidebar collapses into a persistent 48px icon rail.
  - **Mobile (< 768px):** Linearized single-column view with bottom sheet utility drawers and persistent sticky top command header.

## Elevation & Depth

This design system avoids theatrical drop shadows and soft, diffuse ambient glows. Visual depth is established through tonal stacking and razor-sharp borders.

### The Tonal Stacking Principle
Depth is produced strictly through luminance hierarchy:
- Base canvases `#09090b` support nested panels at `#121215`.
- Floating inspectors and elevated cards render at `#18181b`.
- Overlaid context menus, dropdowns, and flyouts render at `#202024`.

### Hairline Boundaries
Every elevation transition must be demarcated by a 1px border (`#27272a`). Surfaces never touch without this explicit separation line.

### Overlays & Menus
For popovers, command palettes, and floating action sheets:
- Box Shadow: `0 0 0 1px #27272a, 0 8px 24px -4px rgba(0, 0, 0, 0.75)`.
- No colored shadows or ambient colored blooms are permitted.

## Shapes

The geometric vocabulary is clipped, architectural, and compact. 

### Corner Radius Standards
- **Core Interactive Elements (Inputs, Buttons, Badges):** 4px (`0.25rem` / `rounded-sm` or `rounded-md`).
- **Surface Enclosures (Cards, Modals, Panels):** 6px to 8px maximum (`0.375rem` - `0.5rem`).
- **Zero Pill Rule:** Pill-shaped (`rounded-full`) borders are strictly prohibited for buttons, tags, or search bars. Circular geometry is reserved exclusively for avatar initials and status dot indicators.

## Components

### Buttons
- **Primary:** Background `#ea580c`, foreground `#ffffff`, 1px solid `#ea580c`. Hover: `#f97316`. Active: `#c2410c`. Padding: 6px 12px. Border radius: 4px. Typographic level: `body-strong`.
- **Secondary:** Background `#18181b`, foreground `#fafafa`, 1px solid `#27272a`. Hover: Background `#202024`, border `#3f3f46`. Active: Background `#121215`.
- **Ghost / Tool:** Background transparent, foreground `#a1a1aa`, 1px solid transparent. Hover: Background `#18181b`, foreground `#fafafa`, border `#27272a`.

### Status Chips & Tags
- Rectangular geometry with 3px to 4px radius. Monospaced font (`code-default` at 11px).
- Styling: Flat dark fill (`#121215`), structural border (`1px solid #27272a`), foreground `#a1a1aa`.
- Active/Execution State: Hairline border `#ea580c` with 6px solid accent dot `#ea580c` on left margin.

### Input Fields & Search Bars
- Background: `#09090b`. Border: 1px solid `#27272a`. Color: `#fafafa`. Placeholder: `#71717a`.
- Focus State: 1px solid `#ea580c` with zero outer fuzzy glow. Optional subtle `box-shadow: 0 0 0 1px #ea580c`.
- Height: Standardized 32px height for ultra-compact operational density.

### Tables & Data Grids
- Clean structural borders: Cell borders `1px solid #27272a`.
- Header Row: Background `#121215`, text `label-caps` in `#71717a`, height 32px.
- Data Rows: Alternating hover background `#18181b`. Numeric cells right-aligned in `code-default` with `tnum`.
- Selection State: Left 2px border accent `#ea580c` with background `#18181b`.

### Checkboxes & Radios
- Size: 14px by 14px square.
- Checked: Background `#ea580c`, border `#ea580c`, white check icon.
- Unchecked: Background `#09090b`, border 1px solid `#3f3f46`.

### Cards & Container Panels
- Background: `#121215`. Border: 1px solid `#27272a`. Radius: 6px.
- Card Header: Discrete 1px border-bottom (`#27272a`), 8px vertical padding, 12px horizontal padding.
- Card Body: 12px or 16px internal padding.

### Command Palette (K-Bar)
- Modal frame locked at 640px width.
- Canvas: `#121215` with a 1px border `#3f3f46`.
- Direct search bar input pinned to top, 40px height, without borders, separated by bottom border `#27272a`.
- Active row: `#18181b` with right-aligned JetBrains Mono keyboard shortcuts in muted zinc `#71717a`.