// --- Bonk++ Plugin ---
// Version: 1.0.2
// Description: Detects car crashes (bonks) using filtered jerk calculation,
//              plays sound effects (.wav, .ogg, .mp3) from default and custom folders,
//              and displays a configurable visual vignette effect.
//              Includes robust respawn detection using MLFeed (optional).

// --- Settings ---

// General Settings for enabling features and controlling sound playback probability/volume
[Setting category="General" name="Enable Sound Effect" description="Play a sound when you bonk."]
bool Setting_EnableSound = true;
[Setting category="General" name="Enable Visual Effect" description="Show a visual effect when you bonk."]
bool Setting_EnableVisual = true;
[Setting category="General" name="Bonk Chance (%)" description="Probability (0-100%) that a sound will play on bonk." min=0 max=100]
uint Setting_BonkChance = 100;
[Setting category="General" name="Bonk Volume (%)" description="Volume for bonk sound effects." min=0 max=100]
uint Setting_BonkVolume = 69; // Nice.

// Detection Settings for tuning crash sensitivity and cooldown
[Setting category="Detection" name="Preliminary Accel Threshold" description="Initial deceleration required (lower = more sensitive). Base value for dynamic threshold." min=1.0 max=100.0]
float Setting_BonkThreshold = 16.0f;
[Setting category="Detection" name="Sensitivity (Grounded)" description="Jerk magnitude threshold when 4 wheels are grounded (higher = less sensitive)." min=1.0 max=50.0]
float Setting_SensitivityGrounded = 4.0f;
[Setting category="Detection" name="Sensitivity (Airborne/Less Contact)" description="Jerk magnitude threshold when < 4 wheels are grounded (higher = less sensitive)." min=1.0 max=50.0]
float Setting_SensitivityAirborne = 4.0f;
[Setting category="Detection" name="Bonk Debounce (ms)" description="Minimum time in milliseconds between bonks." min=300 max=5000]
uint Setting_BonkDebounce = 500;


// Sound Settings controlling playback behavior and which sounds are active
enum SoundMode { Random, Ordered }
[Setting category="Sound" name="Sound Playback Mode" description="How to select the next sound effect."]
SoundMode Setting_SoundPlaybackMode = SoundMode::Random;
[Setting category="Sound" name="Max Consecutive Repeats (Random)" description="Max times the same sound plays consecutively in Random mode (1 = never repeats)." min=1 max=5]
uint Setting_MaxConsecutiveRepeats = 3;
[Setting category="Sound" name="Enable Custom Sounds" description="Load sound files from the PluginStorage folder."]
bool Setting_EnableCustomSounds = true;
[Setting category="Sound" name="Enable bonk.wav" description="Enable the default bonk.wav sound."]
bool Setting_Enable_bonkwav = true;
[Setting category="Sound" name="Enable oof.wav" description="Enable the default oof.wav sound."]
bool Setting_Enable_oofwav = true;
// The afterrender attribute calls RenderSoundCategoryFooter after this setting is drawn
[Setting category="Sound" name="Enable vineboom.mp3" description="Enable the default vineboom.mp3 sound." afterrender="RenderSoundCategoryFooter"]
bool Setting_Enable_vineboommp3 = true;

// Visual Settings for customizing the crash vignette effect
[Setting category="Visual" name="Duration (ms)" description="How long the visual effect lasts." min=50 max=2000]
uint Setting_VisualDuration = 420; // Funny numbers
[Setting category="Visual" name="Color" color description="Color of the visual effect vignette."]
vec3 Setting_VisualColor = vec3(1.0f, 0.0f, 0.0f); // Default Red
[Setting category="Visual" name="Max Opacity" description="Maximum opacity/intensity of the effect (0.0 to 1.0)." min=0.0 max=1.0]
float Setting_VisualMaxOpacity = 0.696f; // Specific nice.
[Setting category="Visual" name="Feather (Width %)" description="How far the gradient spreads inwards (fraction of screen width)." min=0.0 max=1.0]
float Setting_VisualFeather = 0.1f; // Adjusted default
[Setting category="Visual" name="Radius (Height %)" description="Rounding of the gradient shape corners (fraction of screen height)." min=0.0 max=1.0]
float Setting_VisualRadius = 0.2f; // Adjusted default

