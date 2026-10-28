---
version: alpha
name: Sipli
description: A calm, bottle-led hydration tracker with editorial headings and native iOS controls.
colors:
  primary: '#2B6BFF'
  background: '#F4F1EA'
  ink: '#0A1A2F'
typography:
  sans:
    fontFamily: SF Pro
  mono:
    fontFamily: SF Mono
rounded:
  card: 20px
  control: 9999px
spacing:
  page-inset: 16px
  onboarding-inset: 24px
components:
  button: {}
  card: {}
  dialog: {}
---

# Sipli design context

The existing identity comes from `WaterQuest/Components/Theme.swift`,
`WaterQuest/Views/Onboarding/Components/OnboardingPalette.swift`, and
`docs/superpowers/specs/2026-07-06-sipli-v5-design.md`. Runtime tokens remain
canonical; this file records their intent rather than generating a second theme.

## Product and visual direction

Sipli helps people log a drink quickly and build a habit without guilt. The
persistent water bottle is the expressive element; forms, navigation, purchases,
and corrections use familiar native iOS patterns. Existing English copy and
system-formatted dates, quantities, and StoreKit prices remain in place. No new
market, pricing, permissions, or subscription policies are introduced.

Headings use the editorial type helpers in Theme. Body copy uses system type;
numeric changes use `numericText` where useful. Light mode uses paper and navy;
dark mode uses the same semantic tokens with slate surfaces and pale text.
Preserve existing cards, SF Symbols, bottle artwork, and supportive language.

Coach, insight and feedback copy speaks to the person using Sipli. Omit implementation/provenance labels such as “live log”, “built-in encouragement” and “on-device AI” from these ordinary views. Keep useful intake/progress facts and encouragement; fallback content must not be labelled AI-generated. Privacy/legal disclosures and required Weather attribution remain visible in their appropriate places.

## Layout

`FoldResolver`, `FoldAwareSplit`, and `avoidingFold()` own responsive geometry.
Active fold regions take priority over landscape width caps. Two-column screens
place content on either side of the fold. In landscape, Home, Insights, Diary, and Settings keep their columns inside
one shared page scroll, so both sides move together. FoldPaneScroll contributes
content without nesting vertical scroll views in this mode. Insights uses
shared scrolling for its other column layouts too; horizontal folds use its single-page
layout rather than separate upper/lower scroll regions. Settings fills both usable panes: profile, appearance, and daily goal on the
first side; schedule, reminders, permissions, and about on the second. Each
side has bottom clearance. In landscape, both sides share the page scroll. Portrait Settings, including a horizontal fold, uses one continuous scroll
with all sections in their existing order. Wide landscape keeps two columns.
Single-column
forms use the larger available pane on either fold axis, capped at 620 points.
Do not scale interactive calendars to tiny touch targets just to fit a short pane.

Onboarding keeps its primary action reachable and lets longer content scroll.
Decorative bottles and dials resize to available space; text and controls reflow.
A selected state must not change a control's padding or move its text.
The onboarding bottle fills its pane with breathing room around the cap and
base. Home allocates the bottle the remaining height beneath its summary text;
increasing bottle presence must never push its base below the visible pane.
At 560pt of available Home summary width, use balanced columns: a larger bottle
on the left, hydration details and vertically stacked streak/badge controls on
the right. Narrow summaries keep their existing arrangement. The same summary
component owns this behavior in folded and fully open modes.
In wide landscape, Home also uses two page columns regardless of size class:
summary on the left, quests and log on the right. Regular-width Duo windows
must not fall back to a full-width summary that hides the other cards.
In split onboarding, the first pane groups the question with the bottle. The
second pane owns answer controls, live response, helper instructions, and the
primary action. A shared question component supplies the same copy in the
single-pane layout; never repeat the heading in both panes. On tabletop the
weight ruler adapts to the answer pane so its unit selector remains reachable.
When the question pane is wide, use two columns inside it: bottle on the left,
question on the right. Narrow question panes stack the heading above the bottle.
Answer content also uses two columns when each can remain readable: amount
beside target settings, dial beside time values, preview beside reminder
choices, and input beside response. The custom answer Layout reflows the same
view instances so text-field focus and selection state survive width changes.

## Motion and interaction

Motion should acknowledge an action, never delay it: 160 ms press feedback,
240 ms tab arrival with a six-point rise, short fades, existing Theme springs,
and native navigation/sheet transitions. Preserve navigation stacks and scroll
positions. Reduce Motion removes added translation, scaling, delayed entrances,
and rotating preview messages. Basic logging and data correction remain free.

