// --- settings.as ---
// Handles Bonk++ plugin settings definitions, debug logging,
// and custom UI elements within the Openplanet settings window.

// --- Settings Definitions ---

// --- General Settings ---
[Setting category="General" name="Enable Sound Effect" description="Play a sound when you bonk."]
bool Setting_EnableSound = true;

[Setting category="General" name="Enable Visual Effect" description="Show a visual effect when you bonk."]
bool Setting_EnableVisual = true;

[Setting category="General" name="Bonk Chance (%)" description="Probability (0-100%) that a sound will play on bonk." min=0 max=100]
uint Setting_BonkChance = 100;

[Setting category="General" name="Bonk Volume (%)" description="Volume for bonk sound effects." min=0 max=100]
uint Setting_BonkVolume = 69; // Nice.

[Setting category="General" name="Time Between Bonks (ms)"
         description="Minimum time (milliseconds) before another bonk can be registered after the previous one."
         min=300 max=5000]
uint Setting_BonkDebounce = 400; // Prevents the spamming of bonks.

// --- Detection Parameters ---
// NOTE: Setting_BonkThreshold has been REMOVED.
// The Jerk Sensitivity settings are now the primary control.

// *** Descriptions updated slightly for clarity ***
[Setting category="General" name="Jerk Sensitivity (Grounded)"
         description="Required impact sharpness when on 4 wheels. LOWER values are MORE sensitive (detects lighter hits)."
         min=0.1 max=50.0 beforerender="RenderDetectionHeader"] // Keep adjusted range
float Setting_SensitivityGrounded = 8.0f;

[Setting category="General" name="Jerk Sensitivity (Air/Other)"
         description="Required impact sharpness when airborne or on fewer wheels. LOWER values are MORE sensitive."
         min=0.1 max=50.0] // Keep adjusted range
float Setting_SensitivityAirborne = 8.0f;

// --- Sound Settings ---

/**
 * @enum SoundMode
 * @brief Defines the playback modes for selecting bonk sounds.
 */
enum SoundMode { Random, Ordered }

// RenderPlaybackHeader is called before this setting to draw a subgroup header.
// RenderMaxRepeatsInput is called after to manually draw the conditional input.
[Setting category="Sound" name="Sound Playback Mode"
         description="How to select the next sound effect."
         beforerender="RenderPlaybackHeader"
         afterrender="RenderMaxRepeatsInput"]
SoundMode Setting_SoundPlaybackMode = SoundMode::Random;

// Hidden setting, controlled manually via RenderMaxRepeatsInput when Random mode is active.
[Setting category="Sound" hidden]
uint Setting_MaxConsecutiveRepeats = 3;

// RenderSourcesHeader is called before this setting to draw a subgroup header.
[Setting category="Sound" name="Enable bonk.wav" description="Enable the default bonk.wav sound." beforerender="RenderSourcesHeader"]
bool Setting_Enable_bonkwav = true;

[Setting category="Sound" name="Enable oof.wav" description="Enable the default oof.wav sound."]
bool Setting_Enable_oofwav = true;

[Setting category="Sound" name="Enable vineboom.mp3" description="Enable the default vineboom.mp3 sound."]
bool Setting_Enable_vineboommp3 = true;

// RenderCustomSoundsHeader is called before this setting.
// RenderSoundCategoryFooter is called after this setting to display folder info.
[Setting category="Sound" name="Enable Custom Sounds"
    description="Load sound files (.wav, .ogg, .mp3) from the PluginStorage folder."
    beforerender="RenderCustomSoundsHeader" afterrender="RenderSoundCategoryFooter"]
bool Setting_EnableCustomSounds = true;

// --- Visual Settings ---
[Setting category="Visual" name="Duration (ms)" description="How long the visual effect lasts." min=50 max=2000]
uint Setting_VisualDuration = 420;

[Setting category="Visual" name="Color" color description="Color of the visual effect vignette."]
vec3 Setting_VisualColor = vec3(1.0f, 0.0f, 0.0f); // Default: Red