// Misc. Settings for enabling detailed debug logs
[Setting category="Misc." name="Enable Debug Logging" description="Show detailed logs for debugging."]
bool Setting_Debug_EnableMaster = false;
[Setting category="Misc." name="Debug: Crash Detection" if=Setting_Debug_EnableMaster description="Log details about impact detection."]
bool Setting_Debug_Crash = false;
[Setting category="Misc." name="Debug: Sound Loading" if=Setting_Debug_EnableMaster description="Log details about finding and loading sound files."]
bool Setting_Debug_Loading = false;
[Setting category="Misc." name="Debug: Sound Playback" if=Setting_Debug_EnableMaster description="Log details about sound selection and playback attempts."]
bool Setting_Debug_Playback = false;


// --- Global State Variables ---
// Used for crash detection calculations
vec3 g_previousVel = vec3(0, 0, 0);
float g_previousSpeed = 0.0f;
vec3 g_previousVdt = vec3(0, 0, 0); // Stores the filtered velocity change from the previous frame
// Used for debouncing bonk events
uint64 g_lastBonkTime = 0;
// Used for ordered sound playback
int g_orderedSoundIndex = 0;
// Used for visual effect rendering state
bool g_visualActive = false;
uint64 g_visualStartTime = 0;
// Used for random sound anti-repeat logic
string g_lastPlayedSoundPath = "";
int g_consecutivePlayCount = 0;


// --- Sound Management ---
// Holds metadata about a sound file and its cached audio sample handle
class SoundInfo {
    string path;             // Full path for custom, filename for default
    Audio::Sample@ sample = null; // Handle to the loaded audio data (null until loaded)
    bool enabled = true;      // Read from settings during LoadSounds
    bool isCustom = false;     // Flag indicating if it's from PluginStorage
    string displayName;      // Filename used for display
    bool loadAttempted = false; // Prevents repeated load attempts if a file is invalid
    bool loadFailed = false;    // Set if loading fails, used to skip playback attempts
}
// Master list containing metadata for all found/enabled sounds
array<SoundInfo> g_allSounds;

// -- Debug Logging Helper --
// Prints message to log if master debug and category debug flags are enabled
void Dbg_Print(const string &in category, const string &in message) {
    if (!Setting_Debug_EnableMaster) return;
    bool categoryEnabled = false;
    if (category == "Crash" && Setting_Debug_Crash) categoryEnabled = true;
    else if (category == "Loading" && Setting_Debug_Loading) categoryEnabled = true;
    else if (category == "Playback" && Setting_Debug_Playback) categoryEnabled = true;
    if (categoryEnabled) {
        print("[Bonk++ DBG:" + category + "] " + message);
    }
}

// -- Plugin Lifecycle & Callbacks --
// Main entry point, called once when the plugin is loaded or reloaded
void Main() {
    LoadSounds(); // Initial load of sound metadata based on settings
    print("Bonk++ Plugin Loaded! v" + Meta::ExecutingPlugin().Version);
}

// Called when the plugin is enabled via UI or code
void OnEnable() {
    print("Bonk++ Enabled");
    // Consider whether state needs resetting here (if disabling/enabling is common)
}

// Called when the plugin is disabled via UI or code
void OnDisable() {
    print("Bonk++ Disabled");
    g_visualActive = false; // Ensure visual effect stops if disabled mid-effect
}

