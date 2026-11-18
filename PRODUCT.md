# Project XMConnect

<!-- impeccable:product-schema 1 -->

## Platform

macos

Native macOS 15+ only. This is not iOS, Android, or a web wrapper; tooling with no macOS platform enum must not substitute web guidance.

## Stack

Confirmed: SwiftUI and AppKit for interface, lifecycle, menu bar, and animation. Reuse the repository's C++ `libmdr` and Objective-C++ IOBluetooth transport through the existing C ABI. Build a separate native app without removing the reference client.

## Users

Initially the owner of WH-1000XM6 headphones who wants to control their headphones directly from their Mac, with familiar phone-app organization.

## Product Purpose

A standalone Mac headphone controller with quick menu-bar access and a full device window. Success means real device-backed controls and accurate connection state, not a disconnected visual mockup.

## Operating Context

WH-1000XM6 over Bluetooth Classic; user reports latest firmware. Exact firmware and live-device behavior remain to be verified. Phone and Mac may share a multipoint connection.

## Capabilities and Constraints

- Minimum macOS 15; temporary product name Project XMConnect.
- Main window and menu bar share one serialized headphone session.
- Initial milestone: pairing guidance, explicit connection, battery, NC/ambient/off, ambient level, EQ presets/bands, playback/volume, supported device settings, and connected-device display.
- Capability/range discovery governs controls; never claim unsupported Sony features or assume every firmware supports the same commands.
- No automatic device connection or hardware writes during agent testing. A clearly labeled, explicit demo mode may exercise the UI without Bluetooth.
- Preserve upstream license notices. No Sony logos or extracted proprietary device artwork in shipping resources.
- Distribution and final public branding remain undecided. Local development builds are not notarized releases.

## Brand Commitments

User explicitly requests Material 3 Expressive principles alongside supplied Sony Sound Connect phone screenshots, implemented natively with Apple's frameworks. Preserve the phone's recognizable organization rather than invent a different product aesthetic. User approved beginning after supplying overview, EQ summary/editor, and settings screenshots.

## Evidence on Hand

Five supplied phone screenshots: device overview, shortcuts/multipoint/playback, ten-band EQ summary, ten-band editor, and grouped settings. Screenshots contain private device names and Sony artwork, so reference them in-session without copying them into the repository or treating them as licensed app assets. They establish a light device header, charcoal cards, lavender selection, and frequencies from 31 Hz to 16 kHz. Actual UI values must come from the device, not screenshot transcription.

## Product Principles

- Actual hardware state outranks optimistic UI.
- Native accessibility and Mac interaction conventions coexist with phone familiarity.
- No hidden packet capture, network dependency at runtime, or automatic connection.
- Preserve the protocol engine and its safety checks; migrate incrementally.
