// --- settings.as ---
// Handles Bonk++ plugin settings definitions, debug logging,
// and specific UI elements related to settings (like the sound folder info).

// --- Settings Definitions ---
// Global variables annotated with [Setting] are automatically handled by Openplanet.

// --- General Settings ---
[Setting category="General" name="Enable Sound Effect" description="Play a sound when you bonk."]
bool Setting_EnableSound = true;
[Setting category="General" name="Enable Visual Effect" description="Show a visual effect when you bonk."]
bool Setting_EnableVisual = true;
[Setting category="General" name="Bonk Chance (%)" description="Probability (0-100%) that a sound will play on bonk." min=0 max=100]
uint Setting_BonkChance = 100;
[Setting category="General" name="Bonk Volume (%)" description="Volume for bonk sound effects." min=0 max=100]
uint Setting_BonkVolume = 69;

// --- Detection Settings ---
[Setting category="Detection" name="Preliminary Accel Threshold" description="Initial deceleration required (lower = more sensitive). Base value for dynamic threshold." min=1.0 max=100.0]
float Setting_BonkThreshold = 16.0f;
[Setting category="Detection" name="Sensitivity (Grounded)" description="Jerk magnitude threshold when 4 wheels are grounded (higher = less sensitive)." min=1.0 max=50.0]
float Setting_SensitivityGrounded = 4.0f;
[Setting category="Detection" name="Sensitivity (Airborne/Less Contact)" description="Jerk magnitude threshold when < 4 wheels are grounded (higher = less sensitive)." min=1.0 max=50.0]
float Setting_SensitivityAirborne = 4.0f;
[Setting category="Detection" name="Bonk Debounce (ms)" description="Minimum time in milliseconds between bonks." min=300 max=5000]
uint Setting_BonkDebounce = 500;

// --- Sound Settings ---
enum SoundMode { Random, Ordered } // Defines the playback modes available in settings
[Setting category="Sound" name="Sound Playback Mode" description="How to select the next sound effect."]
SoundMode Setting_SoundPlaybackMode = SoundMode::Random;
[Setting category="Sound" name="Max Consecutive Repeats (Random)" description="Max times the same sound plays consecutively in Random mode (1 = never repeats)." min=1 max=5]
uint Setting_MaxConsecutiveRepeats = 3;
[Setting category="Sound" name="Enable Custom Sounds" description="Load sound files from the PluginStorage folder."]
bool Setting_EnableCustomSounds = true;
// Specific toggles for default sounds
[Setting category="Sound" name="Enable bonk.wav" description="Enable the default bonk.wav sound."]
bool Setting_Enable_bonkwav = true;
[Setting category="Sound" name="Enable oof.wav" description="Enable the default oof.wav sound."]
bool Setting_Enable_oofwav = true;
// `afterrender` calls the specified global function after this setting widget is drawn in the UI
[Setting category="Sound" name="Enable vineboom.mp3" description="Enable the default vineboom.mp3 sound." afterrender="RenderSoundCategoryFooter"]
bool Setting_Enable_vineboommp3 = true;

// --- Visual Settings ---
[Setting category="Visual" name="Duration (ms)" description="How long the visual effect lasts." min=50 max=2000]
uint Setting_VisualDuration = 420;
[Setting category="Visual" name="Color" color description="Color of the visual effect vignette."]
vec3 Setting_VisualColor = vec3(1.0f, 0.0f, 0.0f); // Default Red
[Setting category="Visual" name="Max Opacity" description="Maximum opacity/intensity of the effect (0.0 to 1.0)." min=0.0 max=1.0]
float Setting_VisualMaxOpacity = 0.696f;
[Setting category="Visual" name="Feather (Width %)" description="How far the gradient spreads inwards (fraction of screen width)." min=0.0 max=1.0]
float Setting_VisualFeather = 0.1f;
[Setting category="Visual" name="Radius (Height %)" description="Rounding of the gradient shape corners (fraction of screen height)." min=0.0 max=1.0]
float Setting_VisualRadius = 0.2f;

// --- Misc. Settings (Debug) ---
// Master toggle for all debug logs
[Setting category="Misc." name="Enable Debug Logging" description="Show detailed logs for debugging."]
bool Setting_Debug_EnableMaster = false;
// Individual toggles for specific log categories, only visible if master toggle is enabled
[Setting category="Misc." name="Debug: Crash Detection" if=Setting_Debug_EnableMaster description="Log details about impact detection."]
bool Setting_Debug_Crash = false;
[Setting category="Misc." name="Debug: Sound Loading" if=Setting_Debug_EnableMaster description="Log details about finding and loading sound files."]
bool Setting_Debug_Loading = false;
[Setting category="Misc." name="Debug: Sound Playback" if=Setting_Debug_EnableMaster description="Log details about sound selection and playback attempts."]
bool Setting_Debug_Playback = false;
[Setting category="Misc." name="Debug: Visual Effect" if=Setting_Debug_EnableMaster description="Log details about visual effect triggering/rendering."]
bool Setting_Debug_Visual = false;
[Setting category="Misc." name="Debug: Main Loop" if=Setting_Debug_EnableMaster description="Log details from the main coordination logic."]
bool Setting_Debug_Main = false;

