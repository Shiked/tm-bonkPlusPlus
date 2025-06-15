// --- settings.as ---
// Handles Bonk++ plugin settings definitions, debug logging, and custom UI elements within the Openplanet settings window.

// --- General Settings ---
[Setting category="General" name="Enable Sound Effect" description="Play a sound when you bonk."]
bool Setting_EnableSound = true;

[Setting category="General" name="Enable Visual Effect" description="Show a visual effect when you bonk."]
bool Setting_EnableVisual = true;

[Setting category="General" name="Bonk Chance (%)" description="Probability (0-100%) that a sound will play on bonk." min=0 max=100]
uint Setting_BonkChance = 100;

[Setting category="General" name="Bonk Volume (%)" description="Volume for bonk sound effects." min=0 max=100]
uint Setting_BonkVolume = 69;

[Setting category="General" name="Time Between Bonks (ms)" description="Minimum time (milliseconds) before another bonk can be played after the previous one." min=300 max=5000]
uint Setting_BonkDebounce = 400;

// --- Detection Parameters ---
[Setting category="General" name="Jerk Sensitivity (Grounded)" description="Required impact sharpness when on 4 wheels.\n**LOWER values are MORE sensitive (detects lighter hits)**" min=0.1 max=50.0 beforerender="RenderDetectionHeader"]
float Setting_SensitivityGrounded = 4.0f;

[Setting category="General" name="Jerk Sensitivity (Air/Other)" description="Required impact sharpness when airborne or on fewer wheels.\n**LOWER values are MORE sensitive (detects lighter hits)**" min=0.1 max=50.0]
float Setting_SensitivityAirborne = 4.0f;

[Setting category="General" name="Deceleration Threshold (Base)" description="Base value for detecting a significant slowdown. Higher values require a harder stop." min=1.0 max=50.0 hidden]
float Setting_DecelerationThreshold = 16.0f;

// --- End General Settings ---

// --- Sound Settings ---
/**
 * SoundMode
 * Defines the playback modes for selecting bonk sounds.
 */
enum SoundMode { Random, Ordered }

[Setting category="Sound" name="Sound Playback Mode" description="How to select the next sound effect from all enabled sources."
    beforerender="RenderPlaybackHeader"
    afterrender="RenderMaxRepeatsInput"]
SoundMode Setting_SoundPlaybackMode = SoundMode::Random;

[Setting category="Sound" hidden] // Controlled via RenderMaxRepeatsInput
uint Setting_MaxConsecutiveRepeats = 3;


// --- Master Toggles for Sound Sources ---
[Setting category="Sound" name="Enable Default Sounds" description="Use sounds packaged with the plugin."
    beforerender="RenderDefaultSoundsHeader"]
bool Setting_EnableDefaultSounds = true;

// Individual Default Sound Toggles (rendered via RenderDefaultSoundTogglesList now)
[Setting category="Sound" name="Enable bonk.wav (Default)" hidden] // Hidden from auto-render
bool Setting_Enable_Default_bonkwav = true;
[Setting category="Sound" name="Enable oof.wav (Default)" hidden]
bool Setting_Enable_Default_oofwav = true;
[Setting category="Sound" name="Enable vineboom.mp3 (Default)" hidden]
bool Setting_Enable_Default_vineboommp3 = true;
// Add more default sound settings here if they exist, following this pattern.

[Setting category="Sound" name="Enable Local Custom Sounds" description="Load sounds from 'PluginStorage/YOUR_PLUGIN_ID/LocalSounds/' folder."
    beforerender="RenderLocalCustomSoundsHeader"
    afterrender="RenderLocalCustomSoundsFooter"]
bool Setting_EnableLocalCustomSounds = true; // This remains a master toggle for the whole folder.

// --- Master Toggle for Remote Sounds ---
[Setting category="Sound" name="Enable Downloaded Sounds" description="Allow use of downloaded sounds."
    beforerender="RenderRemoteSoundsHeader"]
bool Setting_EnableRemoteSounds = false;

// --- Individual Remote Sound Toggles ---
[Setting category="Sound" name="Another One" if=Setting_EnableRemoteSounds description="Enable the downloaded 'another-one.mp3' sound."]
bool Setting_Enable_Remote_another_one_mp3 = true;

