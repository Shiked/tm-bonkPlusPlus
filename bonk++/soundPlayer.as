// --- soundPlayer.as ---
// Manages loading sound metadata, selecting sounds based on settings,
// loading audio samples on demand, and playing them using the Audio namespace.

namespace SoundPlayer {

    /**
     * Holds metadata for a single sound effect, including its path, loaded sample handle, enabled status, and loading state.
     */
    class SoundInfo {
        string path;                  // Full path (absolute for custom, relative like "Sounds/bonk.wav" for default).
        Audio::Sample@ sample = null; // Handle to the loaded audio data (null if not loaded).
        bool enabled = true;          // Whether this sound is currently considered active based on settings.
        bool isCustom = false;        // True if loaded from PluginStorage, false if default plugin resource.
        string displayName;           // User-friendly name, typically the filename.
        bool loadAttempted = false;   // Flag: true if a load attempt was made (prevents repeated attempts on failure).
        bool loadFailed = false;      // Flag: true if the last load attempt failed (skips playback attempts).
    }

    // --- Module State ---
    array<SoundInfo> g_allSounds;        // Master list containing metadata for all discovered sound files.
    int g_orderedSoundIndex = 0;         // Current index for 'Ordered' playback mode.
    string g_lastPlayedSoundPath = "";   // Path of the sound played most recently (for anti-repeat).
    int g_consecutivePlayCount = 0;      // How many times the last sound has played consecutively.
    bool g_isInitialized = false;        // Tracks if Initialize() has run.

    /**
     * Initializes the sound player module by performing an initial scan for sounds.
     *       Called on plugin load via main.as -> Main().
     */
    void Initialize() {
        LoadSounds(); // Scan for sounds and populate g_allSounds.
        g_isInitialized = true;
        Debug::Print("Loading", "SoundPlayer Initialized.");
    }

