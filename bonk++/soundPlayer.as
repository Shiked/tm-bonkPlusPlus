// --- soundPlayer.as ---
// Manages loading sound metadata, selecting sounds based on settings,
// loading audio samples on demand, and playing them.

namespace SoundPlayer {

    // --- Sound Metadata Class ---
    // Stores information about each potential sound effect.
    class SoundInfo {
        string path;                // Full path (absolute for custom, relative like "Sounds/bonk.wav" for default)
        Audio::Sample@ sample = null; // Handle to the loaded audio data (@ indicates handle, null if not loaded)
        bool enabled = true;         // Whether this sound is currently enabled (based on settings)
        bool isCustom = false;        // True if loaded from PluginStorage, false if default plugin resource
        string displayName;         // User-friendly name (usually the filename)
        bool loadAttempted = false;   // Flag to prevent repeated load attempts if file is invalid/missing
        bool loadFailed = false;       // Flag set if loading failed, used to skip playback attempts
    }

    // --- State Variables ---
    // Global state for the sound player module
    array<SoundInfo> g_allSounds;        // Master list of all found/configured sounds
    int g_orderedSoundIndex = 0;         // Index for 'Ordered' playback mode
    string g_lastPlayedSoundPath = "";   // Path of the last sound played (for anti-repeat logic)
    int g_consecutivePlayCount = 0;      // Counter for consecutive plays of the same sound
    bool g_isInitialized = false;        // Flag to ensure initial LoadSounds call

    // --- Initialization ---
    /**
     * @desc Initializes the sound player module. Called on plugin load.
     */
    void Initialize() {
        LoadSounds(); // Perform initial scan and load metadata
        g_isInitialized = true;
    }

