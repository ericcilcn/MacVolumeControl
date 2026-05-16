---
layout: ../../layouts/BaseLayout.astro
title: Permissions
description: Rolume permissions, accessibility access, DDC/CI display control, and first-run notes.
lang: en
---

# Permissions

Rolume is a local macOS menu bar app. It does not upload your device information, and the website does not provide any remote-control functionality.

## Accessibility Permission

Rolume only needs Accessibility permission when you enable features that read or intercept scroll events at the system level:

- Mouse wheel reversal
- Mouse scroll interception
- Trackpad gesture interception
- Modifier-key volume control in global interception scenarios

macOS asks for this permission because these features work below ordinary app windows.

## DDC/CI Display Control

Rolume tries to control external display volume through DDC/CI. Availability depends on the display, cable, adapter, port, and the macOS display path.

If a display cannot be controlled, try:

- Confirm that DDC/CI is enabled in the display menu
- Connect directly instead of through a complex dock
- Try another cable or port
- Open a GitHub Issue with the display model and connection method

## First Launch

The current public beta is not signed or notarized with a Developer ID yet. On first launch, macOS may say the app is from an unidentified developer.

You can allow it manually in System Settings. If the project continues, signing and notarization can be handled as a separate release step.
