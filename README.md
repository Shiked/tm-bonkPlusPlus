# Bonk++ for Trackmania
**Version:** 1.6.9
Plays sounds and shows visuals when you crash ('bonk') your car in Trackmania. Inspired by the original ["Bonk!"](https://github.com/MisfitMaid/tm-bonk) plugin.

---

## Features

*   **Crash Detection:** Detects significant impacts using vehicle physics analysis, trying to ignore normal driving bumps and landings.
*   **Sound Effects:** Plays sounds on bonks. Includes defaults (`bonk.wav`, `oof.wav`, `vineboom.mp3`) and supports your own custom sounds (`.wav`, `.mp3`, `.ogg`).
*   **Visual Effects:** Shows a configurable colored vignette (screen border effect) on impact.
*   **Stat Tracking:** An optional window displays bonk counts (current map, session, all-time) and speeds.
*   **Configurable:** Fine-tune detection sensitivity, sound/visual options, stat display, and more via Openplanet settings.

---

## Installation

1.  Ensure you have [Openplanet](https://openplanet.dev/) installed.
2.  Open the Openplanet overlay (`F3` in-game).
3.  Go to the **Plugin Manager**, search for `Bonk++`, and install it.

---

## Configuration

Access settings via the Openplanet overlay (`F3`):
`Openplanet` -> `Settings` -> `Audio` -> `Bonk++`

You can adjust:
*   **General:** Enable/disable sound/visuals, chance of sound playing, volume.
*   **Detection:** How sensitive the crash detection is (overall threshold, separate ground/air sensitivity), and time between bonks.
*   **Sound:** Playback mode (Random/Ordered), max repeats for random mode, enable/disable default sounds, enable/disable custom sounds.
*   **Visual:** Duration, color, opacity, and shape of the visual effect.
*   **Stat Box:** Enable/disable the stats window, lock its position/size, toggle which stats are shown (bonk counts, speeds, rate).
*   **Reset Stats:** A dedicated tab to reset map, session, or all-time stats (with confirmation).
*   **Misc:** Enable debug logging for troubleshooting.

*(Detailed descriptions for each setting are available as tooltips within the settings menu itself.)*

---

## Custom Sounds

1.  Enable `Enable Custom Sounds` in the **Sound** settings.
2.  Place your `.wav`, `.ogg`, or `.mp3` files in:
    `Documents\Trackmania\OpenplanetNext\PluginStorage\BonkPlusPlus\Sounds\`
    *(The plugin will create this folder if it doesn't exist)*
3.  Click the `Reload Sounds` button in the **Sound** settings (or restart the game).

---

## Dependencies

*   **Required:** `VehicleState` (Included with Openplanet) - Provides core physics data.
*   **Optional (Recommended):** `MLHook` & `MLFeedRaceData` (Install via Plugin Manager) - Needed for the most reliable detection of respawns to prevent false bonks.

---

## Troubleshooting

*   **No Sound/Visuals?** Check the master enable toggles in **General** settings. For sound, also check **Volume**, **Bonk Chance**, and if specific/custom sounds are enabled in **Sound** settings. Check the Openplanet log (`Ctrl+L` or in overlay) for errors.
*   **Too Many/Few Bonks?** Adjust the **Detection** sensitivity settings. Lower values = more sensitive.
*   **Bonk on Respawn?** Install and enable the optional `MLHook` and `MLFeedRaceData` plugins.
*   **Visual Effect Issues?** Adjust settings in the **Visual** category.
*   **Stat Box Annoying?** Disable it in **Stat Box** settings or unlock it (`Lock Stat Box Window`) to move/resize.