    // --- Sound Loading ---
    /**
     * @desc Scans for default and custom sound files, updates the internal list (`g_allSounds`),
     *       and applies enabled/disabled status based on settings. Does NOT load audio samples yet.
     *       Called by Initialize() and OnSettingsChanged().
     */
    void LoadSounds() {
        Debug::Print("Loading", "--- LoadSounds() ---");
        array<SoundInfo> newSounds; // Build a new list to replace the old one

        // 1. Process Default Sounds (defined within the plugin package)
        // Map default filenames to their enable settings for easy lookup
        dictionary defaultSoundSettingsMap;
        defaultSoundSettingsMap["bonk.wav"] = Setting_Enable_bonkwav;
        defaultSoundSettingsMap["oof.wav"] = Setting_Enable_oofwav;
        defaultSoundSettingsMap["vineboom.mp3"] = Setting_Enable_vineboommp3;

        array<string> defaultSoundFiles = defaultSoundSettingsMap.GetKeys();
        Debug::Print("Loading", "Checking for default sound metadata in 'Sounds/' folder: " + string::Join(defaultSoundFiles, ", "));

        for (uint i = 0; i < defaultSoundFiles.Length; i++) {
            string filename = defaultSoundFiles[i];
            string relativePath = "Sounds/" + filename; // Construct path relative to plugin root

            // Verify the file exists within the plugin's resources
            IO::FileSource fs(relativePath);
            if (fs.EOF()) { // EOF is true if the source couldn't be opened/is empty
                warn("[Bonk++] Default sound file not found in plugin resources: '" + relativePath + "'");
                continue; // Skip this file
            }

            // Create metadata entry
            SoundInfo info;
            info.path = relativePath;       // Store the relative path for loading later
            info.isCustom = false;
            info.displayName = filename;    // Use base filename for display/logs
            // Determine if enabled based on settings map
            bool isEnabled = true;          // Default to enabled if map lookup fails
            if (defaultSoundSettingsMap.Get(filename, isEnabled)) {
                info.enabled = isEnabled;
            } else {
                warn("[Bonk++] Setting mapping missing for default sound: " + filename);
                info.enabled = true; // Fallback
            }
            // Reset loading flags (important if reloading)
            info.loadAttempted = false;
            info.loadFailed = false;
            @info.sample = null; // Ensure sample handle is null initially

            Debug::Print("Loading", "Found default sound metadata: '" + info.displayName + "' at path '" + info.path + "' (Enabled: " + info.enabled + ")");
            newSounds.InsertLast(info); // Add to the temporary list
        }

        // 2. Process Custom Sounds (from user's PluginStorage folder)
        if (Setting_EnableCustomSounds) {
            string storageFolder = IO::FromStorageFolder(""); // Get base path like C:\Users\User\OpenplanetNext\PluginStorage\PluginID
            string customSoundFolder = Path::Join(storageFolder, "Sounds"); // Append "Sounds" subfolder
            Debug::Print("Loading", "Checking for custom sound metadata in: " + customSoundFolder);

            // Ensure the custom sounds directory exists, create if not
            if (!IO::FolderExists(customSoundFolder)) {
                Debug::Print("Loading", "- Custom sound folder does not exist, creating.");
                 try { IO::CreateFolder(customSoundFolder); }
                 catch { warn("[Bonk++] Failed to create custom sound folder: " + customSoundFolder + " - Error: " + getExceptionInfo()); }
            }

            // Proceed only if folder exists (or was successfully created)
             if(IO::FolderExists(customSoundFolder)) {
                // List files in the custom sound folder (non-recursively)
                array<string>@ files = IO::IndexFolder(customSoundFolder, false);
                if (files !is null && files.Length > 0) {
                    Debug::Print("Loading", "Found " + files.Length + " potential custom sound files.");
                    for (uint i = 0; i < files.Length; i++) {
                        string fullPath = files[i]; // IO::IndexFolder returns full paths
                        string filename = Path::GetFileName(fullPath);
                        string extension = Path::GetExtension(filename).ToLower();

                        // Check for supported audio file extensions
                        if (extension == ".ogg" || extension == ".wav" || extension == ".mp3") {
                            Debug::Print("Loading", "Processing potential sound metadata: " + filename);
                            // Create metadata entry
                            SoundInfo info;
                            info.path = fullPath;           // Store the full absolute path
                            info.isCustom = true;
                            info.displayName = filename;
                            info.enabled = true;            // Custom sounds enabled by the master toggle
                            info.loadAttempted = false;
                            info.loadFailed = false;
                            @info.sample = null;
                            Debug::Print("Loading", "  - Path: " + info.path);
                            newSounds.InsertLast(info);
                        } else {
                            Debug::Print("Loading", "Skipping non-supported file type: " + filename);
                        }
                    }
                } else {
                    Debug::Print("Loading", "No files found in custom sound folder: " + customSoundFolder);
                }
            } else {
                 Debug::Print("Loading", "Custom sound folder could not be accessed or created: " + customSoundFolder);
                 warn("[Bonk++] Custom sound folder could not be accessed or created: " + customSoundFolder);
            }
        } else {
            Debug::Print("Loading", "Custom sounds disabled by setting.");
        }

        // 3. Invalidate Old Sample Cache & Update Master List
        // Release references to samples held by the *old* list. If a sample is also
        // in the new list, its reference count won't drop to zero, preventing unnecessary unloading.
        for (uint i = 0; i < g_allSounds.Length; i++) {
            @g_allSounds[i].sample = null; // Release the handle reference
        }

        // Replace the global list with the newly constructed list
        g_allSounds = newSounds;
        // Reset playback state associated with the list
        g_lastPlayedSoundPath = "";
        g_consecutivePlayCount = 0;
        g_orderedSoundIndex = 0;
        Debug::Print("Loading", "Finished LoadSounds. Total sound metadata entries: " + g_allSounds.Length);
        Debug::Print("Loading", "--------------------");
    }