[Setting category="Sound" name="Fart" if=Setting_EnableRemoteSounds description="Enable the downloaded 'dry-fart.mp3' sound."]
bool Setting_Enable_Remote_dry_fart_mp3 = true;

[Setting category="Sound" name="Toy Duck" if=Setting_EnableRemoteSounds description="Enable the downloaded 'duck-toy-sound.mp3' sound."]
bool Setting_Enable_Remote_duck_toy_sound_mp3 = true;

[Setting category="Sound" name="Error" if=Setting_EnableRemoteSounds description="Enable the downloaded 'erro.mp3' sound."]
bool Setting_Enable_Remote_erro_mp3 = true;

[Setting category="Sound" name="Wenk" if=Setting_EnableRemoteSounds description="Enable the downloaded 'mac-quack.mp3' sound."]
bool Setting_Enable_Remote_mac_quack_mp3 = true;

[Setting category="Sound" name="Punch" if=Setting_EnableRemoteSounds description="Enable the downloaded 'punch.mp3' sound."]
bool Setting_Enable_Remote_punch_mp3 = true;

[Setting category="Sound" name="Rizzler" if=Setting_EnableRemoteSounds description="Enable the downloaded 'rizz-sound-effect.mp3' sound."]
bool Setting_Enable_Remote_rizz_sound_effect_mp3 = true;

[Setting category="Sound" name="Spongebob bwooomp" if=Setting_EnableRemoteSounds description="Enable the downloaded 'spongebob-boowomp.mp3' sound."]
bool Setting_Enable_Remote_spongebob_boowomp_mp3 = true;

[Setting category="Sound" name="TA-DA!" if=Setting_EnableRemoteSounds description="Enable the downloaded 'ta-da.mp3' sound."]
bool Setting_Enable_Remote_ta_da_mp3 = true;

[Setting category="Sound" name="Taco Gong" if=Setting_EnableRemoteSounds description="Enable the downloaded 'taco-bell-bong-sfx.mp3' sound."]
bool Setting_Enable_Remote_taco_bell_bong_sfx_mp3 = true;

[Setting category="Sound" name="WHAT ARE YOU DOING?!" if=Setting_EnableRemoteSounds description="Enable the downloaded 'what-are-you-doing.mp3' sound."]
bool Setting_Enable_Remote_what_are_you_doing_mp3 = true;


// --- End Sound Settings ---

// --- Visual Settings ---
[Setting category="Visual" name="Duration (ms)" description="How long the visual effect lasts." min=50 max=2000]
uint Setting_VisualDuration = 420;

[Setting category="Visual" name="Color" color description="Color of the visual effect vignette."]
vec3 Setting_VisualColor = vec3(1.0f, 0.0f, 0.0f);

[Setting category="Visual" name="Max Opacity" description="Maximum opacity/intensity of the effect (0.0 to 1.0)." min=0.0 max=1.0]
float Setting_VisualMaxOpacity = 0.750f;

[Setting category="Visual" name="Feather (Width %)" description="How far the gradient spreads inwards (fraction of screen width)." min=0.0 max=1.0]
float Setting_VisualFeather = 0.2f;

[Setting category="Visual" name="Radius (Height %)" description="Rounding of the gradient shape corners (fraction of screen height)." min=0.0 max=1.0]
float Setting_VisualRadius = 0.3f;
// --- End Visual Settings ---

// --- Stat Box Settings (largely unchanged, only headers for grouping) ---
[Setting category="Stat Box" name="Enable Stat Box" description="Show a small window tracking bonk statistics." beforerender="RenderBoxControlsHeader"]
bool Setting_EnableBonkCounterGUI = true;
[Setting category="Stat Box" name="Always Show Box" description="Keep the Stat Box visible even when the Openplanet overlay (F3) is hidden."]
bool Setting_GUIAlwaysVisible = true;
[Setting category="Stat Box" name="Lock Stat Box Window" description="Prevents the Stat Box window from being resized or moved." afterrender="RenderResetPositionButton"]
bool Setting_GUILocked = false;

[Setting category="Stat Box" name="Box Position X" description="Horizontal position." min=0 max=5000 if=Setting_GUILocked beforerender="RenderBoxAppearanceHeader"]
float Setting_GUIPosX = 50.0f;
[Setting category="Stat Box" name="Box Position Y" description="Vertical position." min=0 max=3000 if=Setting_GUILocked]
float Setting_GUIPosY = 50.0f;
[Setting category="Stat Box" name="Box Width" description="Width of the Stat Box." min=50 max=1000 if=Setting_GUILocked]
float Setting_GUIWidth = 250.0f;
[Setting category="Stat Box" name="Box Height" description="Height of the Stat Box." min=30 max=500 if=Setting_GUILocked]
float Setting_GUIHeight = 98.0f;