// Helper to count wheels currently touching a non-null surface
int GetWheelContactCount(CSceneVehicleVisState@ visState) {
    if (visState is null) return 0;
    // Check each wheel's contact material ID. XXX_Null means no contact or airborne.
    return
        (visState.FLGroundContactMaterial != CSceneVehicleVisState::EPlugSurfaceMaterialId::XXX_Null ? 1 : 0) +
        (visState.FRGroundContactMaterial != CSceneVehicleVisState::EPlugSurfaceMaterialId::XXX_Null ? 1 : 0) +
        (visState.RLGroundContactMaterial != CSceneVehicleVisState::EPlugSurfaceMaterialId::XXX_Null ? 1 : 0) +
        (visState.RRGroundContactMaterial != CSceneVehicleVisState::EPlugSurfaceMaterialId::XXX_Null ? 1 : 0);
}

// Main detection loop, called every frame
void Update(float dt) {
    // Need the VehicleState dependency for this
    CSceneVehicleVisState@ visState = VehicleState::ViewingPlayerState();
    if (visState is null) {
        // Reset state if we lose the vehicle visualization
        g_previousVel = vec3(0,0,0); g_previousSpeed = 0.0f; g_previousVdt = vec3(0,0,0);
        return;
    }

    vec3 currentVel = visState.WorldVel;
    float currentSpeed = currentVel.Length();
    // Ensure dtSeconds is not zero to prevent division errors
    float dtSeconds = dt > 0.0f ? (dt / 1000.0f) : 0.016f; // Use a small default if dt is 0

    // --- Primary Respawn Check using MLFeed (if available) ---
    // This is the most reliable way to detect respawns immediately.
#if DEPENDENCY_MLFEEDRACEDATA && DEPENDENCY_MLHOOK
    auto mlf = MLFeed::GetRaceData_V3();
    if (mlf !is null) {
        auto plf = mlf.GetPlayer_V3(MLFeed::LocalPlayersName);
        if (plf !is null) {
        // Check if player isn't fully spawned OR if the time since last respawn is very short
        // Use '<' instead of '!=' for validity checks to avoid compiler warnings
        const uint INVALID_TIME = 0xFFFFFFFF;
        bool lastTimeValid = (plf.LastRespawnRaceTime < INVALID_TIME);
        bool currentTimeValid = (plf.CurrentRaceTime < INVALID_TIME);
        // Check threshold only if both times are valid
        bool isRecentRespawn = (lastTimeValid && currentTimeValid && plf.CurrentRaceTime < (plf.LastRespawnRaceTime + uint(100)));

        // Combine spawn status check with the recent respawn check
        if (plf.spawnStatus != MLFeed::SpawnStatus::Spawned || isRecentRespawn) {
            Dbg_Print("Crash", "MLFeed detected Not Spawned ("+plf.spawnStatus+") or Recent Respawn ("+isRecentRespawn+"). Resetting state.");
            g_previousVel = vec3(0,0,0);
            g_previousSpeed = 0.0f;
            g_previousVdt = vec3(0,0,0);
            g_lastBonkTime = Time::Now; // Reset debounce timer
            return; // Exit immediately, skip bonk detection this frame
        }
    }

    }
#endif
    // --- End of MLFeed Check ---
    // If MLFeed isn't available, we rely on the speed check below and debounce timer.

    // --- Bonk Detection Logic ---

    // 1. Preliminary Deceleration Check:
    //    Calculates instantaneous deceleration.
    //    Compares against a dynamic threshold that increases with speed.
    float currentAccel = (dtSeconds > 0) ? Math::Max(0.0f, (g_previousSpeed - currentSpeed) / dtSeconds) : 0.0f;
    float dynamicThreshold = Setting_BonkThreshold + g_previousSpeed * 1.5f;
    bool preliminaryBonkDetected = currentAccel > dynamicThreshold;

    // 2. Filtered Jerk Calculation (Change in filtered acceleration):
    //    Only calculated if preliminary check passes (or debug is on) for efficiency.
    //    Filters out vertical bumps and forward deceleration (braking).
    float jerkMagnitude = 0.0f;
    vec3 vdt_Filtered = vec3(0,0,0); // Initialize to zero
    if (preliminaryBonkDetected || (Setting_Debug_EnableMaster && Setting_Debug_Crash)) {
        vec3 vdt = currentVel - g_previousVel;          // Velocity change
        float vdtUp = Math::Dot(vdt, visState.Up);      // Get vertical component
        vec3 vdt_NoVertical = vdt - visState.Up * vdtUp;// Remove vertical component
        vdt_Filtered = vdt_NoVertical;                  // Store this potentially useful value
        float forwardComponent = Math::Dot(vdt_NoVertical, visState.Dir); // Get forward component
        if (forwardComponent > 0) {                     // If moving forward (not braking/reversing)
            vdt_Filtered = vdt_NoVertical - visState.Dir * forwardComponent; // Remove forward component
        }
        // Calculate Jerk: Change in filtered velocity change between frames
        vec3 vdtdt = vdt_Filtered - g_previousVdt;
        jerkMagnitude = vdtdt.Length();

        if (preliminaryBonkDetected) {
             Dbg_Print("Crash", "Preliminary Detect Passed! Accel: " + currentAccel + ", DynThresh: " + dynamicThreshold);
             Dbg_Print("Crash", "  -> Jerk Mag (vdtdt.Length): " + jerkMagnitude);
        }
    }

    // 3. Sensitivity Check based on Wheel Contact:
    //    Use different thresholds depending on how many wheels are grounded.
    int wheelContactCount = GetWheelContactCount(visState);
    float sensitivityThreshold = (wheelContactCount == 4) ? Setting_SensitivityGrounded : Setting_SensitivityAirborne;

    // 4. Final Bonk Condition Check:
    //    All conditions must be met: preliminary detection, jerk sensitivity,
    //    sufficient speed before impact, and debounce timer elapsed.
    uint64 currentTime = Time::Now;
    bool debounceOk = (currentTime - g_lastBonkTime) > Setting_BonkDebounce;
    bool speedOk = g_previousSpeed > 10.0f; // Ensure we weren't crawling before the potential impact
    bool sensitivityOk = jerkMagnitude > sensitivityThreshold;

    if (preliminaryBonkDetected && sensitivityOk && speedOk && debounceOk)
    {
        g_lastBonkTime = currentTime; // Reset debounce timer
        Dbg_Print("Crash", "Bonk CONFIRMED! JerkMag: " + jerkMagnitude + " > SensThresh: " + sensitivityThreshold);
        // Trigger sound effects based on chance
        if (Setting_EnableSound) {
            Dbg_Print("Playback", "Sound Enabled. Checking chance...");
            if (Math::Rand(0, 100) < int(Setting_BonkChance)) {
                Dbg_Print("Playback", "Chance success! Calling PlayBonkSound...");
                PlayBonkSound();
            } else { Dbg_Print("Playback", "Chance failed (Probability)."); }
        } else { Dbg_Print("Playback", "Sound Disabled (Setting)."); }
        // Trigger visual effect
        if (Setting_EnableVisual) { TriggerVisualEffect(); }
    }
    // Log reasons for not bonking if preliminary check passed (for debugging)
    else if (preliminaryBonkDetected && Setting_Debug_Crash) {
         if (!sensitivityOk) Dbg_Print("Crash", "Bonk IGNORED: Jerk Magnitude (" + jerkMagnitude + ") <= Sensitivity Threshold (" + sensitivityThreshold + ")");
        else if (!speedOk) Dbg_Print("Crash", "Bonk IGNORED: Previous Speed (" + g_previousSpeed + ") <= 10");
        else if (!debounceOk) Dbg_Print("Crash", "Bonk IGNORED: Debounce Active (LastBonk: " + g_lastBonkTime + ", Now: " + currentTime + ")");
        else Dbg_Print("Crash", "Bonk IGNORED: Unknown reason (Conditions: prelim=" + preliminaryBonkDetected + ", sens=" + sensitivityOk + ", speed=" + speedOk + ", debounce=" + debounceOk + ")");
    }

    // --- Update State for Next Frame ---
    // This happens *after* all checks, using the current frame's data
    g_previousVel = currentVel;
    g_previousSpeed = currentSpeed;
    g_previousVdt = vdt_Filtered; // Store the filtered vdt calculated *this* frame
}