[Setting category="Visual" name="Max Opacity" description="Maximum opacity/intensity of the effect (0.0 to 1.0)." min=0.0 max=1.0]
float Setting_VisualMaxOpacity = 0.750f;

[Setting category="Visual" name="Feather (Width %)" description="How far the gradient spreads inwards (fraction of screen width)." min=0.0 max=1.0]
float Setting_VisualFeather = 0.2f;

[Setting category="Visual" name="Radius (Height %)" description="Rounding of the gradient shape corners (fraction of screen height)." min=0.0 max=1.0]
float Setting_VisualRadius = 0.3f;

// --- Stat Box Settings ---

// Group 1: General Box Controls
// RenderBoxControlsHeader is called before this setting.
[Setting category="Stat Box" name="Enable Stat Box"
         description="Show a small window tracking bonk statistics."
         beforerender="RenderBoxControlsHeader"]
bool Setting_EnableBonkCounterGUI = true;

[Setting category="Stat Box" name="Always Show Box"
         description="Keep the Stat Box visible even when the Openplanet overlay (F3) is hidden."]
bool Setting_GUIAlwaysVisible = true;

[Setting category="Stat Box" name="Lock Stat Box Window"
         description="Prevents the Stat Box window from being resized or moved. Enables position/size settings."
         afterrender="RenderResetPositionButton"] // ADDED afterrender
bool Setting_GUILocked = false;
// Define the new rendering function called by afterrender:
/**
 * @brief Renders a button to reset the Stat Box position and size to defaults.
 * @desc Called via `afterrender` on Setting_GUILocked.
 */
void RenderResetPositionButton() {
    // Add some vertical space after the lock checkbox
    UI::Dummy(vec2(0, 5));
    // Place the button on the same line slightly indented, or on a new line.
    // Let's put it on a new line for clarity.

    if (UI::Button("Reset Window Position & Size")) {
        const float DEFAULT_X = 50.0f;
        const float DEFAULT_Y = 50.0f;
        const float DEFAULT_W = 250.0f;
        const float DEFAULT_H = 98.0f; // Default height from settings

        Setting_GUIPosX = DEFAULT_X;
        Setting_GUIPosY = DEFAULT_Y;
        Setting_GUIWidth = DEFAULT_W;
        Setting_GUIHeight = DEFAULT_H; // Reset height too

        UI::ShowNotification("Stat Box position/size reset!");
        Debug::Print("Settings", "Stat Box position/size reset via button.");
    }
    if (UI::IsItemHovered()) {
        UI::SetTooltip("Click to reset the Stat Box window to its default screen position and size.\nUseful if the window becomes lost off-screen.");
    }
    UI::Dummy(vec2(0, 10)); // Add space before the next settings group header
}

// Group 2: Box Appearance (Conditional based on Lock)
// RenderBoxAppearanceHeader is called before this setting.
[Setting category="Stat Box" name="Box Position X"
         description="Horizontal position (pixels from left)."
         min=50 max=2000 if=Setting_GUILocked
         beforerender="RenderBoxAppearanceHeader"] // Header applies to this conditional group
float Setting_GUIPosX = 50.0f;

[Setting category="Stat Box" name="Box Position Y"
         description="Vertical position (pixels from top)."
         min=50 max=1400 if=Setting_GUILocked]
float Setting_GUIPosY = 50.0f;

[Setting category="Stat Box" name="Box Width"
         description="Width of the Stat Box window (pixels)."
         min=50 max=2000 if=Setting_GUILocked]
float Setting_GUIWidth = 250.0f;

[Setting category="Stat Box" name="Box Height"
         description="Height of the Stat Box window (pixels)."
         min=30 max=1250 if=Setting_GUILocked]
float Setting_GUIHeight = 98.0f; // Only enforced when window is locked


// Group 3: Stat Visibility Settings
// Renders a separator *after* this setting via afterrender.
[Setting category="Stat Box" name="Use Compact Labels"
         description="Display shorter labels in the Stat Box for a more compact look."] // Separator after appearance settings