[Setting category="Stat Box" name="Use Compact Labels" description="Display shorter labels." beforerender="RenderStatVisibilityHeader"]
bool Setting_UseCompactLabels = false;
[Setting category="Stat Box" name="Show Session Bonks" description="Display total bonks since plugin load."]
bool Setting_ShowSessionBonks = false;
[Setting category="Stat Box" name="Show Map Bonks" description="Display total bonks on the current map."]
bool Setting_ShowMapBonks = true;
[Setting category="Stat Box" name="Show All-Time Bonks" description="Display total bonks recorded across all sessions."]
bool Setting_ShowAllTimeBonks = true;
[Setting category="Stat Box" name="Show Fastest All-Time Bonk" description="Display the highest speed bonk recorded across all sessions."]
bool Setting_ShowHighestAllTimeBonk = true;
[Setting category="Stat Box" name="Show Highest Speed Bonk (Map)" description="Display the highest speed bonk on the current map."]
bool Setting_ShowMapMaxSpeed = false;
[Setting category="Stat Box" name="Show Last Bonk Speed" description="Display the speed of the most recent bonk this session."]
bool Setting_ShowLastBonkSpeed = true;
[Setting category="Stat Box" name="Show Bonk Rate (Map)" description="Display bonks per minute on the current map."]
bool Setting_ShowBonkRate = false;
// --- End Stat Box Settings ---

// --- Misc. Settings (Debug) ---
// Master toggle for all debug logs
[Setting category="Misc." name="Enable Debug Logging" description="Show detailed logs for debugging."]
bool Setting_Debug_EnableMaster = false;

// Individual toggles for specific log categories, only visible if master toggle is enabled
[Setting category="Misc." name="Debug: Crash Detection (warning: spams the logs)" if=Setting_Debug_EnableMaster description="Log details about impact detection."]
bool Setting_Debug_Crash = false;
[Setting category="Misc." name="Debug: Sound Loading" if=Setting_Debug_EnableMaster description="Log details about finding and loading sound files."]
bool Setting_Debug_Loading = false;
[Setting category="Misc." name="Debug: Sound Playback" if=Setting_Debug_EnableMaster description="Log details about sound selection and playback attempts."]
bool Setting_Debug_Playback = false;
[Setting category="Misc." name="Debug: SoundPlayer (Core)" if=Setting_Debug_EnableMaster description="Log general details from the SoundPlayer module (initialization, list building)."]
bool Setting_Debug_SoundPlayer = false;
[Setting category="Misc." name="Debug: Visual Effect" if=Setting_Debug_EnableMaster description="Log details about visual effect triggering/rendering."]
bool Setting_Debug_Visual = false;
[Setting category="Misc." name="Debug: Main Loop" if=Setting_Debug_EnableMaster description="Log details from the main coordination logic."]
bool Setting_Debug_Main = false;
[Setting category="Misc." name="Debug: Settings" if=Setting_Debug_EnableMaster description="Log details from the settings."]
bool Setting_Debug_Settings = false;
[Setting category="Misc." name="Debug: GUI" if=Setting_Debug_EnableMaster description="Log details from the BonkStatsUI rendering."]
bool Setting_Debug_GUI = false;

// --- Debug Logging Namespace (unchanged) ---
namespace Debug {
    void Print(const string &in category, const string &in message) {
        if (!Setting_Debug_EnableMaster) return;
        bool categoryEnabled = false;
        if (category == "Crash") categoryEnabled = Setting_Debug_Crash;
        else if (category == "Loading") categoryEnabled = Setting_Debug_Loading;
        else if (category == "Playback") categoryEnabled = Setting_Debug_Playback;
        else if (category == "SoundPlayer") categoryEnabled = Setting_Debug_SoundPlayer;
        else if (category == "Visual") categoryEnabled = Setting_Debug_Visual;
        else if (category == "Main") categoryEnabled = Setting_Debug_Main;
        else if (category == "Settings") categoryEnabled = Setting_Debug_Settings;
        else if (category == "GUI") categoryEnabled = Setting_Debug_GUI;
        // Add other categories here with 'else if' if needed.
        if (categoryEnabled) print("[Bonk++ DBG:" + category + "] " + message);
    }
}