Use native Button semantics for press cancellation; do not layer a zero-distance
DragGesture over a button. Capture the saved entry for confirmation and disable
logging immediately after a successful commit to prevent duplicate taps.
Use automatic iOS toolbar styling for the add-drink action and a native sheet
for logging. Log Intake uses one content-fitted native detent for its compact columns, a drag handle,
and sheet adaptation in compact landscape. Its save action stays in a bottom
safe-area inset while fields scroll above it. The native sheet owns its
viewport; do not apply whole-screen fold avoidance inside it. At 420pt sheet
width, default-sized text uses compact amount and beverage columns, with one
shared quick-log row beneath them. Narrow
sheets or larger Dynamic Type use the native stacked Form with medium/large detents.
The compact sheet measures its natural content and save footer, reserves navigation
clearance, and cannot expand into empty space; native sizing caps it on short displays. Presets keep
44pt touch targets and remain visible at the initial detent. Present achievement celebrations modally after logging dismisses,
so native navigation chrome cannot intercept the celebration's controls.

## Canonical UI map

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
| --- | --- | --- | --- | --- |
| Navigation | MainTabView, NavigationStack | MainTabView.swift | Four persistent tabs, native sheets | DuoLayoutTests |
| Date | Native DatePicker | DiaryView.swift, SettingsView.swift | Graphical calendar, native time popup | Simulator captures |
| Select/Listbox | Native Picker and Toggle | SettingsView.swift | System popup geometry and locale | Simulator flows |
| Form | Native Form/ScrollView, avoidingFold | FoldLayout.swift | Two-pane screen or one scrollable usable pane | DuoLayoutTests |
| Onboarding panes | OnboardingView, OnboardingAnswerLayout | OnboardingStep.swift | Bottle/question pane plus adaptive answer columns | All-step Duo captures |
| Toast | AddIntakeView SavedBanner | AddIntakeView.swift | Immutable successful log confirmation | BottleFlowTests |
| CRUD | EntryEditorSheet, HydrationStore | v5 design spec, DashboardView.swift | Free edit/delete, destructive confirmation | BottleFlowTests |
| Button | SipliCTA, PrimaryButtonStyle, SipliPressStyle | Theme.swift, SipliCTA.swift | Wrapping primary label, Reduce Motion | Onboarding flow |
| Premium plans | PaywallPresenter, SubscriptionManager | RootView.swift, SubscriptionManager.swift | Sheet-local presentation, StoreKit data | Paywall captures; no purchases |

## Verification

XCTest interaction assertions and inspected simulator captures are the runtime
evidence. Screenshot names include pose, orientation, and screen. DEBUG simulated
fold bands test layout resolution; Device Hub controls test native open/partial/
closed display changes separately. Passing screenshots cannot prove universal
accessibility or the absence of every possible UI bug. See the dated QA report
for exact coverage and remaining platform boundaries.

## Share exports

`ShareCardRenderer` and `ShareCardView` own daily, weekly and achievement PNG exports. The normal export is a 360 × 450 point poster at 3× (1080 × 1350 pixels). The content canvas owns its size; backgrounds and off-canvas decoration are paint and must not contribute intrinsic layout width. Keep text and branding at least 28 points inside the canvas. Fixed poster typography is independent of the sender’s Dynamic Type setting; the app’s interactive UI continues to follow accessibility settings.

Achievement keepsakes use the same glass bottle and liquid geometry as Home, SF Serif display type, a quiet Sipli wordmark and the catalog’s actual title/detail. Artwork uses category colors from Theme and each achievement’s symbol. Spooky badges retain the established potion/pumpkin palette, bats, moon and pumpkin shapes from SpookySeason; their identity follows the earned badge, not today’s event switch. No new raster assets or character faces are introduced. Catalog cards stay 4:5 in light and dark. Long localized copy first reduces poster type/art proportionately; unusually long copy expands the export height rather than truncating content. DateFormatter follows the render locale, calendar and timezone. Native SharePreview uses the actual rendered PNG.

Token path: Theme and SpookySeason.Palette remain canonical → shared poster/artwork → ImageRenderer export. `StaticBottleArtwork` reuses BottleWaterCanvas and the existing bottle asset without sensors or animation. Verification combines native PNG render/OCR margin tests, catalog light/dark coverage, long text/locale cases and the native iOS share-sheet flow. Achievement eligibility and persisted awards are separate and unchanged.

Design metadata uses CSS `px` lengths for schema compatibility; these document equivalent UIKit logical points, not image pixels. `rounded.control: 9999px` denotes the existing native Capsule shape. Runtime Theme and native geometry remain canonical; no app spacing or corner styling changed in this metadata cleanup.