// --- Render visual effect ---
// Draws a screen-wide vignette gradient using NanoVG
void Render() {
    // Only render if enabled and active
    if (!Setting_EnableVisual || !g_visualActive) {
        if (g_visualActive) { g_visualActive = false; } // Ensure flag is reset if disabled mid-effect
        return;
    }
    uint64 currentTime = Time::Now;
    uint64 elapsed = currentTime - g_visualStartTime;

    // Deactivate if duration is over
    if (elapsed >= Setting_VisualDuration) {
        g_visualActive = false;
        return;
    }

    // Calculate current alpha based on progress (fades out)
    float progress = (Setting_VisualDuration > 0) ? (float(elapsed) / float(Setting_VisualDuration)) : 1.0f;
    float currentAlpha = Setting_VisualMaxOpacity * (1.0f - progress);
    currentAlpha = Math::Clamp(currentAlpha, 0.0f, 1.0f); // Clamp to valid range

    // Get screen dimensions
    float w = float(Draw::GetWidth());
    float h = float(Draw::GetHeight());

    // Setup NanoVG drawing
    nvg::BeginPath();
    nvg::Rect(0, 0, w, h); // Define the full screen area

    // Calculate gradient parameters based on settings
    float radius = h * Setting_VisualRadius;   // Corner rounding based on screen height
    float feather = w * Setting_VisualFeather; // Gradient feathering based on screen width

    // Create the gradient paint (transparent center -> colored edges)
    nvg::Paint gradient = nvg::BoxGradient(
                              vec2(0,0),      // Top-left corner
                              vec2(w,h),      // Bottom-right corner (size)
                              radius,         // Corner rounding
                              feather,        // Feather width
                              vec4(0,0,0,0),  // Inner color (fully transparent)
                              vec4(Setting_VisualColor.x, Setting_VisualColor.y, Setting_VisualColor.z, currentAlpha) // Outer color (user color with current alpha)
                          );

    // Fill the screen rectangle with the gradient
    nvg::FillPaint(gradient);
    nvg::Fill();
    // nvg::ClosePath(); // Not strictly necessary after Fill
}