// --- Settings UI Rendering Callbacks ---

// General Settings Headers (unchanged)
void RenderDetectionHeader() { UI::Dummy(vec2(0, 10)); UI::SeparatorText("Detection Parameters"); UI::Dummy(vec2(0, 5)); }

// Sound Settings Headers & Custom UI
void RenderPlaybackHeader() { UI::SeparatorText("Playback Behavior"); }

void RenderMaxRepeatsInput() {
    if (Setting_SoundPlaybackMode == SoundMode::Random) {
        int tempRepeats = int(Setting_MaxConsecutiveRepeats);
        int oldValue = tempRepeats;
        tempRepeats = UI::InputInt("Max Random Repeats", tempRepeats, 1);
        if (UI::IsItemHovered()) UI::SetTooltip("Max times the same sound plays consecutively in Random mode (1 = never repeats). Applies to the combined list of all enabled sounds.");
        if (tempRepeats != oldValue) {
            Setting_MaxConsecutiveRepeats = uint(Math::Clamp(tempRepeats, 1, 10));
            Debug::Print("Settings", "Max Random Repeats changed to: " + Setting_MaxConsecutiveRepeats);
        }
    }
}

void RenderDefaultSoundsHeader() {
    UI::Dummy(vec2(0, 10));
    UI::SeparatorText("Default Sounds (Packaged with Plugin)");
}

void RenderLocalCustomSoundsHeader() {
    UI::Dummy(vec2(0, 10));
    UI::SeparatorText("Local Custom Sounds (Your Files)");
}

void RenderLocalCustomSoundsFooter() {
    UI::Dummy(vec2(0, 5));
    string customPath = SoundPlayer::g_userLocalSoundsFolder;
    UI::TextWrapped("Place custom sounds (.ogg, .wav, .mp3) in:");
    UI::PushItemWidth(-200);
    UI::InputText("##LocalCustomSoundPath", customPath, UI::InputTextFlags::ReadOnly);
    UI::PopItemWidth();
    if (UI::IsItemHovered()) { UI::SetTooltip("Right-click to copy path"); if (UI::IsMouseClicked(UI::MouseButton::Right)) { IO::SetClipboard(customPath); UI::ShowNotification("Path copied!"); }}

    if (UI::Button("Open Local Sounds Folder")) {
        if (!IO::FolderExists(customPath)) { try { IO::CreateFolder(customPath, true); } catch {} }
        OpenExplorerPath(customPath);
    }
    UI::SameLine();
    if (UI::Button("Reload Local Sounds")) {
        SoundPlayer::ReloadLocalCustomSounds();
        // --- SUCCESS NOTIFICATION ---
        string localSoundSuccessHeader = Icons::CheckCircle + " Success";
        string localSoundSuccessMessage = "Local custom sounds reloaded!";
        vec4 successBgColor = vec4(0.2f, 0.6f, 0.25f, 0.9f); 
        UI::ShowNotification(localSoundSuccessHeader, localSoundSuccessMessage, successBgColor, 4000); 
    }
}

void RenderRemoteSoundsHeader() {
    UI::Dummy(vec2(0, 10));
    UI::SeparatorText("Remote Sounds");
}

void RenderRemoteSoundsFooter() {
    UI::Dummy(vec2(0, 10));
    UI::Separator();
    UI::TextDisabled("Manage actual downloads and see full list in the 'Downloaded Sounds' tab.");
}

void RenderRemoteCustomSoundsFooter() {
    UI::Dummy(vec2(0, 5));
    UI::TextDisabled("Remote sounds are downloaded to: ");
    UI::SameLine();
    UI::PushItemWidth(-200);
    UI::InputText("##DownloadedSoundsPath", SoundPlayer::g_downloadedSoundsFolder, UI::InputTextFlags::ReadOnly);
    UI::PopItemWidth();
    if (UI::IsItemHovered()) { UI::SetTooltip("Right-click to copy path"); if (UI::IsMouseClicked(UI::MouseButton::Right)) { IO::SetClipboard(SoundPlayer::g_downloadedSoundsFolder); UI::ShowNotification("Path copied!"); }}

    UI::SameLine();
    if (UI::Button("Open Folder##DL", vec2(100, 0))) { // Unique ID for button
        if (!IO::FolderExists(SoundPlayer::g_downloadedSoundsFolder)) { try { IO::CreateFolder(SoundPlayer::g_downloadedSoundsFolder, true); } catch {} }
        OpenExplorerPath(SoundPlayer::g_downloadedSoundsFolder);
    }


}

