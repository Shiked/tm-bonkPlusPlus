# Bonk++ for Trackmania
**Version:** 1.6.9.1
Plays sounds and shows visuals when you crash ('bonk') your car in Trackmania. Inspired by the original ["Bonk!"](https://github.com/MisfitMaid/tm-bonk) plugin.

Openplanet page: [Bonk++ Plugin](https://openplanet.dev/plugin/bonkplusplus)
---

## Features

*   **Crash Detection:** Detects significant impacts using vehicle physics analysis, trying to ignore normal driving bumps and landings.
*   **Sound Effects:**
    *   Plays sounds on bonks. Includes defaults (`bonk.wav`, `oof.wav`, `vineboom.mp3`).
    *   Supports your own custom local sounds (`.wav`, `.mp3`, `.ogg`).
    *   **New!** Supports downloading and using a curated list of remote sounds hosted online.
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
*   **Detection:** How sensitive the crash detection is, and time between bonks.
*   **Sound (Main Tab):**
    *   Playback mode (Random/Ordered).
    *   Max repeats for random mode.
    *   Master toggles for Default Sounds, Local Custom Sounds, and Remote Sounds.
    *   Individual enable/disable toggles for each *downloaded* Remote Sound (sounds must be downloaded first via the "Downloaded Sounds" tab).
*   **Downloaded Sounds (Tab):**
    *   View a list of available remote sounds.
    *   Download individual remote sounds to your local storage.
    *   Refresh the list of available remote sounds from the server.
    *   Reload the status of already downloaded sounds.
*   **Visual:** Duration, color, opacity, and shape of the visual effect.
*   **Stat Box:** Enable/disable the stats window, lock its position/size, toggle which stats are shown.
*   **Reset Stats:** A dedicated tab to reset map, session, or all-time stats (with confirmation).
*   **Misc:** Enable debug logging for troubleshooting.

*(Detailed descriptions for each setting are available as tooltips within the settings menu itself.)*

---

## Sound Sources

Bonk++ supports three types of sound sources:

### 1. Default Sounds
These are sounds packaged directly with the plugin (`bonk.wav`, `oof.wav`, `vineboom.mp3`).
*   Enable/disable the entire group using "Enable Default Sounds" in the **Sound** settings tab.

### 2. Local Custom Sounds
Load your own sound files from your computer.
1.  Enable `Enable Local Custom Sounds` in the **Sound** settings tab.
2.  Place your `.wav`, `.ogg`, or `.mp3` files in:
    `Documents\Trackmania\OpenplanetNext\PluginStorage\BonkPlusPlus\LocalSounds\`
    *(The plugin will create the `BonkPlusPlus\LocalSounds\` folder if it doesn't exist. If you are updating from an older version of Bonk++, your sounds from the old `\Sounds\` folder will be automatically moved to `\LocalSounds\` the first time you run this version.)*
3.  Click the `Reload Local Sounds` button in the **Sound** settings tab (under "Local Custom Sounds") or restart the game/plugin.

### 3. Remote Sounds (New!)
Download and use a curated list of sounds hosted online.
1.  Go to the **Downloaded Sounds** settings tab in Bonk++.
2.  You'll see a list of available remote sounds. Click `Download` (or `Re-download`) next to the sounds you want to use. They will be saved to:
    `Documents\Trackmania\OpenplanetNext\PluginStorage\BonkPlusPlus\DownloadedSounds\`
3.  Once a sound is downloaded, go back to the main **Sound** settings tab.
4.  Ensure "Enable Remote Sounds" is checked.
5.  You can then enable/disable individual downloaded remote sounds using their toggles (under the "Manage Downloaded Sound Toggles" collapsible section).
    *Note: A remote sound **must be downloaded first** via the "Downloaded Sounds" tab before its enable toggle in the "Sound" tab becomes active.*

---

## Dependencies

*   **Required:** `VehicleState` (Included with Openplanet) - Provides core physics data.
*   **Optional (Recommended):** `MLHook` & `MLFeedRaceData` (Install via Plugin Manager) - Needed for the most reliable detection of respawns to prevent false bonks.

---

## Troubleshooting

*   **No Sound/Visuals?**
    *   Check the master enable toggles in **General** settings.
    *   For sound, check **Volume** and **Bonk Chance**.
    *   In the **Sound** tab, ensure the desired sound source (Default, Local Custom, Remote) has its master toggle enabled.
    *   Then, ensure the specific individual sound (default or remote) is also enabled.
    *   For remote sounds, make sure they are first downloaded via the **Downloaded Sounds** tab.
    *   Check the Openplanet log (`Ctrl+L` or in overlay) for errors.
*   **Too Many/Few Bonks?** Adjust the **Detection** sensitivity settings. Lower values = more sensitive.
*   **Bonk on Respawn?** Install and enable the optional `MLHook` and `MLFeedRaceData` plugins.
*   **Visual Effect Issues?** Adjust settings in the **Visual** category.
*   **Stat Box Annoying?** Disable it in **Stat Box** settings or unlock it (`Lock Stat Box Window`) to move/resize.