// --- Sound Handling ---

// Loads metadata for all potential sound files based on settings.
// Does not load actual audio samples; that happens on demand in PlayBonkSound.
void LoadSounds() {
    Dbg_Print("Loading", "--- LoadSounds() ---");
    array<SoundInfo> newSounds; // Temporary list to build

    // Map default sound filenames to their corresponding enable settings
    dictionary defaultSoundSettingsMap;
    defaultSoundSettingsMap["bonk.wav"] = Setting_Enable_bonkwav;
    defaultSoundSettingsMap["oof.wav"] = Setting_Enable_oofwav;
    defaultSoundSettingsMap["vineboom.mp3"] = Setting_Enable_vineboommp3;

    array<string> defaultSoundFiles = defaultSoundSettingsMap.GetKeys();
    Dbg_Print("Loading", "Checking for default sound metadata: " + string::Join(defaultSoundFiles, ", "));

    // Process default sounds
    for (uint i = 0; i < defaultSoundFiles.Length; i++) {
        string filename = defaultSoundFiles[i];
        // Check if the file exists within the plugin's resources
        IO::FileSource fs(filename);
        if (fs.EOF()) { // Check if file source is invalid/empty
            warn("[Bonk++] Default sound file not found in plugin resources: '" + filename + "'");
            continue; // Skip this file
        }
        // Create metadata object
        SoundInfo info;
        info.path = filename; // Store relative filename for default sounds
        info.isCustom = false;
        info.displayName = filename;
        // Get enabled status from the mapped setting
        bool isEnabled = true; // Default to true if mapping fails
        if (defaultSoundSettingsMap.Get(filename, isEnabled)) {
            info.enabled = isEnabled;
        } else {
            warn("[Bonk++] Setting mapping missing for default sound: " + filename);
            info.enabled = true; // Fallback to enabled
        }
        // Reset load status flags (important if reloading)
        info.loadAttempted = false;
        info.loadFailed = false;
        @info.sample = null; // Ensure sample is null initially

        Dbg_Print("Loading", "Found default sound metadata: '" + filename + "' (Enabled: " + info.enabled + ")");
        newSounds.InsertLast(info); // Add to temporary list
    }

    // Process custom sounds (if enabled)
    if (Setting_EnableCustomSounds) {
        string storageFolder = IO::FromStorageFolder("");
        string customSoundFolder = Path::Join(storageFolder, "Sounds"); // Use Path::Join
        Dbg_Print("Loading", "Checking for custom sound metadata in: " + customSoundFolder);

        // Ensure the custom sound folder exists
        if (!IO::FolderExists(customSoundFolder)) {
            Dbg_Print("Loading", "... Custom sound folder does not exist, creating.");
            IO::CreateFolder(customSoundFolder);
        }

        // Index the custom sound folder
        array<string>@ files = IO::IndexFolder(customSoundFolder, false); // false = non-recursive
        if (files !is null && files.Length > 0) {
            Dbg_Print("Loading", "Found " + files.Length + " potential custom sound files.");
            for (uint i = 0; i < files.Length; i++) {
                string fullPath = files[i]; // IndexFolder likely returns full paths here
                string filename = Path::GetFileName(fullPath);
                string extension = Path::GetExtension(filename).ToLower();

                // Check for supported audio extensions
                if (extension == ".ogg" || extension == ".wav" || extension == ".mp3") {
                    Dbg_Print("Loading", "Processing potential sound metadata: " + filename);
                    SoundInfo info;
                    info.path = fullPath; // Store the full absolute path
                    info.isCustom = true;
                    info.displayName = filename;
                    info.enabled = true; // Custom sounds are always considered enabled if master toggle is on
                    info.loadAttempted = false;
                    info.loadFailed = false;
                    @info.sample = null;
                    Dbg_Print("Loading", "  - Path: " + info.path);
                    newSounds.InsertLast(info);
                } else {
                    Dbg_Print("Loading", "Skipping non-supported file type: " + filename);
                }
            }
        } else {
            Dbg_Print("Loading", "No files found in custom sound folder: " + customSoundFolder);
        }
    } else {
        Dbg_Print("Loading", "Custom sounds disabled by setting.");
    }

    // Replace the global list with the newly built list
    g_allSounds = newSounds;
    // Reset playback state variables
    g_lastPlayedSoundPath = "";
    g_consecutivePlayCount = 0;
    Dbg_Print("Loading", "Finished LoadSounds. Total sound metadata entries: " + g_allSounds.Length);
    Dbg_Print("Loading", "--------------------");
}