// Stat Box Headers
void RenderBoxControlsHeader() { UI::SeparatorText("General Box Controls"); UI::Dummy(vec2(0, 5)); }
void RenderBoxAppearanceHeader() { UI::Separator(); UI::Dummy(vec2(0, 5)); UI::Text("Box Position & Size (When Locked)"); UI::Dummy(vec2(0, 5)); }
void RenderStatVisibilityHeader() { UI::Separator(); UI::Dummy(vec2(0, 10)); UI::SeparatorText("Stats to Display"); UI::Dummy(vec2(0, 5)); }
void RenderResetPositionButton() {
    UI::Dummy(vec2(0, 5));
    if (UI::Button("Reset Window Position & Size")) {
        Setting_GUIPosX = 50.0f; Setting_GUIPosY = 50.0f;
        Setting_GUIWidth = 250.0f; Setting_GUIHeight = 98.0f;
        string guiResetSuccessHeader = Icons::CheckCircle + " Success";
        string guiResetSuccessMessage = "Stat Box position/size reset!";
        vec4 successBgColor = vec4(0.2f, 0.6f, 0.25f, 0.9f); 
        UI::ShowNotification(guiResetSuccessHeader, guiResetSuccessMessage, successBgColor, 4000); 
    }
    if (UI::IsItemHovered()) UI::SetTooltip("**Only works when \"Lock Stat Box Window\" is enabled.**\nResets to default position/size.");
    UI::Dummy(vec2(0, 10));
}

// --- Custom UI Rendering for Sound Toggles in the main "Sound" tab ---

// This function will be called from the new [SettingsTab name="Sound"] RenderSoundSettingsTab
// to manually render the default sound toggles.
void RenderDefaultSoundTogglesList() {
    if (!Setting_EnableDefaultSounds) {
        UI::TextDisabled(" (Default sounds master toggle is off)");
        return;
    }
    UI::SetNextItemOpen(true, UI::Cond::Appearing);
    if (!UI::CollapsingHeader("Manage Default Sounds##Defaults")) return;
    UI::Indent();
    if (SoundPlayer::g_defaultSounds.Length == 0) { UI::TextDisabled("(No default sounds loaded)"); }

    for (uint i = 0; i < SoundPlayer::g_defaultSounds.Length; i++) {
        SoundPlayer::SoundInfo@ sf = SoundPlayer::g_defaultSounds[i];
        if (sf is null) continue;

        // Get the current state from the actual Setting_ variable
        string settingName = sf.defaultSoundSettingVarName; 
        bool currentEnabled = SoundPlayer::GetSettingBool(settingName, true);

        if (UI::Checkbox(sf.displayName + "##default_toggle_" + i, currentEnabled)) {
            // Update the actual Setting_ variable
            SoundPlayer::SetSettingBool(settingName, !currentEnabled);
        }
    }
    UI::Unindent();
    UI::Dummy(vec2(0,5));
}

// --- Custom Tab for Managing Sound Downloads ---
[SettingsTab name="Download Sounds"]

