---
name: Project XMConnect
description: A native macOS listening controller with a device-aware 3D portrait.
colors:
  background: '#101313'
  surface: '#272B2C'
  surface-high: '#363B3D'
  outline: '#50585B'
  primary: '#C3C2FF'
  on-primary: '#24234F'
  text: '#F1F1F0'
  secondary: '#C9CBCB'
  header: '#E7E8E5'
  on-header: '#191C1C'
  error: '#FFB4AB'
typography:
  device-name:
    fontFamily: 'SF Pro'
    fontSize: '30px'
    fontWeight: 600
rounded:
  card: '22px'
  pill: '999px'
spacing:
  group-gap: '12px'
  card-inset: '22px'
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

# Design System: Project XMConnect

## Overview

The product front-loads **device identity**, then makes the most common listening changes reachable in one scroll. The user’s Sound Connect references inform the layout, not the assets. The design applies Material 3 tonal hierarchy and restrained expressive motion through SwiftUI, AppKit, and RealityKit.

## Colors

Pale ceramic separates the hardware portrait from the dark listening surface. Lavender identifies selection and actionable emphasis, not decorative borders. The portrait’s materials use the MDR-reported finish; a neutral render is used when color is unreported. The app does not infer finish from the UI accent.

## Typography

Use native SF type roles and SF Symbols. The model is the main display line; finish and codec are supporting context. Tabular digits keep battery, volume, and EQ values stable as they change.

## Layout

The title bar keeps navigation native. The pale header pairs the model with its identity, stacking those elements when width is limited. Overview shortcuts prioritize listening mode and its ambient level, an EQ preview, playback, then connected devices. Keep the content column readable at wide window widths and use regular system controls for focus, menus, and slider adjustment.

## Elevation & Depth

Cards rely on tonal separation rather than shadows. Physical depth belongs to the model itself: shaped geometry, contrasting pads and housings, and neutral studio-style lighting. The app does not ship the screenshot artwork or Sony logos.

## Shapes

Rounded groups contain related controls. Pills denote an action or selected option. Keep the model silhouette recognizable without using it as chrome for settings.

## Components

- **Device portrait:** original model-specific meshes for WH-1000XM3 through WH-1000XM6. The XM6 sculpt uses the supplied reference for the padded crown, folding rails, broad matte shells and recessed cushions, with distinct Black, Platinum Silver and Midnight Blue materials. When recognized, the headset turns into a three-quarter resting pose in 580 ms, with no overshoot or idle loop. On completion the grab cursor and rotation controls unlock. A horizontal drag spins the model; a vertical drag tilts it within a stable range. Rotate left/right and Reset view also work without a drag. Reduce Motion skips straight to the resting pose. Model and finish are also text, independent of the animation.
- **Noise mode:** text labels alongside icons and a lavender selection surface. The highlight settles with a short spring and only moves when the reported mode changes.
- **Equalizer:** the selected preset and response share a card. Edit Bands toggles between the summary and native frequency sliders for custom presets. The graph represents reported settings, not acoustic gain.
- **Motion:** short, local fades for expansion and page changes; no idle loops. MetalKit requests portrait frames during the one-shot reveal or when orbit or viewport changes. Reduce Motion removes the entrance, selection travel, and fades while keeping direct manipulation.
- **Menu bar:** compact version of the same session, without the 3D portrait.

## Do's and Don'ts

- Do distinguish demo data, connected state, pending writes, and device errors.
- Do keep permission and connection controls available while motion plays.
- Don't replay the arrival animation on battery, settings, or ordinary navigation changes.
- Don't invent model/finish matches for unknown Bluetooth identities or copy proprietary art.