// Selects an appropriate sound based on settings and plays it.
// Loads the audio sample on demand if it hasn't been loaded yet.
void PlayBonkSound() {
    Dbg_Print("Playback", "--- PlayBonkSound() ---");

    // 1. Create a list of indices of sounds that are currently enabled
    array<uint> enabledIndices;
    for (uint i = 0; i < g_allSounds.Length; i++) {
        // Check the 'enabled' flag (set during LoadSounds) and if loading hasn't failed previously
        if (g_allSounds[i].enabled && !g_allSounds[i].loadFailed) {
            enabledIndices.InsertLast(i);
        }
    }
    Dbg_Print("Playback", "Found " + enabledIndices.Length + " enabled sounds.");

    if (enabledIndices.Length == 0) {
        warn("[Bonk++] No enabled sounds found to play.");
        Dbg_Print("Playback", "-----------------------"); // Use Dbg_Print for consistency
        return;
    }

    // 2. Select an index from the enabled list based on the playback mode
    uint selectedIndexInMasterList = uint(-1); // Index in the main g_allSounds array
    bool soundSelected = false;

    if (Setting_SoundPlaybackMode == SoundMode::Random) {
        uint potentialEnabledIndex = Math::Rand(0, enabledIndices.Length); // Get random index from enabled list
        uint potentialMasterIndex = enabledIndices[potentialEnabledIndex]; // Map to index in g_allSounds
        string potentialPath = g_allSounds[potentialMasterIndex].path;

        // Anti-repeat logic: If only one sound is enabled, skip this check.
        // If the randomly chosen sound is the same as the last one AND we've hit the consecutive limit...
        if (enabledIndices.Length > 1 && potentialPath == g_lastPlayedSoundPath && g_consecutivePlayCount >= int(Setting_MaxConsecutiveRepeats)) {
            Dbg_Print("Playback", "Constraint hit: '" + g_allSounds[potentialMasterIndex].displayName + "' played " + g_consecutivePlayCount + " times. Re-selecting.");
            int retryCount = 0; const int MAX_RETRIES = 10; // Limit retries to prevent infinite loops
            // Try finding a different sound
            while (potentialPath == g_lastPlayedSoundPath && retryCount < MAX_RETRIES) {
                potentialEnabledIndex = Math::Rand(0, enabledIndices.Length);
                potentialMasterIndex = enabledIndices[potentialEnabledIndex];
                potentialPath = g_allSounds[potentialMasterIndex].path;
                retryCount++;
            }
            // If we still couldn't find a different one (unlikely unless only 1 sound enabled), log a warning
            if (potentialPath == g_lastPlayedSoundPath) {
                warn("[Bonk++] Could not select different random sound after " + MAX_RETRIES + " retries.");
            }
        }
        selectedIndexInMasterList = potentialMasterIndex; // Use the finally selected index
        soundSelected = true;
        Dbg_Print("Playback", "Random mode selected index: " + potentialEnabledIndex + " (maps to g_allSounds index " + selectedIndexInMasterList + ").");

    } else { // Ordered Mode
        int count = int(enabledIndices.Length); // Cast length for modulo
        g_orderedSoundIndex = g_orderedSoundIndex % count; // Ensure index is within bounds
         if (g_orderedSoundIndex < count) {
             selectedIndexInMasterList = enabledIndices[g_orderedSoundIndex]; // Map ordered index to master list index
             soundSelected = true;
             Dbg_Print("Playback", "Ordered mode selected index: " + g_orderedSoundIndex + " (maps to g_allSounds index " + selectedIndexInMasterList + ").");
             g_orderedSoundIndex = (g_orderedSoundIndex + 1) % count; // Increment for next time
         } else {
             warn("[Bonk++] Ordered index calculation error."); // Should not happen with modulo
         }
    }

    // Ensure we successfully selected an index
    if (!soundSelected || selectedIndexInMasterList >= g_allSounds.Length) {
        warn("[Bonk++] Failed to select a valid sound index.");
        Dbg_Print("Playback", "-----------------------");
        return;
    }

    // 3. Update anti-repeat state tracking
    string selectedPath = g_allSounds[selectedIndexInMasterList].path;
    if (selectedPath == g_lastPlayedSoundPath) {
        g_consecutivePlayCount++; // Increment if same sound as last time
    } else {
        g_lastPlayedSoundPath = selectedPath; // Reset if different sound
        g_consecutivePlayCount = 1;
    }
    Dbg_Print("Playback", "Consecutive count for '" + g_allSounds[selectedIndexInMasterList].displayName + "': " + g_consecutivePlayCount);

    // 4. Load audio sample if it hasn't been loaded/attempted yet
    //    Use copy-modify-replace to update the g_allSounds array element
    SoundInfo infoCopy = g_allSounds[selectedIndexInMasterList]; // Get a copy
    if (infoCopy.sample is null && !infoCopy.loadAttempted) {
        Dbg_Print("Playback", "Sample for '" + infoCopy.displayName + "' is null, attempting to load...");
        infoCopy.loadAttempted = true; // Mark that we tried loading
        Audio::Sample@ loadedSample = null; // Temporary handle for the loaded sample
        // Load from correct location based on flag
        if (infoCopy.isCustom) {
            @loadedSample = Audio::LoadSampleFromAbsolutePath(infoCopy.path);
        } else {
            @loadedSample = Audio::LoadSample(infoCopy.path); // Path is filename for defaults
        }
        @infoCopy.sample = loadedSample; // Store the handle (or null if failed) in the copy
        // Update failure flag based on result
        if (infoCopy.sample is null) {
            warn("[Bonk++] Failed to load sample ON DEMAND for: '" + infoCopy.path + "'");
            infoCopy.loadFailed = true;
        } else {
            Dbg_Print("Playback", "... Success.");
            infoCopy.loadFailed = false;
        }
        // Assign the potentially modified copy (with sample handle and flags) back to the array
        g_allSounds[selectedIndexInMasterList] = infoCopy;
    }

    // 5. Play the sound if the sample is valid
    //    Access the potentially updated element directly from g_allSounds
    if (g_allSounds[selectedIndexInMasterList].sample !is null && !g_allSounds[selectedIndexInMasterList].loadFailed) {
        Dbg_Print("Playback", "Attempting to play: '" + g_allSounds[selectedIndexInMasterList].displayName + "' with volume " + Setting_BonkVolume + "%");
        // Play the sample handle stored in the array element
        Audio::Voice@ voice = Audio::Play(g_allSounds[selectedIndexInMasterList].sample);
        if (voice !is null) {
            // Apply volume setting
            voice.SetGain(float(Setting_BonkVolume) / 100.0f);
            Dbg_Print("Playback", "Sound played successfully.");
        } else {
            // This usually indicates an issue with the audio engine or the sample data
            warn("[Bonk++] Audio::Play returned null voice for: '" + g_allSounds[selectedIndexInMasterList].path + "'. Sample might be invalid or audio engine issue?");
        }
    } else {
        // Log only if loading hasn't already failed (to avoid spamming logs)
        if (!g_allSounds[selectedIndexInMasterList].loadFailed) {
            warn("[Bonk++] Cannot play sound, sample handle is null or load failed. Path: '" + g_allSounds[selectedIndexInMasterList].path + "'");
        }
    }
    Dbg_Print("Playback", "-----------------------");
}


