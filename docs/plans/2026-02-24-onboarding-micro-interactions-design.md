# Onboarding Micro-Interactions Design

## Problem
The onboarding screens feel too plain and static compared to the rest of the app (dashboard with liquid animations, glass cards, rich visual depth). Only the welcome step has staggered entrance animations.

## Approach
Enhance the existing onboarding structure with richer micro-interactions, themed per-step icon animations, a water drop progress indicator, staggered content entrances on all pages, and selection feedback.

## Design

### 1. Water Drop Step Progress Indicator
- Horizontal row of 7 water drops at top of onboarding view
- Completed steps: filled drops with splash micro-animation on transition
- Current step: gentle pulse animation
- Future steps: outlined/dimmed
- Fill animates with spring when advancing

### 2. Per-Step Themed Icon Animations
| Step | Icon | Animation |
|------|------|-----------|
| Name | person.wave.2.fill | Wiggle rotation +/-8deg, 1.8s loop |
| Weight | scalemass.fill | Tilt left-right +/-12deg, 2s loop |
| Activity | figure.run | Vertical bounce 3px, 0.8s loop |
| Goal | target | Slow 360deg rotation 8s + expanding pulse rings |
| Schedule | sun.and.horizon.fill | Rising arc motion + glow intensify |
| Reminders | bell.and.waves.left.and.right.fill | Sway +/-15deg, 2.5s |

### 3. Staggered Content Entrance on All Pages
- Icon: scale 0.6->1.0 + opacity, delay 0.1s
- Title: slide up 20pt + opacity, delay 0.3s
- Subtitle: slide up 15pt + opacity, delay 0.45s
- Card content: slide up 20pt + opacity, delay 0.6s
- Animations replay when navigating to each step

### 4. Selection Micro-Interactions
- Activity buttons: scale spring (1.03x) on select, checkmark transition(.scale + .opacity), haptic feedback
- Sliders: numericText content transitions (already present)
- Toggles: haptic feedback on change, conditional content uses move+opacity transition

### 5. Page Transition Polish
- matchedGeometryEffect for Continue->Start button morph
- Spring-based page transitions (already present, keep)

### 6. Navigation Bar Enhancements
- Step indicator text "3 of 7" with numericText transition
- Continue button shimmer/gradient animation on final "Start" step
- Back button animated fade in/out