void RenderRemoteSoundManagementTab() {
    UI::SeparatorText(Icons::InfoCircle + " Important Note");
    UI::PushStyleColor(UI::Col::Text, vec4(1.0f, 0.85f, 0.4f, 1.0f)); // Yellow/gold
    UI::TextWrapped("Sounds must be downloaded from this tab before they can be enabled.");
    UI::TextWrapped("Once downloaded, please enable the sound in the main 'Sound' settings tab.");
    UI::Dummy(vec2(0,2));
    UI::Separator();
    UI::PopStyleColor();
    UI::Dummy(vec2(0,5));

    // Row for Refresh List and Reload Downloaded Status
    if (UI::BeginTable("RemoteActionsTable", 2, UI::TableFlags::SizingStretchProp)) {
        UI::TableNextRow();
        UI::TableNextColumn();
        if (UI::Button(Icons::Refresh + " Refresh Sound List from Server")) {
            SoundPlayer::RequestRefreshRemoteSoundList();
            UI::ShowNotification("Refreshing sound list from server...");
        }
        if(UI::IsItemHovered()){ UI::SetTooltip("Pretty useless tbh.\nFetches the latest list of available remote sounds from files.shikes.space.");}

        UI::TableNextColumn();
        if (UI::Button(Icons::FolderOpen + " Reload Downloaded Status")) {
            SoundPlayer::RefreshDownloadedSoundsStatus();
            string refreshDownloadSuccessHeader = Icons::CheckCircle + " Success";
            string refreshDownloadSuccessMessage = " Refreshed status of downloaded sounds!";
            vec4 successBgColor = vec4(0.2f, 0.6f, 0.25f, 0.9f); 
            UI::ShowNotification(refreshDownloadSuccessHeader, refreshDownloadSuccessMessage, successBgColor, 5000);
        }
        if(UI::IsItemHovered()){ UI::SetTooltip("Re-scans the 'DownloadedSounds' folder.\nUseful if you manually removed files.");}

        UI::EndTable();
    }
    UI::Dummy(vec2(0,5));

    UI::Separator();

    if (SoundPlayer::g_remoteSounds.Length == 0) {
        UI::TextDisabled("(No remote sounds defined or list failed to fetch. Try refreshing.)");
        return;
    }

    // Table for listing sounds and their download actions
    if (UI::BeginTable("RemoteSoundsListTable", 2, UI::TableFlags::Borders | UI::TableFlags::RowBg | UI::TableFlags::SizingStretchProp)) {
        UI::TableSetupColumn("Sound Name (Filename)");
        UI::TableSetupColumn("Status / Action", UI::TableColumnFlags::WidthStretch, 0.45f);
        UI::TableHeadersRow();

        for (uint i = 0; i < SoundPlayer::g_remoteSounds.Length; i++) {
            SoundPlayer::SoundInfo@ sf = SoundPlayer::g_remoteSounds[i];
            if (sf is null) continue;

            UI::TableNextRow(); // Specify min_row_height here if needed: UI::TableNextRow(UI::TableRowFlags::None, 30.0f);
            UI::TableNextColumn();
            UI::Dummy(vec2(0, 1));
            UI::Text(sf.displayName);
            UI::SameLine();
            UI::TextDisabled(" (" + sf.remoteFilename + ")");
            // UI::Dummy(vec2(0, 2));

            UI::TableNextColumn(); // This is the "Status / Action" column
            string btnLabel = "";
            bool btnDisabled = false; // Used to disable the main action button if status is shown instead
            vec4 btnColor = UI::GetStyleColor(UI::Col::Button);

            switch (sf.loadState) {
                case SoundPlayer::SoundLoadState::Idle:
                    btnLabel = Icons::CloudDownload + " Download";
                    if (sf.isDownloaded) {
                        btnLabel = Icons::Refresh + " Re-download";
                    }
                    break;
                case SoundPlayer::SoundLoadState::Downloading:
                    btnLabel = Icons::Spinner + " Downloading...";
                    btnDisabled = true;
                    break;
                case SoundPlayer::SoundLoadState::Downloaded:
                    // Example: [Text: " Downloaded ✓"] [Button: 🔄]
                    UI::AlignTextToFramePadding();
                    UI::PushStyleColor(UI::Col::Text, vec4(0.2f, 0.8f, 0.2f, 1.0f)); // Green text for status
                    UI::Text(" Downloaded " + Icons::Check);
                    UI::PopStyleColor();
                    UI::SameLine();

                    btnLabel = Icons::Refresh + "";
                    if (UI::Button(btnLabel + "##re-dl"+i)) {
                        SoundPlayer::RequestDownloadRemoteSound(i);
                    }
                    if(UI::IsItemHovered()){ UI::SetTooltip("Re-download " + sf.displayName); }


                    btnDisabled = true; // Don't show the main action button for this state
                    break;

                case SoundPlayer::SoundLoadState::LoadFailed_Download:
                    btnLabel = Icons::ExclamationTriangle + " Download Failed";
                    btnColor = vec4(0.8f, 0.2f, 0.2f, 1.0f); // Reddish
                    break;

                case SoundPlayer::SoundLoadState::LoadFailed_Sample:
                    // Order: [Text: " Downloaded ✓"] [Text: "⚠️(Sample Load Fail)"] [Button: 🔄]
                    if (sf.isDownloaded) {
                        UI::AlignTextToFramePadding(); // Align first text part
                        UI::Text(" Downloaded " + Icons::Check);
                        UI::SameLine();

                        UI::AlignTextToFramePadding(); // Align second text part
                        UI::PushStyleColor(UI::Col::Text, vec4(0.8f, 0.2f, 0.2f, 1.0f)); // Red for error
                        UI::Text(" " + Icons::ExclamationTriangle + "(Sample Load Fail)");
                        UI::PopStyleColor();
                        UI::SameLine();

                        btnLabel = Icons::Refresh + "";
                        if (UI::Button(btnLabel + "##re-dl"+i, vec2(UI::GetFrameHeight(), UI::GetFrameHeight()))){
                             SoundPlayer::RequestDownloadRemoteSound(i);
                        }
                        if(UI::IsItemHovered()){ UI::SetTooltip("Re-download " + sf.displayName + " (sample load failed). This might fix the issue."); }

                        btnDisabled = true; // Don't show the main action button
                    } else {
                        // This state (LoadFailed_Sample but not isDownloaded) should ideally not occur.
                        // If it does, it means there was an attempt to load a sample for a non-downloaded file,
                        // which LoadAudioSample should prevent.
                        btnLabel = Icons::ExclamationTriangle + " Error (Load Fail)";
                        btnColor = vec4(0.8f, 0.2f, 0.2f, 1.0f);
                    }
                    break;
            }

            // This renders the main action button (e.g., "Download", "Download Failed")
            // It's skipped if btnDisabled was set to true (i.e., for Downloaded or specific LoadFailed_Sample states)
            if (!btnDisabled) {
                UI::PushStyleColor(UI::Col::Button, btnColor);
                // No need to BeginDisabled/EndDisabled here if btnDisabled is false as button is just not rendered
                if (UI::Button(btnLabel + "##dl_" + i)) { // Auto-sized button
                    // Only allow action if not currently downloading
                    if (sf.loadState != SoundPlayer::SoundLoadState::Downloading) {
                        SoundPlayer::RequestDownloadRemoteSound(i);
                    }
                }
                UI::PopStyleColor();
            }
        } // End of for loop
        UI::EndTable();
        UI::Dummy(vec2(0,5));
        UI::InputText("##DownloadSoundPath", SoundPlayer::g_downloadedSoundsFolder, UI::InputTextFlags::ReadOnly);
        if (UI::IsItemHovered()) { UI::SetTooltip("Right-click to copy path"); if (UI::IsMouseClicked(UI::MouseButton::Right)) { IO::SetClipboard(SoundPlayer::g_downloadedSoundsFolder); UI::ShowNotification("Path copied!"); }}
        if (UI::Button("Open Downloaded Sounds Folder##DLPathBtn")) {
            if (!IO::FolderExists(SoundPlayer::g_downloadedSoundsFolder)) { try { IO::CreateFolder(SoundPlayer::g_downloadedSoundsFolder, true); } catch {} }
                OpenExplorerPath(SoundPlayer::g_downloadedSoundsFolder);
        }
        if(UI::IsItemHovered()){ UI::SetTooltip("Open the folder where remote sounds are downloaded.");}


    }
}