bool Setting_UseCompactLabels = false;

// RenderStatVisibilityHeader is called before this setting.
[Setting category="Stat Box" name="Show Session Bonks"
         description="Display total bonks since plugin load."
         beforerender="RenderStatVisibilityHeader"] // Header for this visibility group
bool Setting_ShowSessionBonks = false;

[Setting category="Stat Box" name="Show Map Bonks"
         description="Display total bonks on the current map."]
bool Setting_ShowMapBonks = true;

[Setting category="Stat Box" name="Show All-Time Bonks"
         description="Display total bonks recorded across all sessions."]
bool Setting_ShowAllTimeBonks = true;

[Setting category="Stat Box" name="Show Fastest All-Time Bonk"
         description="Display the highest speed bonk recorded across all sessions."]
bool Setting_ShowHighestAllTimeBonk = true;

[Setting category="Stat Box" name="Show Highest Speed Bonk (Map)"
         description="Display the highest speed bonk on the current map."]
bool Setting_ShowMapMaxSpeed = false;

[Setting category="Stat Box" name="Show Last Bonk Speed"
         description="Display the speed of the most recent bonk this session."]
bool Setting_ShowLastBonkSpeed = true;

[Setting category="Stat Box" name="Show Bonk Rate (Map)"
         description="Display bonks per minute on the current map (requires active play)."]
bool Setting_ShowBonkRate = false;

// --- End Stat Box Settings ---

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
[Setting category="Misc." name="Debug: Settings" if=Setting_Debug_EnableMaster description="Log details from the settings."]
bool Setting_Debug_Settings = false;
[Setting category="Misc." name="Debug: GUI" if=Setting_Debug_EnableMaster description="Log details from the BonkStatsUI rendering."]
bool Setting_Debug_GUI = false; // Added for consistency


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
        // Exit immediately if the master debug toggle is off.
        if (!Setting_Debug_EnableMaster) return;

        // Determine if the specific category is enabled using if/else if.
        bool categoryEnabled = false;
        if (category == "Crash") {
            categoryEnabled = Setting_Debug_Crash;
        } else if (category == "Loading") {
            categoryEnabled = Setting_Debug_Loading;
        } else if (category == "Playback") {
            categoryEnabled = Setting_Debug_Playback;
        } else if (category == "Visual") {
            categoryEnabled = Setting_Debug_Visual;
        } else if (category == "Main") {
            categoryEnabled = Setting_Debug_Main;
        } else if (category == "Settings") {
            categoryEnabled = Setting_Debug_Settings;
        }
        // *** REMOVED GUI - Add it back if Setting_Debug_GUI exists ***
        // else if (category == "GUI") {
        //     categoryEnabled = Setting_Debug_GUI; // Assuming Setting_Debug_GUI exists
        // }
        // Add other categories here with 'else if' if needed.

        // Print the message only if both master and category toggles are enabled.
        if (categoryEnabled) {
            // Using print for general debug logs as requested elsewhere for visibility.
            print("[Bonk++ DBG:" + category + "] " + message);
        }
    }
}
 // namespace Debug

// --- Settings UI Rendering Callbacks ---
// These functions are called by Openplanet via `beforerender` or `afterrender`
// metadata attributes on specific settings to inject custom UI elements.

/**
 * @brief Renders a header for the "Playback Behavior" subgroup in Sound settings.
 * @desc Called via `beforerender` on Setting_SoundPlaybackMode.
 */
void RenderPlaybackHeader() {
    // No separator needed before the very first setting in the tab
    UI::SeparatorText("Playback Behavior");
}

/**
 * @brief Renders a header for the "Default Sounds" subgroup in Sound settings.
 * @desc Called via `beforerender` on Setting_Enable_bonkwav.
 */
void RenderSourcesHeader() {
    UI::Dummy(vec2(0, 10)); // Add space before the header
    UI::SeparatorText("Default Sounds");
    UI::Dummy(vec2(0, 5)); // Add space after the header
}