// --- End of Settings Definitions ---

// --- Debug Logging Namespace ---
// Provides a centralized way to handle conditional debug printing.
// Defined *after* settings variables so it can access them.
namespace Debug {
    /**
     * @desc Prints a message to the Openplanet log if the master debug setting
     *       and the specific category debug setting are both enabled.
     * @param category The log category (e.g., "Crash", "Playback"). Should match a Setting_Debug_... variable name suffix.
     * @param message The message to print.
     */
    void Print(const string &in category, const string &in message) {
        if (!Setting_Debug_EnableMaster) return; // Check master toggle first

        // Check if the specific category is enabled
        bool categoryEnabled = false;
        if (category == "Crash" && Setting_Debug_Crash) categoryEnabled = true;
        else if (category == "Loading" && Setting_Debug_Loading) categoryEnabled = true;
        else if (category == "Playback" && Setting_Debug_Playback) categoryEnabled = true;
        else if (category == "Visual" && Setting_Debug_Visual) categoryEnabled = true;
        else if (category == "Main" && Setting_Debug_Main) categoryEnabled = true;
        // Add other categories here if needed for future debugging

        if (categoryEnabled) {
            print("[Bonk++ DBG:" + category + "] " + message);
        }
    }
}

// --- Settings UI Callbacks ---
// Functions called by Openplanet during settings UI rendering or lifecycle events.
// Must remain global.

/**
 * @desc Renders custom UI elements at the bottom of the "Sound" settings category.
 *       Called via the `afterrender` attribute on the last setting in the category.
 */
void RenderSoundCategoryFooter() {
    UI::Separator();
    UI::TextWrapped("Place custom sound files (.ogg, .wav, .mp3) in the folder below. They will be loaded automatically if 'Enable Custom Sounds' is checked above.");

    // Display the path to the custom sounds folder
    string customPath = IO::FromStorageFolder("Sounds/");
    UI::PushItemWidth(-160); // Adjust width for buttons on the same line
    UI::InputText("##CustomSoundPath", customPath, UI::InputTextFlags::ReadOnly); // Use ## to hide label but provide ID
    UI::PopItemWidth();

    // Add context menu to copy the path
    if (UI::IsItemHovered()) {
        UI::SetTooltip("Right-click to copy path");
        if (UI::IsMouseClicked(UI::MouseButton::Right)) {
             IO::SetClipboard(customPath);
             UI::ShowNotification("Path copied to clipboard!");
        }
    }

    // Add buttons next to the path
    UI::SameLine();
    if (UI::Button("Open Folder")) {
        // Ensure the folder exists before trying to open it
        if (!IO::FolderExists(customPath)) {
             Debug::Print("Loading", "Creating custom sound folder for 'Open Folder' button: " + customPath);
             // Attempt to create the folder if it doesn't exist
             try { IO::CreateFolder(customPath); } catch { warn("[Bonk++] Failed to create custom sound folder: " + customPath + " - Error: " + getExceptionInfo()); }
         }
        // Attempt to open the folder (might fail silently if folder still doesn't exist)
        OpenExplorerPath(customPath);
     }
     UI::SameLine();
     if (UI::Button("Reload Sounds")) {
        // Trigger a reload of sound metadata
        SoundPlayer::LoadSounds();
        UI::ShowNotification("Sounds reloaded!"); // Give user feedback
     }
}

/**
 * @desc Called by Openplanet whenever *any* plugin setting is changed via the UI.
 *       Reloads sounds to apply changes to default sound toggles or the custom sound toggle.
 */
void OnSettingsChanged() {
    Debug::Print("Loading", "Settings changed, reloading sounds...");
    SoundPlayer::LoadSounds(); // Reload sound metadata
}

/**
 * @desc Called by Openplanet when settings are loaded (e.g., on game start).
 *       No custom logic needed here as settings are loaded automatically into global variables.
 * @param section Provides access to raw settings data if needed.
 */
void OnSettingsLoad(Settings::Section& section) {
    // print("[Bonk++] Settings Loaded."); // Optional: Log if needed
}

/**
 * @desc Called by Openplanet when settings are saved (e.g., on game exit or closing settings).
 *       No custom logic needed here as settings are saved automatically from global variables.
 * @param section Provides access to write raw settings data if needed.
 */
void OnSettingsSave(Settings::Section& section) {
    // print("[Bonk++] Settings Saved."); // Optional: Log if needed
}