    /**
     * Scans for default sounds (packaged with the plugin) and custom sounds
     *       (in PluginStorage/Bonk++/Sounds/), updates the internal list `g_allSounds`,
     *       and applies enabled/disabled status based on settings.
     *       Crucially, this *only loads metadata*, not the actual audio samples.
     *       Called by Initialize() and main.as -> OnSettingsChanged().
     */
    void LoadSounds() {
        Debug::Print("Loading", "--- Scanning for Sound Files ---");
        array<SoundInfo> newSoundList; // Build a fresh list to replace the old one.

        // --- 1. Process Default Sounds ---
        // Map default filenames to their corresponding enable Setting variable name suffixes.
        dictionary defaultSoundSettingsMap;
        defaultSoundSettingsMap["bonk.wav"] = Setting_Enable_bonkwav;
        defaultSoundSettingsMap["oof.wav"] = Setting_Enable_oofwav;
        defaultSoundSettingsMap["vineboom.mp3"] = Setting_Enable_vineboommp3;
        // Add more default sounds here if needed.

        array<string> defaultSoundFiles = defaultSoundSettingsMap.GetKeys();
        Debug::Print("Loading", "Checking for default sounds in 'Sounds/': " + string::Join(defaultSoundFiles, ", "));

        for (uint i = 0; i < defaultSoundFiles.Length; i++) {
            string filename = defaultSoundFiles[i];
            string relativePath = "Sounds/" + filename; // Path relative to the plugin's root directory.

            // Verify the file exists within the plugin's own resources using FileSource.
            // FileSource attempts to open the file; EOF() is true if it failed or is empty.
            IO::FileSource fs(relativePath);
            if (fs.EOF()) {
                warn("[Bonk++] Default sound file not found in plugin resources: '" + relativePath + "'");
                continue; // Skip this file.
            }
            // Note: fs goes out of scope here, closing the source. We only needed it to check existence.

            // Create metadata entry for this default sound.
            SoundInfo info;
            info.path = relativePath; // Store relative path for loading via Audio::LoadSample.
            info.isCustom = false;
            info.displayName = filename;
            // Look up the corresponding setting to determine if this sound is enabled.
            bool isEnabledSetting = true; // Default to true if lookup fails.
            if (defaultSoundSettingsMap.Get(filename, isEnabledSetting)) {
                info.enabled = isEnabledSetting;
            } else {
                warn("[Bonk++] Setting mapping missing for default sound: " + filename + ". Defaulting to enabled.");
                info.enabled = true;
            }
            // Ensure loading flags and sample handle are reset (important if reloading settings).
            info.loadAttempted = false;
            info.loadFailed = false;
            @info.sample = null;

            Debug::Print("Loading", "Found default sound: '" + info.displayName + "' (Enabled: " + info.enabled + ")");
            newSoundList.InsertLast(info);
        }

        // --- 2. Process Custom Sounds ---
        if (Setting_EnableCustomSounds) {
            // Get the absolute path to the plugin's dedicated storage folder.
            string storageFolder = IO::FromStorageFolder(""); // e.g., C:\Users\User\OpenplanetNext\PluginStorage\Bonk++
            string customSoundFolder = Path::Join(storageFolder, "Sounds"); // Target subfolder.
            Debug::Print("Loading", "Checking for custom sounds in: " + customSoundFolder);

            // Ensure the custom sounds directory exists. Create it if necessary.
            if (!IO::FolderExists(customSoundFolder)) {
                Debug::Print("Loading", "- Custom sound folder does not exist. Attempting creation...");
                 try {
                     IO::CreateFolder(customSoundFolder, true); // Recursive creation.
                     Debug::Print("Loading", "- Custom sound folder created successfully.");
                 } catch {
                     warn("[Bonk++] Failed to create custom sound folder: '" + customSoundFolder + "'. Cannot load custom sounds. Error: " + getExceptionInfo());
                     // Skip custom sound loading if directory creation failed.
                 }
            }

            // Proceed only if the folder exists (or was successfully created).
             if (IO::FolderExists(customSoundFolder)) {
                // List files/folders within the custom sound folder (non-recursively).
                array<string>@ filesInFolder = IO::IndexFolder(customSoundFolder, false);
                if (filesInFolder !is null && filesInFolder.Length > 0) {
                    Debug::Print("Loading", "Found " + filesInFolder.Length + " items in custom folder. Processing files...");
                    for (uint i = 0; i < filesInFolder.Length; i++) {
                        string fullPath = filesInFolder[i]; // IO::IndexFolder returns absolute paths here.
                        string filename = Path::GetFileName(fullPath);
                        string extension = Path::GetExtension(filename).ToLower(); // Lowercase for comparison.

                        // Check if the file extension is supported.
                        if (extension == ".ogg" || extension == ".wav" || extension == ".mp3") {
                            Debug::Print("Loading", "Found custom sound file: '" + filename + "'");
                            // Create metadata entry.
                            SoundInfo info;
                            info.path = fullPath; // Store the full absolute path for loading.
                            info.isCustom = true;
                            info.displayName = filename;
                            info.enabled = true; // Enabled because the master custom toggle is on.
                            info.loadAttempted = false;
                            info.loadFailed = false;
                            @info.sample = null;
                            newSoundList.InsertLast(info);
                        } else {
                             // Silently ignore unsupported files unless debugging is enabled.
                             Debug::Print("Loading", "Skipping non-supported file type: '" + filename + "'");
                        }
                    }
                } else {
                    Debug::Print("Loading", "No files found in custom sound folder: " + customSoundFolder);
                }
            }
            // else: Folder doesn't exist and couldn't be created (warning already logged).
        } else {
            Debug::Print("Loading", "Custom sounds are disabled in settings.");
        }

        // --- 3. Update Master List & Reset State ---
        // Release references to samples held by the *previous* g_allSounds list.
        // If a sample is also present in the new list, its reference count won't drop to zero,
        // preventing unnecessary unloading/reloading by the Audio system.
        for (uint i = 0; i < g_allSounds.Length; i++) {
            @g_allSounds[i].sample = null; // Nullify the handle reference in the old list entry.
        }

        // Replace the global list with the newly constructed list.
        g_allSounds = newSoundList;

        // Reset playback state related to the list contents.
        g_lastPlayedSoundPath = "";
        g_consecutivePlayCount = 0;
        g_orderedSoundIndex = 0; // Reset ordered index.

        Debug::Print("Loading", "Sound scan complete. Total sound metadata entries: " + g_allSounds.Length);
    }