    // --- Sound Playback ---
    /**
     * @desc Selects an appropriate sound based on settings, loads it if necessary, and plays it.
     *       Called by main.as when a bonk occurs and the chance check passes.
     */
    void PlayBonkSound() {
        if (!g_isInitialized) Initialize(); // Safety check

        Debug::Print("Playback", "--- PlayBonkSound() ---");

        // 1. Filter for Enabled Sounds: Create a list of indices pointing to enabled sounds in g_allSounds.
        array<uint> enabledIndices;
        for (uint i = 0; i < g_allSounds.Length; i++) {
            // Only include if enabled by settings AND not previously failed to load
            if (g_allSounds[i].enabled && !g_allSounds[i].loadFailed) {
                enabledIndices.InsertLast(i);
            }
        }
        Debug::Print("Playback", "Found " + enabledIndices.Length + " enabled sounds.");

        // Exit if no sounds are available to play
        if (enabledIndices.Length == 0) {
            warn("[Bonk++] No enabled sounds found to play.");
            Debug::Print("Playback", "-----------------------");
            return;
        }

        // 2. Select Sound Index: Choose an index from `enabledIndices` based on playback mode.
        uint selectedIndexInMasterList = uint(-1); // Will hold the index within the main g_allSounds list
        bool soundSelected = false;

        if (Setting_SoundPlaybackMode == SoundMode::Random) {
            // Random Mode Logic
            uint potentialEnabledIndex = Math::Rand(0, enabledIndices.Length); // Pick random index from *enabled* list
            uint potentialMasterIndex = enabledIndices[potentialEnabledIndex];  // Get corresponding index in *master* list
            string potentialPath = g_allSounds[potentialMasterIndex].path;      // Get its path for comparison

            // Anti-repeat logic (only if more than one sound enabled)
            if (enabledIndices.Length > 1 && potentialPath == g_lastPlayedSoundPath && g_consecutivePlayCount >= int(Setting_MaxConsecutiveRepeats)) {
                Debug::Print("Playback", "Constraint hit: '" + g_allSounds[potentialMasterIndex].displayName + "' played " + g_consecutivePlayCount + " times. Re-selecting.");
                int retryCount = 0; const int MAX_RETRIES = 10; // Prevent potential infinite loop
                // Try finding a *different* sound
                while (potentialPath == g_lastPlayedSoundPath && retryCount < MAX_RETRIES) {
                    potentialEnabledIndex = Math::Rand(0, enabledIndices.Length);
                    potentialMasterIndex = enabledIndices[potentialEnabledIndex];
                    potentialPath = g_allSounds[potentialMasterIndex].path;
                    retryCount++;
                }
                if (potentialPath == g_lastPlayedSoundPath) { // Still the same after retries? Log it.
                    warn("[Bonk++] Could not select different random sound after " + MAX_RETRIES + " retries.");
                }
            }
            // Final selection (either original random pick or the re-selected one)
            selectedIndexInMasterList = potentialMasterIndex;
            soundSelected = true;
            Debug::Print("Playback", "Random mode selected index: " + potentialEnabledIndex + " (maps to g_allSounds index " + selectedIndexInMasterList + "). Path: " + g_allSounds[selectedIndexInMasterList].path);

        } else { // Ordered Mode Logic
            int count = int(enabledIndices.Length);
            g_orderedSoundIndex = g_orderedSoundIndex % count; // Wrap index around if it exceeds bounds
            if (g_orderedSoundIndex < count) {
                 selectedIndexInMasterList = enabledIndices[g_orderedSoundIndex]; // Map ordered index to master list index
                 soundSelected = true;
                 Debug::Print("Playback", "Ordered mode selected index: " + g_orderedSoundIndex + " (maps to g_allSounds index " + selectedIndexInMasterList + "). Path: " + g_allSounds[selectedIndexInMasterList].path);
                 g_orderedSoundIndex = (g_orderedSoundIndex + 1) % count; // Increment for next time, wrapping around
             } else {
                 warn("[Bonk++] Ordered index calculation error (index " + g_orderedSoundIndex + " >= count " + count + ")."); // Should not happen due to modulo
             }
        }

        // Check if a valid index was actually selected
        if (!soundSelected || selectedIndexInMasterList >= g_allSounds.Length) {
            warn("[Bonk++] Failed to select a valid sound index.");
            Debug::Print("Playback", "-----------------------");
            return;
        }

        // 3. Update Anti-Repeat State: Track consecutive plays.
        string selectedPath = g_allSounds[selectedIndexInMasterList].path;
        if (selectedPath == g_lastPlayedSoundPath) {
            g_consecutivePlayCount++; // Increment if same sound played again
        } else {
            g_lastPlayedSoundPath = selectedPath; // Store the new path
            g_consecutivePlayCount = 1; // Reset counter for the new sound
        }
        Debug::Print("Playback", "Consecutive count for '" + g_allSounds[selectedIndexInMasterList].displayName + "': " + g_consecutivePlayCount);

        // 4. On-Demand Audio Sample Loading: Load if not already loaded/attempted.
        //    Use copy-modify-replace strategy to safely update the array element.
        SoundInfo infoCopy = g_allSounds[selectedIndexInMasterList]; // Work on a copy
        if (infoCopy.sample is null && !infoCopy.loadAttempted) {
            Debug::Print("Playback", "Sample for '" + infoCopy.displayName + "' is null, attempting to load from path: " + infoCopy.path);
            infoCopy.loadAttempted = true; // Mark that we tried loading
            Audio::Sample@ loadedSample = null; // Temporary handle
            try {
                // Load from appropriate source based on type
                if (infoCopy.isCustom) {
                    // Custom sounds have absolute paths
                    @loadedSample = Audio::LoadSampleFromAbsolutePath(infoCopy.path);
                } else {
                    // Default sounds have relative paths ("Sounds/...")
                    @loadedSample = Audio::LoadSample(infoCopy.path);
                }
             } catch {
                 // Catch potential exceptions during loading (e.g., invalid file format)
                 warn("[Bonk++] EXCEPTION during sound loading for: '" + infoCopy.path + "' - Error: " + getExceptionInfo());
                 @loadedSample = null; // Ensure handle is null on error
             }

            @infoCopy.sample = loadedSample; // Store the result (handle or null) in the copy

            // Update flags based on loading result
            if (infoCopy.sample is null) {
                warn("[Bonk++] Failed to load sample ON DEMAND for: '" + infoCopy.path + "'");
                infoCopy.loadFailed = true;
            } else {
                Debug::Print("Playback", "- Success!");
                infoCopy.loadFailed = false;
            }
            // Write the modified copy (with updated sample handle and flags) back to the master array
            g_allSounds[selectedIndexInMasterList] = infoCopy;
        }

        // 5. Play Sound: If the sample handle is valid and loading didn't fail.
        //    Access the element directly from g_allSounds again, as it might have been updated above.
        if (g_allSounds[selectedIndexInMasterList].sample !is null && !g_allSounds[selectedIndexInMasterList].loadFailed) {
            Debug::Print("Playback", "Attempting to play: '" + g_allSounds[selectedIndexInMasterList].displayName + "' with volume " + Setting_BonkVolume + "%");
            Audio::Voice@ voice = null;
            try {
                // Play the audio sample
                @voice = Audio::Play(g_allSounds[selectedIndexInMasterList].sample);
             } catch {
                 // Catch potential exceptions during playback
                 warn("[Bonk++] EXCEPTION during Audio::Play for: '" + g_allSounds[selectedIndexInMasterList].path + "' - Error: " + getExceptionInfo());
                 @voice = null;
             }

            // If playback started successfully, set the volume
            if (voice !is null) {
                 try {
                    voice.SetGain(float(Setting_BonkVolume) / 100.0f); // Convert percentage to 0.0-1.0 range
                    Debug::Print("Playback", "Sound played successfully.");
                 } catch {
                     // Catch potential exceptions when setting gain
                     warn("[Bonk++] EXCEPTION during voice.SetGain for: '" + g_allSounds[selectedIndexInMasterList].path + "' - Error: " + getExceptionInfo());
                 }
            } else {
                // Log if Audio::Play failed
                warn("[Bonk++] Audio::Play returned null voice for: '" + g_allSounds[selectedIndexInMasterList].path + "'.");
            }
        } else {
            // Log why playback was skipped
            if (!g_allSounds[selectedIndexInMasterList].loadFailed) { // Only warn if we haven't already logged a load failure
                warn("[Bonk++] Cannot play sound, sample handle is null or load failed. Path: '" + g_allSounds[selectedIndexInMasterList].path + "'");
            } else {
                 Debug::Print("Playback", "Skipping playback for previously failed sound: '" + g_allSounds[selectedIndexInMasterList].displayName + "'");
            }
        }
        Debug::Print("Playback", "-----------------------");
    }

} // namespace SoundPlayer