// TriggerVisualEffect
void TriggerVisualEffect() { g_visualActive = true; g_visualStartTime = Time::Now; }

// --- Settings Handling ---

// Renders info about custom sounds after the last default sound setting
void RenderSoundCategoryFooter() {
    UI::Separator();
    UI::TextWrapped("Place custom sound files (.ogg, .wav, .mp3) in the folder below. They will be loaded automatically if 'Enable Custom Sounds' is checked above.");
    string customPath = IO::FromStorageFolder("Sounds/");

    // Display path read-only, allow right-click copy
    UI::InputText("Custom Sound Path", customPath, UI::InputTextFlags::ReadOnly);
    if (UI::IsItemHovered()) {
        UI::SetTooltip("Right-click to copy path");
        if (UI::IsMouseClicked(UI::MouseButton::Right)) {
             IO::SetClipboard(customPath);
             UI::ShowNotification("Path copied to clipboard!");
        }
    }

    // Buttons on the same line
    UI::SameLine();
    if (UI::Button("Open Folder")) {
        // Ensure folder exists before trying to open it
        if (!IO::FolderExists(customPath)) {
             Dbg_Print("Loading", "Creating custom sound folder for 'Open Folder' button: " + customPath);
             IO::CreateFolder(customPath);
         }
        OpenExplorerPath(customPath); // Open regardless of creation result
     }
     UI::SameLine();
     if (UI::Button("Reload Sounds")) {
        LoadSounds(); // Reload metadata and apply enabled states from settings
     }
}

// Reload sounds whenever a relevant setting changes
void OnSettingsChanged() {
    Dbg_Print("Loading", "Settings changed, reloading sounds...");
    LoadSounds();
}

// Standard empty callbacks - No custom saving/loading needed anymore
void OnSettingsLoad(Settings::Section& section) {}
void OnSettingsSave(Settings::Section& section) {}