/**
 * @brief Renders a header for the "Custom Sounds" subgroup in Sound settings.
 * @desc Called via `beforerender` on Setting_EnableCustomSounds.
 */
void RenderCustomSoundsHeader() {
    UI::Dummy(vec2(0, 10)); // Add space before the header
    UI::SeparatorText("Custom Sounds");
}

/**
 * @brief Renders the input control for Max Consecutive Repeats manually.
 * @desc This is necessary because the setting should only be visible when
 *       `Setting_SoundPlaybackMode` is set to `Random`.
 *       Called via `afterrender` on Setting_SoundPlaybackMode.
 */
void RenderMaxRepeatsInput() {
    // Only render this input if Random mode is selected.
    if (Setting_SoundPlaybackMode == SoundMode::Random) {

        // Use a temporary variable for the InputInt widget.
        int tempRepeats = int(Setting_MaxConsecutiveRepeats);
        int oldValue = tempRepeats; // Store old value to detect changes

        // Render the InputInt widget with step buttons (+/-).
        // The label is part of the widget itself for proper alignment.
        tempRepeats = UI::InputInt("Max Random Repeats Allowed", tempRepeats, 1);

        // Add a tooltip explaining the setting.
        if (UI::IsItemHovered()) {
            UI::SetTooltip("Max times the same sound plays consecutively in Random mode (1 = never repeats).");
        }

        // Update the actual setting only if the value changed.
        if (tempRepeats != oldValue) {
            // Clamp the value to a reasonable range.
            tempRepeats = Math::Clamp(tempRepeats, 1, 10); // Clamped to 1-10
            // Store the clamped value back into the setting.
            Setting_MaxConsecutiveRepeats = uint(tempRepeats);
            Debug::Print("Settings", "Max Random Repeats changed to: " + Setting_MaxConsecutiveRepeats);
        }
    }
    // If Setting_SoundPlaybackMode is Ordered, this function does nothing.
}

/**
 * @brief Renders custom UI elements at the bottom of the "Sound" settings category.
 * @desc Displays the path to the custom sound folder and provides buttons
 *       to open the folder and reload sounds.
 *       Called via `afterrender` on Setting_EnableCustomSounds.
 */
void RenderSoundCategoryFooter() {
    UI::Dummy(vec2(0, 5)); // Add space before the separator
    UI::Separator();
    UI::Dummy(vec2(0, 5)); // Add space before the separator
    UI::TextWrapped(" Place custom sound files (.ogg | .wav | .mp3) in the folder below:");
    // Display the read-only path to the custom sounds folder.
    string customPath = IO::FromStorageFolder("Sounds/");
    UI::PushItemWidth(-160); // Adjust width to leave space for buttons
    // Use ## to hide the label visually but provide a unique ID for the widget.
    UI::InputText("##CustomSoundPath", customPath, UI::InputTextFlags::ReadOnly);
    UI::PopItemWidth();

    // Add a context menu (right-click) to copy the path.
    if (UI::IsItemHovered()) {
        UI::SetTooltip("Right-click to copy path");
        if (UI::IsMouseClicked(UI::MouseButton::Right)) {
             IO::SetClipboard(customPath);
             UI::ShowNotification("Path copied to clipboard!");
        }
    }

    // Add buttons after the path input field.
    if (UI::Button("Open Folder")) {
        // Ensure the folder exists before trying to open it, create if not.
        if (!IO::FolderExists(customPath)) {
             Debug::Print("Settings", "Creating custom sound folder for 'Open Folder' button: " + customPath);
             try {
                 IO::CreateFolder(customPath, true); // Create recursively if needed
             } catch {
                 warn("[Bonk++] Failed to create custom sound folder: " + customPath + " - Error: " + getExceptionInfo());
             }
         }
        // Attempt to open the folder in the system's file explorer.
        OpenExplorerPath(customPath);
     }
    UI::Dummy(vec2(0, 10)); 
    UI::Separator();
    UI::Dummy(vec2(0, 5)); 

    if (UI::Button("Reload Sounds")) {
    // Trigger a reload of sound metadata from the files.
    SoundPlayer::LoadSounds(); // Calls the existing function in soundPlayer.as
    UI::ShowNotification("Sounds reloaded!");
    Debug::Print("Settings", "Reload Sounds button clicked.");
    }
    UI::SameLine(); // Keep the next button on the same line
    UI::Text("Push this button if you add new sound file(s).");
}