    /**
     * Selects a sound based on current settings (mode, enabled status),
     *       loads its audio sample if not already loaded, and plays it.
     *       Called by main.as when a bonk occurs and the chance check passes.
     */
    void PlayBonkSound() {
        // Ensure initialization has run (safety check).
        if (!g_isInitialized) Initialize();

        // --- 1. Filter for Playable Sounds ---
        // Create a temporary list of indices pointing to sounds in g_allSounds
        // that are currently enabled and haven't failed loading previously.
        array<uint> enabledIndices;
        for (uint i = 0; i < g_allSounds.Length; i++) {
            if (g_allSounds[i].enabled && !g_allSounds[i].loadFailed) {
                enabledIndices.InsertLast(i);
            }
        }
        Debug::Print("Playback", "Found " + enabledIndices.Length + " enabled and loadable sounds.");

        // Exit if no sounds are available.
        if (enabledIndices.Length == 0) {
            warn("[Bonk++] No enabled sounds found or all failed to load. Cannot play sound.");
            return;
        }

        // --- 2. Select Sound Index ---
        // This index will point into the main g_allSounds list.
        uint selectedIndexInMasterList = uint(-1); // Initialize to an invalid index.
        bool soundSelected = false;

        if (Setting_SoundPlaybackMode == SoundMode::Random) {
            // -- Random Mode --
            uint potentialEnabledIndex = Math::Rand(0, enabledIndices.Length); // Pick from enabled list.
            uint potentialMasterIndex = enabledIndices[potentialEnabledIndex];  // Map to master list index.
            string potentialPath = g_allSounds[potentialMasterIndex].path;

            // Apply anti-repeat constraint if needed.
            if (enabledIndices.Length > 1 && potentialPath == g_lastPlayedSoundPath && g_consecutivePlayCount >= int(Setting_MaxConsecutiveRepeats)) {
                Debug::Print("Playback", "Anti-repeat constraint hit for '" + g_allSounds[potentialMasterIndex].displayName + "' (played " + g_consecutivePlayCount + "/" + Setting_MaxConsecutiveRepeats + " times). Retrying selection...");
                int retryCount = 0; const int MAX_RETRIES = 10; // Limit retries.
                // Try to find a *different* sound.
                while (potentialPath == g_lastPlayedSoundPath && retryCount < MAX_RETRIES) {
                    potentialEnabledIndex = Math::Rand(0, enabledIndices.Length);
                    potentialMasterIndex = enabledIndices[potentialEnabledIndex];
                    potentialPath = g_allSounds[potentialMasterIndex].path;
                    retryCount++;
                }
                if (potentialPath == g_lastPlayedSoundPath) {
                    warn("[Bonk++] Could not select a different random sound after " + MAX_RETRIES + " retries. Playing repeat.");
                } else {
                    Debug::Print("Playback", "Anti-repeat retry selected different sound: '" + g_allSounds[potentialMasterIndex].displayName + "'");
                }
            }
            // Final selection for Random mode.
            selectedIndexInMasterList = potentialMasterIndex;
            soundSelected = true;
            Debug::Print("Playback", "Random mode selected: '" + g_allSounds[selectedIndexInMasterList].displayName + "' (Master Index: " + selectedIndexInMasterList + ")");

        } else { // Setting_SoundPlaybackMode == SoundMode::Ordered
            // -- Ordered Mode --
            int count = int(enabledIndices.Length);
            // Ensure the ordered index wraps around the number of *enabled* sounds.
            g_orderedSoundIndex = g_orderedSoundIndex % count;
            selectedIndexInMasterList = enabledIndices[g_orderedSoundIndex]; // Map ordered index to master list index.
            soundSelected = true;
            Debug::Print("Playback", "Ordered mode selected: '" + g_allSounds[selectedIndexInMasterList].displayName + "' (Master Index: " + selectedIndexInMasterList + ", Ordered Index: " + g_orderedSoundIndex + ")");
            // Increment and wrap the ordered index for the *next* call.
            g_orderedSoundIndex = (g_orderedSoundIndex + 1) % count;
        }

        // Validate the selected index (should always be valid if enabledIndices > 0).
        if (!soundSelected || selectedIndexInMasterList >= g_allSounds.Length) {
            warn("[Bonk++] Internal error: Failed to select a valid sound index.");
            return;
        }

        // --- 3. Update Anti-Repeat State ---
        string selectedPath = g_allSounds[selectedIndexInMasterList].path;
        if (selectedPath == g_lastPlayedSoundPath) {
            g_consecutivePlayCount++; // Increment if the same sound is playing again.
        } else {
            g_lastPlayedSoundPath = selectedPath; // Store the new path.
            g_consecutivePlayCount = 1;          // Reset counter for the new sound.
        }
        Debug::Print("Playback", "Consecutive play count for '" + g_allSounds[selectedIndexInMasterList].displayName + "': " + g_consecutivePlayCount);

        // --- 4. On-Demand Audio Sample Loading ---
        // Check if the sample needs loading (is null) and hasn't failed loading before.
        // Directly modify the element in g_allSounds. Handles are reference counted, so this is safe.
        if (g_allSounds[selectedIndexInMasterList].sample is null && !g_allSounds[selectedIndexInMasterList].loadAttempted) {
            string pathToLoad = g_allSounds[selectedIndexInMasterList].path;
            string displayName = g_allSounds[selectedIndexInMasterList].displayName;
            bool isCustom = g_allSounds[selectedIndexInMasterList].isCustom;

            Debug::Print("Playback", "Sample for '" + displayName + "' not loaded. Attempting load from: " + pathToLoad);
            g_allSounds[selectedIndexInMasterList].loadAttempted = true; // Mark attempt even before try-catch.

            Audio::Sample@ loadedSample = null; // Temporary handle.
            try {
                // Use the correct Audio loading function based on whether it's a custom or default sound.
                if (isCustom) {
                    @loadedSample = Audio::LoadSampleFromAbsolutePath(pathToLoad); // Absolute path for custom.
                } else {
                    @loadedSample = Audio::LoadSample(pathToLoad); // Relative path for default.
                }
             } catch {
                 warn("[Bonk++] EXCEPTION during sound loading for: '" + pathToLoad + "'. Error: " + getExceptionInfo());
                 @loadedSample = null; // Ensure handle is null on error.
             }

            // Assign the loaded sample (or null if failed) back to the array element.
            @g_allSounds[selectedIndexInMasterList].sample = loadedSample;

            // Update the loadFailed flag based on the result.
            if (loadedSample is null) {
                warn("[Bonk++] Failed to load sample for: '" + pathToLoad + "'. Sound disabled.");
                g_allSounds[selectedIndexInMasterList].loadFailed = true;
            } else {
                Debug::Print("Playback", "- Sample loaded successfully for '" + displayName + "'.");
                g_allSounds[selectedIndexInMasterList].loadFailed = false;
            }
        }

        // --- 5. Play Sound ---
        // Check again if the sample is valid and loading didn't fail (might have failed in step 4).
        if (g_allSounds[selectedIndexInMasterList].sample !is null && !g_allSounds[selectedIndexInMasterList].loadFailed) {
            string displayName = g_allSounds[selectedIndexInMasterList].displayName;
            Debug::Print("Playback", "Playing sound: '" + displayName + "' (Volume: " + Setting_BonkVolume + "%)");

            Audio::Voice@ voice = null; // Handle for the playing sound instance.
            try {
                // Play the audio sample.
                @voice = Audio::Play(g_allSounds[selectedIndexInMasterList].sample);
             } catch {
                 warn("[Bonk++] EXCEPTION during Audio::Play for: '" + g_allSounds[selectedIndexInMasterList].path + "'. Error: " + getExceptionInfo());
                 @voice = null;
             }

            // If playback initiated successfully, set the volume.
            if (voice !is null) {
                 try {
                    // Convert volume setting (0-100) to gain (0.0-1.0).
                    voice.SetGain(float(Setting_BonkVolume) / 100.0f);
                    Debug::Print("Playback", "- Sound played successfully.");
                 } catch {
                     warn("[Bonk++] EXCEPTION during voice.SetGain for: '" + g_allSounds[selectedIndexInMasterList].path + "'. Error: " + getExceptionInfo());
                 }
            } else {
                // Log if Audio::Play failed to return a voice handle.
                warn("[Bonk++] Audio::Play returned null voice handle for: '" + g_allSounds[selectedIndexInMasterList].path + "'.");
            }
        } else {
            // Log why playback was skipped if the sample is invalid or loading failed.
            if (!g_allSounds[selectedIndexInMasterList].loadFailed) { // Avoid repeating the load failure warning.
                warn("[Bonk++] Cannot play sound: Sample handle is null for '" + g_allSounds[selectedIndexInMasterList].path + "'.");
            } else {
                 Debug::Print("Playback", "Skipping playback for previously failed sound: '" + g_allSounds[selectedIndexInMasterList].displayName + "'");
            }
        }
    }

} // namespace SoundPlayer