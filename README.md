# Bonk++ for Trackmania
**Version:** 1.0.2

## Description

Bonk++ is an Openplanet plugin for Trackmania (2020+) that enhances gameplay by providing audible and visual feedback when your car experiences a "bonk" (significant impact or crash). 
It uses physics analysis inspired by the original ["Bonk!" plugin](https://github.com/MisfitMaid/tm-bonk) to trigger the effects.

## Features

*   **Physics-Based Crash Detection:** Uses filtered jerk calculation (change in specific acceleration components) to detect significant impacts, ignoring normal braking and vertical bumps.
*   **Sound Effects:** Plays a sound effect upon detecting a bonk.
    *   Includes default sounds (`bonk.wav`, `oof.wav`, `vineboom.mp3`).
    *   Supports custom user-added sounds (`.wav`, `.mp3`, `.ogg`).
    *   Configurable playback chance, volume, playback mode (Random/Ordered), and anti-repeat for Random mode.
    *   Individual toggles for default sounds and a master toggle for custom sounds.
*   **Visual Feedback:** Displays a configurable screen vignette effect upon detecting a bonk.
    *   Customize duration, color, maximum opacity, feathering, and corner radius.
*   **Highly Configurable:** Fine-tune detection sensitivity (grounded/airborne), preliminary acceleration threshold, and debounce timing via Openplanet settings.
*   **Debug Options:** Includes optional detailed logging for troubleshooting detection, sound loading, and playback.

## Installation

1.  Make sure you have [Openplanet](https://openplanet.dev/) installed for Trackmania.
2.  Download the latest `Bonk++` version from the in-game Openplanet plugin manager, see [Openplanet's plugin installation guide](https://openplanet.dev/docs/tutorials/installing-plugins) for more information. 

## Configuration (Openplanet Settings)

You can configure Bonk++ through the Openplanet overlay (press `F3`).  
Navigate to `Openplanet` -> `Settings` -> `Audio` -> `Bonk++`.

### General
*   `Enable Sound Effect`: Master toggle for playing sounds on bonks.
*   `Enable Visual Effect`: Master toggle for showing the visual on bonks.
*   `Bonk Chance (%)`: The probability (0-100%) that a sound will play when a bonk is detected.
*   `Bonk Volume (%)`: Adjusts the volume of the bonk sound effects.

### Detection
*   `Preliminary Accel Threshold`: The initial deceleration required to *consider* an impact a potential bonk. Higher values require a harder initial hit. This works alongside the sensitivity settings.
*   `Sensitivity (Grounded)`: The magnitude of filtered *jerk* (sharp change in side/up/down acceleration) required to confirm a bonk when all 4 wheels are on the ground. **Higher values make it *less* sensitive** (requires a sharper impact).
*   `Sensitivity (Airborne/Less Contact)`: Jerk magnitude threshold when fewer than 4 wheels are grounded. **Higher values make it *less* sensitive**.
*   `Bonk Debounce (ms)`: The minimum time (in milliseconds) that must pass after one bonk before another can be triggered. Prevents spamming effects during multi-stage crashes.

### Sound
*   `Sound Playback Mode`:
    *   `Random`: Selects a random *enabled* sound each time.
    *   `Ordered`: Cycles through the list of *enabled* sounds sequentially.
*   `Max Consecutive Repeats (Random)`: In `Random` mode, limits how many times the *same* sound file can be chosen consecutively. `1` means it will always try to pick a different sound if possible.
*   `Enable Custom Sounds`: Master toggle to enable or disable loading sounds from the custom folder specified below.
*   `Enable [Default Sound Name]`: Individual toggles for each default sound (`bonk.wav`, `oof.wav`, `vineboom.mp3`).

*(At the bottom of the Sound category, information about the custom sound folder is displayed)*

### Visual
*   `Duration (ms)`: How long the visual vignette effect lasts on screen.
*   `Color`: Click the color swatch to pick the color of the vignette effect.
*   `Max Opacity`: The maximum transparency of the vignette effect (0.0 = fully transparent, 1.0 = fully opaque color). The effect fades out from this value.
*   `Feather (Width %)`: Controls the softness of the vignette's edge (gradient size relative to screen width).
*   `Radius (Height %)`: Controls the rounding of the vignette's corners (relative to screen height). 

### Misc. (Debug)
*   `Enable Debug Logging`: Master toggle for all debug messages.
*   `Debug: Crash Detection`: Show detailed logs related to acceleration, jerk, and threshold checks (be warned: a lot of logging happens).
*   `Debug: Sound Loading`: Show logs related to finding and preparing sound file metadata.
*   `Debug: Sound Playback`: Show logs related to selecting and attempting to play sounds.

## Custom Sounds

1.  Ensure `Enable Custom Sounds` is checked in the settings.
2.  Place your custom sound files (`.wav`, `.ogg`, or `.mp3` format) inside the following folder:
    *   `Documents\Trackmania\OpenplanetNext\PluginStorage\BonkPlusPlus\Sounds\`
3.  Use the "Reload Sounds" button in the plugin settings (under the "Sound" category) or restart the game to make the plugin recognize new files.
4.  Currently, all found custom sounds are considered enabled if the master toggle is on; there are no individual toggles for custom sounds in the UI because it was next to impossible to figure out.

## Dependencies

*   **Required:**
    *   VehicleState (comes from Openplanet): Provides necessary vehicle physics information (velocity, wheel contact, etc.). Must be installed and enabled.
*   **Optional (Recommended for best respawn detection):**
    *   [MLHook](https://openplanet.dev/plugin/mlhook): Base plugin for ManiaLive interaction.
    *   [MLFeedRaceData](https://openplanet.dev/plugin/mlfeedracedata): Provides detailed race state information, including precise respawn status

## Troubleshooting

*   **No sounds play:** Check `Enable Sound Effect`, `Bonk Volume`, `Bonk Chance`. Ensure default sounds are enabled or `Enable Custom Sounds` is on and files exist in the correct folder/format. Check the Openplanet log (`Ctrl+L`) for loading errors.
*   **Bonks trigger too often/not often enough:** Adjust `Preliminary Accel Threshold` and the `Sensitivity` settings. Lower threshold/sensitivity = more bonks. Higher threshold/sensitivity = fewer bonks. Check debug logs if enabled.
*   **Bonks trigger on respawn:** Ensure `MLHook` and `MLFeedRaceData` are installed and enabled for the most reliable detection. If they are not available, the plugin relies on less precise methods which might occasionally trigger.
*   **Visual effect is annoying/too strong/too weak:** Adjust `Enable Visual Effect`, `Duration`, `Color`, `Max Opacity`, `Feather`, and `Radius` settings