/**
 * @brief Renders a header for the "Detection Parameters" subgroup in General settings.
 * @desc Called via `beforerender` on Setting_BonkThreshold.
 */
void RenderDetectionHeader() {
    UI::Dummy(vec2(0, 10)); // Add space before the separator
    UI::SeparatorText("Detection Parameters");
    UI::Dummy(vec2(0, 5)); // Add space after the separator text
}

// --- Settings UI Callbacks for Stat Box Tab ---

/** @brief Renders header for the general Stat Box controls.
 *  @desc Called via `beforerender` on Setting_EnableBonkCounterGUI. */
void RenderBoxControlsHeader() {
    UI::SeparatorText("General Box Controls");
    UI::Dummy(vec2(0, 5)); // Add space after header
}

/** @brief Renders header for the Stat Box appearance settings (only shown when locked).
 *  @desc Called via `beforerender` on Setting_GUIPosX. */
void RenderBoxAppearanceHeader() {
    // This callback is only triggered if Setting_GUILocked is true due to the `if` condition.

    // Add a separator *before* the header text, as the reset button might be above it now.
    UI::Separator();
    UI::Dummy(vec2(0, 5));

    UI::Text("Box Position & Size (When Locked)");
    UI::Dummy(vec2(0, 5));
}

/** @brief Renders a separator after the appearance settings.
 *  @desc Called via `afterrender` on Setting_UseCompactLabels. */
void RenderAppearanceSeparator() {
    UI::Dummy(vec2(0, 5)); // Add space before separator
    UI::Separator();
    UI::Dummy(vec2(0, 5)); // Add space after separator
}

/** @brief Renders header for the statistic visibility toggles.
 *  @desc Called via `beforerender` on Setting_ShowSessionBonks. */
void RenderStatVisibilityHeader() {
    // This header now consistently follows the appearance separator.
    UI::SeparatorText("Stats to Display");
    UI::Dummy(vec2(0, 5));
}

// --- Reset Stats Tab Rendering ---

/**
 * @brief Renders the content of the "Reset Stats" custom settings tab.
 * @desc Provides buttons to reset map-specific, session-specific, and all-time stats.
 *       Includes a confirmation modal for resetting all-time stats.
 */