// --- Settings Lifecycle Callbacks ---
void OnSettingsChanged() {
    Debug::Print("Settings", "Settings changed.");
    for (uint i = 0; i < SoundPlayer::g_remoteSounds.Length; i++) {
        SoundPlayer::SoundInfo@ sf = SoundPlayer::g_remoteSounds[i];
        if (sf is null || !sf.isDownloaded) { // Check if NOT downloaded
            string settingName = SoundPlayer::GetRemoteSoundEnableSettingName(sf.remoteFilename);
            if (SoundPlayer::GetSettingBool(settingName, false)) { // If it was just enabled by the user
                SoundPlayer::SetSettingBool(settingName, false); // Force it back to false
                // --- CUSTOMIZED NOTIFICATION ---
                string errorHeader = Icons::ExclamationTriangle + " Could NOT enable sound!";
                string errorMessage = "\"" + sf.displayName + "\" is not downloaded.\nPlease download it first from the \"Download Sounds\" tab.";
                vec4 errorBgColor = vec4(0.7f, 0.15f, 0.15f, 0.9f); // Dark Red
                UI::ShowNotification(errorHeader, errorMessage, errorBgColor, 5000);
            }
        }
    }
    SoundPlayer::RebuildPlayableSoundsList();
}

// --- Reset Stats Tab ---
[SettingsTab name="Reset Stats"]
void RenderResetStatsTab() {
    UI::SeparatorText(Icons::InfoCircle + " Important Note");
    UI::PushStyleColor(UI::Col::Text, vec4(1.0f, 0.85f, 0.4f, 1.0f)); // Yellow/gold
    UI::TextWrapped("Use these buttons to reset tracked bonk statistics.");
    UI::PopStyleColor();
    UI::PushStyleColor(UI::Col::Text, vec4(0.7f, 0.15f, 0.15f, 0.9f)); // Yellow/gold
    UI::TextWrapped("Current stats will reset instantly - \"All-Time\" requires confirmation");
    UI::Dummy(vec2(0,2));
    UI::Separator();
    UI::PopStyleColor();
    UI::Dummy(vec2(0,5));
    UI::Text("Current Map Stats:"); UI::SameLine();
    if (UI::Button("Reset Map")) { ResetMapStats(); UI::ShowNotification("Current map stats reset!"); }
    if (UI::IsItemHovered()) UI::SetTooltip("Resets Bonks, Highest Speed, and Active Time for the current map only.");
    UI::Dummy(vec2(0, 5)); UI::Separator(); UI::Dummy(vec2(0, 5));
    UI::Text("Current Session Stats:"); UI::SameLine();
    if (UI::Button("Reset Session")) { ResetSessionStats(); UI::ShowNotification("Current session stats reset!"); }
    if (UI::IsItemHovered()) UI::SetTooltip("Resets Session Bonks and Last Bonk Speed since plugin load/enable.");
    UI::Dummy(vec2(0, 5)); UI::Separator(); UI::Dummy(vec2(0, 5));
    UI::Text("All-Time Stats:"); UI::SameLine();
    UI::PushStyleColor(UI::Col::Button, vec4(0.8f, 0.2f, 0.2f, 1.0f)); UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.9f, 0.3f, 0.3f, 1.0f)); UI::PushStyleColor(UI::Col::ButtonActive, vec4(1.0f, 0.4f, 0.4f, 1.0f));
    if (UI::Button("Reset All-Time")) { UI::OpenPopup("Confirm All-Time Reset"); }
    UI::PopStyleColor(3);
    if (UI::IsItemHovered()) UI::SetTooltip("WARNING: Resets total bonk count and highest speed across ALL sessions. Requires confirmation.");

    if (UI::BeginPopupModal("Confirm All-Time Reset", UI::WindowFlags::AlwaysAutoResize)) {
        UI::TextWrapped("You really want to reset your All-Time Bonk statistics?"); UI::Separator();
        UI::TextWrapped("Total bonk count: " + g_totalAllTimeBonks);
        string highestSpeedStr = (g_highestAllTimeBonkSpeedKmh > 0.1f) ? Text::Format("%.0f", g_highestAllTimeBonkSpeedKmh) : "N/A";
        UI::TextWrapped("Highest recorded bonk: " + highestSpeedStr + " Km/h"); UI::Separator();
        UI::PushStyleColor(UI::Col::Text, vec4(1.0f, 0.2f, 0.2f, 1.0f)); UI::Text("THIS ACTION CANNOT BE UNDONE."); UI::PopStyleColor(); UI::Separator();
        UI::PushStyleColor(UI::Col::Button, vec4(0.8f, 0.2f, 0.2f, 1.0f)); UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.9f, 0.3f, 0.3f, 1.0f)); UI::PushStyleColor(UI::Col::ButtonActive, vec4(1.0f, 0.4f, 0.4f, 1.0f));
        if (UI::Button("YES, RESET STATS", vec2(220, 0))) { ResetAllTimeStats(); UI::ShowNotification("All-Time stats reset!"); UI::CloseCurrentPopup(); }
        UI::PopStyleColor(3); UI::SameLine();
        if (UI::Button("Cancel", vec2(100, 0))) { UI::CloseCurrentPopup(); }
        UI::EndPopup();
    }
    UI::Dummy(vec2(0, 8)); UI::Separator();

}