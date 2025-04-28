// --- soundPlayer.as ---
// Manages loading, selecting, and playing bonk sound effects.

#include "settings" // Needed for settings access and Debug namespace

namespace SoundPlayer {

    // --- Sound Metadata Class ---
    class SoundInfo {
        string path;
        Audio::Sample@ sample = null;
        bool enabled = true;
        bool isCustom = false;
        string displayName;
        bool loadAttempted = false;
        bool loadFailed = false;
    }

    // --- State Variables ---
    array<SoundInfo> g_allSounds; // Master list
    int g_orderedSoundIndex = 0;
    string g_lastPlayedSoundPath = "";
    int g_consecutivePlayCount = 0;
    bool g_isInitialized = false;

    // --- Initialization ---
    void Initialize() {
        LoadSounds(); // Initial load
        g_isInitialized = true;
    }

    // --- Sound Loading ---
    void LoadSounds() {
        Debug::Print("Loading", "--- LoadSounds() ---");
        array<SoundInfo> newSounds;

        dictionary defaultSoundSettingsMap;
        defaultSoundSettingsMap["bonk.wav"] = Setting_Enable_bonkwav;
        defaultSoundSettingsMap["oof.wav"] = Setting_Enable_oofwav;
        defaultSoundSettingsMap["vineboom.mp3"] = Setting_Enable_vineboommp3;

        array<string> defaultSoundFiles = defaultSoundSettingsMap.GetKeys();
        Debug::Print("Loading", "Checking for default sound metadata: " + string::Join(defaultSoundFiles, ", "));

        for (uint i = 0; i < defaultSoundFiles.Length; i++) {
            string filename = defaultSoundFiles[i];
            // Check if file exists relative to the plugin root
            // NOTE: This assumes plugin files are accessible via relative paths directly.
            //       Using IO::FileSource is a good way to verify existence.
             IO::FileSource fs(filename);
             if (fs.EOF()) { // Check if file source is invalid/empty
                 warn("[Bonk++] Default sound file not found in plugin resources: '" + filename + "'");
                 continue; // Skip this file
             }

            SoundInfo info;
            info.path = filename;
            info.isCustom = false;
            info.displayName = filename;
            bool isEnabled = true;
            if (defaultSoundSettingsMap.Get(filename, isEnabled)) {
                info.enabled = isEnabled;
            } else {
                warn("[Bonk++] Setting mapping missing for default sound: " + filename);
                info.enabled = true;
            }
            info.loadAttempted = false;
            info.loadFailed = false;
            @info.sample = null;

            Debug::Print("Loading", "Found default sound metadata: '" + filename + "' (Enabled: " + info.enabled + ")");
            newSounds.InsertLast(info);
        }

        if (Setting_EnableCustomSounds) {
            string storageFolder = IO::FromStorageFolder(""); // Gets base storage folder path
            string customSoundFolder = Path::Join(storageFolder, "Sounds"); // Construct path to Sounds subfolder
            Debug::Print("Loading", "Checking for custom sound metadata in: " + customSoundFolder);

            if (!IO::FolderExists(customSoundFolder)) {
                Debug::Print("Loading", "... Custom sound folder does not exist, creating.");
                 try {
                    IO::CreateFolder(customSoundFolder);
                 } catch {
                     warn("[Bonk++] Failed to create custom sound folder: " + customSoundFolder + " - Error: " + getExceptionInfo());
                 }
            }

             // Defensive check after potential creation attempt
             if(IO::FolderExists(customSoundFolder)) {
                array<string>@ files = IO::IndexFolder(customSoundFolder, false); // false = non-recursive
                if (files !is null && files.Length > 0) {
                    Debug::Print("Loading", "Found " + files.Length + " potential custom sound files.");
                    for (uint i = 0; i < files.Length; i++) {
                        string fullPath = files[i];
                        string filename = Path::GetFileName(fullPath);
                        string extension = Path::GetExtension(filename).ToLower();

                        if (extension == ".ogg" || extension == ".wav" || extension == ".mp3") {
                            Debug::Print("Loading", "Processing potential sound metadata: " + filename);
                            SoundInfo info;
                            info.path = fullPath;
                            info.isCustom = true;
                            info.displayName = filename;
                            info.enabled = true; // Custom sounds are always enabled if master toggle is on
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
                 Debug::Print("Loading", "Custom sound folder still does not exist after attempting creation: " + customSoundFolder);
                 warn("[Bonk++] Custom sound folder could not be accessed or created: " + customSoundFolder);
            }
        } else {
            Debug::Print("Loading", "Custom sounds disabled by setting.");
        }

        // --- Sample Cache Invalidation ---
        // Before replacing g_allSounds, release handles to samples that are no longer needed
        // to allow Openplanet's audio system to potentially free memory.
        // NOTE: This assumes Audio::Sample uses reference counting. If a sample handle
        //       is still present in `newSounds`, its ref count won't drop to zero here.
        for (uint i = 0; i < g_allSounds.Length; i++) {
            @g_allSounds[i].sample = null; // Release the reference
        }
        // --- End Cache Invalidation ---


        g_allSounds = newSounds; // Replace master list
        g_lastPlayedSoundPath = ""; // Reset playback state
        g_consecutivePlayCount = 0;
        g_orderedSoundIndex = 0; // Reset ordered index too
        Debug::Print("Loading", "Finished LoadSounds. Total sound metadata entries: " + g_allSounds.Length);
        Debug::Print("Loading", "--------------------");
    }

    // --- Sound Playback ---
    void PlayBonkSound() {
         if (!g_isInitialized) Initialize(); // Safety init

        Debug::Print("Playback", "--- PlayBonkSound() ---");
        array<uint> enabledIndices;
        for (uint i = 0; i < g_allSounds.Length; i++) {
            if (g_allSounds[i].enabled && !g_allSounds[i].loadFailed) {
                enabledIndices.InsertLast(i);
            }
        }
        Debug::Print("Playback", "Found " + enabledIndices.Length + " enabled sounds.");

        if (enabledIndices.Length == 0) {
            warn("[Bonk++] No enabled sounds found to play.");
            Debug::Print("Playback", "-----------------------");
            return;
        }

        uint selectedIndexInMasterList = uint(-1);
        bool soundSelected = false;

        if (Setting_SoundPlaybackMode == SoundMode::Random) {
            uint potentialEnabledIndex = Math::Rand(0, enabledIndices.Length);
            uint potentialMasterIndex = enabledIndices[potentialEnabledIndex];
            string potentialPath = g_allSounds[potentialMasterIndex].path;

            if (enabledIndices.Length > 1 && potentialPath == g_lastPlayedSoundPath && g_consecutivePlayCount >= int(Setting_MaxConsecutiveRepeats)) {
                Debug::Print("Playback", "Constraint hit: '" + g_allSounds[potentialMasterIndex].displayName + "' played " + g_consecutivePlayCount + " times. Re-selecting.");
                int retryCount = 0; const int MAX_RETRIES = 10;
                while (potentialPath == g_lastPlayedSoundPath && retryCount < MAX_RETRIES) {
                    potentialEnabledIndex = Math::Rand(0, enabledIndices.Length);
                    potentialMasterIndex = enabledIndices[potentialEnabledIndex];
                    potentialPath = g_allSounds[potentialMasterIndex].path;
                    retryCount++;
                }
                if (potentialPath == g_lastPlayedSoundPath) {
                    warn("[Bonk++] Could not select different random sound after " + MAX_RETRIES + " retries.");
                }
            }
            selectedIndexInMasterList = potentialMasterIndex;
            soundSelected = true;
            Debug::Print("Playback", "Random mode selected index: " + potentialEnabledIndex + " (maps to g_allSounds index " + selectedIndexInMasterList + ").");

        } else { // Ordered Mode
            int count = int(enabledIndices.Length);
            g_orderedSoundIndex = g_orderedSoundIndex % count;
            if (g_orderedSoundIndex < count) {
                 selectedIndexInMasterList = enabledIndices[g_orderedSoundIndex];
                 soundSelected = true;
                 Debug::Print("Playback", "Ordered mode selected index: " + g_orderedSoundIndex + " (maps to g_allSounds index " + selectedIndexInMasterList + ").");
                 g_orderedSoundIndex = (g_orderedSoundIndex + 1) % count;
             } else {
                 warn("[Bonk++] Ordered index calculation error.");
             }
        }

        if (!soundSelected || selectedIndexInMasterList >= g_allSounds.Length) {
            warn("[Bonk++] Failed to select a valid sound index.");
            Debug::Print("Playback", "-----------------------");
            return;
        }

        string selectedPath = g_allSounds[selectedIndexInMasterList].path;
        if (selectedPath == g_lastPlayedSoundPath) {
            g_consecutivePlayCount++;
        } else {
            g_lastPlayedSoundPath = selectedPath;
            g_consecutivePlayCount = 1;
        }
        Debug::Print("Playback", "Consecutive count for '" + g_allSounds[selectedIndexInMasterList].displayName + "': " + g_consecutivePlayCount);

        // Load audio sample on demand
        // Create a temporary copy to modify, then assign back
        SoundInfo infoCopy = g_allSounds[selectedIndexInMasterList];
        if (infoCopy.sample is null && !infoCopy.loadAttempted) {
            Debug::Print("Playback", "Sample for '" + infoCopy.displayName + "' is null, attempting to load...");
            infoCopy.loadAttempted = true;
            Audio::Sample@ loadedSample = null;
            try {
                if (infoCopy.isCustom) {
                    @loadedSample = Audio::LoadSampleFromAbsolutePath(infoCopy.path);
                } else {
                    @loadedSample = Audio::LoadSample(infoCopy.path);
                }
             } catch {
                 warn("[Bonk++] EXCEPTION during sound loading for: '" + infoCopy.path + "' - Error: " + getExceptionInfo());
                 @loadedSample = null; // Ensure it's null on exception
             }

            @infoCopy.sample = loadedSample; // Assign loaded (or null) handle to copy

            if (infoCopy.sample is null) {
                warn("[Bonk++] Failed to load sample ON DEMAND for: '" + infoCopy.path + "'");
                infoCopy.loadFailed = true;
            } else {
                Debug::Print("Playback", "... Success.");
                infoCopy.loadFailed = false;
            }
            g_allSounds[selectedIndexInMasterList] = infoCopy; // Put the updated copy back
        }

        // Play the sound using the (potentially just loaded) sample handle from the master list
        if (g_allSounds[selectedIndexInMasterList].sample !is null && !g_allSounds[selectedIndexInMasterList].loadFailed) {
            Debug::Print("Playback", "Attempting to play: '" + g_allSounds[selectedIndexInMasterList].displayName + "' with volume " + Setting_BonkVolume + "%");
             Audio::Voice@ voice = null;
             try {
                 @voice = Audio::Play(g_allSounds[selectedIndexInMasterList].sample);
             } catch {
                 warn("[Bonk++] EXCEPTION during Audio::Play for: '" + g_allSounds[selectedIndexInMasterList].path + "' - Error: " + getExceptionInfo());
                 @voice = null; // Ensure null on exception
             }

            if (voice !is null) {
                 try {
                    voice.SetGain(float(Setting_BonkVolume) / 100.0f);
                    Debug::Print("Playback", "Sound played successfully.");
                 } catch {
                     warn("[Bonk++] EXCEPTION during voice.SetGain for: '" + g_allSounds[selectedIndexInMasterList].path + "' - Error: " + getExceptionInfo());
                 }
            } else {
                warn("[Bonk++] Audio::Play returned null voice for: '" + g_allSounds[selectedIndexInMasterList].path + "'.");
            }
        } else {
            // Only warn if we haven't already logged a load failure for this sound
            if (!g_allSounds[selectedIndexInMasterList].loadFailed) {
                warn("[Bonk++] Cannot play sound, sample handle is null or load failed. Path: '" + g_allSounds[selectedIndexInMasterList].path + "'");
            } else {
                 Debug::Print("Playback", "Skipping playback for previously failed sound: '" + g_allSounds[selectedIndexInMasterList].displayName + "'");
            }
        }
        Debug::Print("Playback", "-----------------------");
    }

} // namespace SoundPlayer