[SettingsTab name="Reset Stats"]
void RenderResetStatsTab() {
    UI::TextWrapped("Use these buttons to reset tracked bonk statistics.");
    UI::Separator();
    UI::Dummy(vec2(0, 5)); // Add vertical space

    // --- Map Stats Reset ---
    UI::Text("Current Map Stats:");
    UI::SameLine(); // Place button next to text
    if (UI::Button("Reset Map")) {
        // Calls the global function defined in main.as
        ResetMapStats();
        UI::ShowNotification("Current map stats reset!");
        Debug::Print("Settings", "Map Stats Reset via Settings Tab.");
    }
    if (UI::IsItemHovered()) {
        UI::SetTooltip("Resets Bonks, Highest Speed, and Active Time for the current map only.");
    }
    UI::Dummy(vec2(0, 5)); // Add vertical space
    UI::Separator();
    UI::Dummy(vec2(0, 5)); // Add vertical space

    // --- Session Stats Reset ---
    UI::Text("Current Session Stats:");
    UI::SameLine(); // Place button next to text
    if (UI::Button("Reset Session")) {
        // Calls the global function defined in main.as
        ResetSessionStats();
        UI::ShowNotification("Current session stats reset!");
        Debug::Print("Settings", "Session Stats Reset via Settings Tab.");
    }
    if (UI::IsItemHovered()) {
        UI::SetTooltip("Resets Session Bonks and Last Bonk Speed since the plugin was last loaded/enabled.");
    }
    UI::Dummy(vec2(0, 5)); // Add vertical space
    UI::Separator();
    UI::Dummy(vec2(0, 5)); // Add vertical space

    // --- All-Time Stats Reset ---
    UI::Text("All-Time Stats:");
    UI::SameLine(); // Place button next to text
    // Use a warning color style for the reset button
    UI::PushStyleColor(UI::Col::Button, vec4(0.8f, 0.2f, 0.2f, 1.0f));        // Normal
    UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.9f, 0.3f, 0.3f, 1.0f)); // Hover
    UI::PushStyleColor(UI::Col::ButtonActive, vec4(1.0f, 0.4f, 0.4f, 1.0f));  // Clicked
    if (UI::Button("Reset All-Time")) {
        // Open the confirmation popup instead of resetting directly.
        UI::OpenPopup("Confirm All-Time Reset");
    }
    UI::PopStyleColor(3); // Pop the 3 colors pushed above
    if (UI::IsItemHovered()) {
        UI::SetTooltip("WARNING: Resets the total bonk count and highest speed recorded across ALL sessions. This action requires confirmation and cannot be undone!");
    }

    // --- Confirmation Popup Logic ---
    // Define the modal popup window. It centers automatically.
    // UI::WindowFlags::AlwaysAutoResize makes it fit its content.
    if (UI::BeginPopupModal("Confirm All-Time Reset", UI::WindowFlags::AlwaysAutoResize)) {
        UI::TextWrapped("You really want to reset your All-Time Bonk statistics?");
        UI::Separator();
        // Display current stats for confirmation
        UI::TextWrapped("Total bonk count: " + g_totalAllTimeBonks);
        // Format speed, handling the case where it hasn't been set yet.
        string highestSpeedStr = (g_highestAllTimeBonkSpeedKmh > 0.1f) ? Text::Format("%.0f", g_highestAllTimeBonkSpeedKmh) : "N/A";
        UI::TextWrapped("Highest recorded bonk: " + highestSpeedStr + " speed");
        UI::Separator();

        // Emphasize the warning text with color.
        UI::PushStyleColor(UI::Col::Text, vec4(1.0f, 0.2f, 0.2f, 1.0f)); // Red text
        UI::Text("THIS ACTION CANNOT BE UNDONE.");
        UI::PopStyleColor();

        UI::Separator();

        // Confirmation Button (uses warning style again)
        UI::PushStyleColor(UI::Col::Button, vec4(0.8f, 0.2f, 0.2f, 1.0f));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.9f, 0.3f, 0.3f, 1.0f));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(1.0f, 0.4f, 0.4f, 1.0f));
        // Give the button a fixed width for better layout.
        if (UI::Button("YES, RESET STATS", vec2(220, 0))) {
            // Calls the global function defined in main.as
            ResetAllTimeStats();
            UI::ShowNotification("All-Time stats have been reset!");
            Debug::Print("Settings", "All-Time Stats Reset via Settings Tab CONFIRMED.");
            UI::CloseCurrentPopup(); // Close the modal on confirmation
        }
        UI::PopStyleColor(3); // Pop the 3 colors

        UI::SameLine(); // Place cancel button next to confirm button

        // Cancel Button
        if (UI::Button("Cancel", vec2(100, 0))) {
            UI::CloseCurrentPopup(); // Close the modal on cancel
        }

        UI::EndPopup(); // Must be called even if the popup wasn't fully rendered (e.g., closed early)
    }
    UI::Dummy(vec2(0, 8)); // Add final spacing
    UI::Separator(); // End of All-Time section separator
}


// --- Settings Lifecycle Callbacks ---

/**
 * @brief Called by Openplanet whenever *any* plugin setting is changed via the UI.
 * @desc Reloads sound metadata to apply changes related to enabling/disabling
 *       specific sounds or the custom sounds feature.
 */
void OnSettingsChanged() {
    Debug::Print("Settings", "Settings changed, reloading sounds...");
    // Ensure sound list reflects current enable/disable settings
    SoundPlayer::LoadSounds();
}
