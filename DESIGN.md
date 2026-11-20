---
name: Sonico
description: A native macOS listening controller with a device-aware 3D portrait.
colors:
  background: '#1D1F22'
  surface: '#313439'
  surface-high: '#3D4146'
  outline: '#838A94'
  primary: '#DADEEB'
  on-primary: '#14191F'
  text: '#F6F7F8'
  secondary: '#CCD0D6'
  header: '#DDE0E2'
  on-header: '#171E23'
  error: '#FFB8B0'
typography:
  device-name:
    fontFamily: 'SF Pro'
    fontSize: '31px'
    fontWeight: 600
rounded:
  card: '20px'
  pill: '999px'
spacing:
  group-gap: '12px'
  card-inset: '18px'
  page-inset: '20px'
components:
  control-card:
    backgroundColor: '{colors.surface}'
    textColor: '{colors.text}'
    rounded: '{rounded.card}'
    padding: '{spacing.card-inset}'
  primary-action:
    backgroundColor: '{colors.primary}'
    textColor: '{colors.on-primary}'
    rounded: '{rounded.pill}'
---

# Design System: Sonico

## Overview

The product front-loads **device identity**, then makes the most common listening changes reachable in one scroll. The user’s Sound Connect references inform the layout, not the assets. The design applies Material 3 tonal hierarchy and restrained expressive motion through SwiftUI, AppKit, and RealityKit.

## Colors

The front matter gives representative dark-mode tokens. `FinishPalette.swift` is authoritative: light and dark roles mix the MDR-reported shell into the canvas, cards, selection, and studio backdrop. Increase Contrast strengthens guide rules and secondary text. Text and controls do not rely on color alone. Unreported finishes use neutral geometry materials and a fallback UI palette.

## Typography

Use native SF type roles and SF Symbols. The model is the main display line; finish and codec are supporting context. Tabular digits keep battery, volume, and EQ values stable as they change.

## Layout

The title bar keeps navigation native: My Device, Equalizer, Settings. The studio panel keeps the larger portrait and identity side by side down to the window minimum, while the portrait column scales. Overview shortcuts prioritize listening mode and its ambient level, an EQ preview, playback, then connected devices. Keep the content column readable at wide window widths and use regular system controls for focus, menus, and slider adjustment.

## Elevation & Depth

Cards rely on tonal separation rather than shadows. Physical depth belongs to the model itself: shaped geometry, contrasting pads and housings, and neutral studio-style lighting. The app does not ship the screenshot artwork or Sony logos.

## Shapes

Rounded groups contain related controls. Pills denote an action or selected option. Keep the model silhouette recognizable without using it as chrome for settings.

## Components

- **Device portrait:** original model-specific meshes for WH-1000XM3 through WH-1000XM6. The XM6 sculpt references external angles and a parts diagram for its padded crown, folding hinges, lowered touch faces, recessed cushions and side-specific ports. It uses one cached mesh with finish-specific materials. When recognized, the headset fades in and turns into a three-quarter resting pose over 640 ms, easing in and out without overshoot or an idle loop. On completion the grab cursor and rotation controls unlock. A horizontal drag spins the model; a vertical drag tilts it within a stable range. Rotate left/right and Reset view also work without a drag. Reduce Motion skips straight to the resting pose. Model and finish are also text, independent of the animation.
- **Noise mode:** text labels alongside icons and a finish-tinted selection surface. The highlight settles with a short spring and only moves when the reported mode changes.
- **Equalizer:** the selected preset and response share a card. Edit Bands toggles between the summary and native frequency sliders for custom presets. The graph represents reported settings, not acoustic gain.
- **Motion:** short, local fades for expansion and page changes; no idle loops. MetalKit requests portrait frames during the one-shot reveal or when orbit or viewport changes. Reduce Motion removes the entrance, selection travel, and fades while keeping direct manipulation.
- **App icon:** a flat headphone driver with a vented surround and central dust cap, filled with a violet-to-blue-to-teal gradient on white. macOS handles the outer shape and optional tinted and clear appearances; older systems use the matching `.icns` fallback.
- **Menu bar:** compact version of the same session, without the 3D portrait.

## Do's and Don'ts

- Do distinguish demo data, connected state, pending writes, and device errors.
- Do keep permission and connection controls available while motion plays.
- Don't replay the arrival animation on battery, settings, or ordinary navigation changes.
- Don't invent model/finish matches for unknown Bluetooth identities or copy proprietary art.
