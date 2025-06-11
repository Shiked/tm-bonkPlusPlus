// --- soundPlayer.as ---
// Manages loading sound metadata, selecting sounds based on settings,
// downloading remote sounds, loading audio samples, and playing them.

namespace SoundPlayer {

    // --- Enums ---
    enum SoundSourceType { Default, LocalCustom, Remote }
    enum SoundLoadState { Idle, Downloading, Downloaded, LoadFailed_Download, LoadFailed_Sample }

    // --- Sound Metadata Class ---
    class SoundInfo {
        string displayName;         // User-friendly name
        string path;                // Relative for default, Absolute for local custom & downloaded remote
        SoundSourceType sourceType;
        Audio::Sample@ sample = null;
        bool isEnabledByUser = true; // User toggle from settings UI (persisted for remote/default)
        SoundLoadState loadState = SoundLoadState::Idle;
        bool isDownloaded = false; 
        
        // Remote-specific
        string remoteUrl = "";
        string remoteFilename = ""; // e.g. "another-one.mp3" (used for local filename)
        Net::HttpRequest@ activeDownloadRequest = null; // Handle to ongoing download
        string defaultSoundSettingVarName = ""; // e.g., "Setting_Enable_Default_bonkwav"
    }

    // --- Module State ---
    array<SoundInfo@> g_defaultSounds;      // Metadata for default sounds
    array<SoundInfo@> g_localCustomSounds;  // Metadata for user's local custom sounds
    array<SoundInfo@> g_remoteSounds;       // Metadata for remote sounds (from JSON)
    array<SoundInfo@> g_playableSounds;     // Combined, filtered list of sounds that can actually be played

    int g_orderedSoundIndex = 0;
    string g_lastPlayedPath = "";
    int g_consecutivePlayCount = 0;
    bool g_isInitialized = false;
    string g_downloadedSoundsFolder = "";
    string g_userLocalSoundsFolder = ""; 

    const string REMOTE_SOUND_LIST_URL = "https://file.shikes.space/api/bonkpp-sounds.json";
    const string REMOTE_SOUND_BASE_URL = "https://file.shikes.space/TM/BonkPP/";
    
    /**
     * Releases all loaded Audio::Sample handles and cancels active downloads.
     */
    void ProcessSoundListForRelease(array<SoundInfo@> &in soundList) {
        for (uint i = 0; i < soundList.Length; i++) {
            if (soundList[i].sample !is null) {
                @soundList[i].sample = null;
                 Debug::Print("SoundPlayer", "Released sample for: " + soundList[i].displayName);
            }
            if (soundList[i].activeDownloadRequest !is null) {
                // HttpRequest doesn't have an Abort(). It will complete but be ignored.
                @soundList[i].activeDownloadRequest = null;
                 Debug::Print("SoundPlayer", "Cleared active download request for: " + soundList[i].displayName);
            }
        }
    }

    /**
     * Re-scans the DownloadedSounds folder for already known remote sounds
     * and updates their isDownloaded and loadState status.
     * It does NOT re-fetch the JSON list from the server.
     */
    void RefreshDownloadedSoundsStatus() {
        Debug::Print("SoundPlayer", "Refreshing status of downloaded remote sounds...");
        if (g_remoteSounds.Length == 0) {
            Debug::Print("SoundPlayer", "No remote sounds defined, skipping refresh of downloaded status.");
            return;
        }

        bool changed = false;
        for (uint i = 0; i < g_remoteSounds.Length; i++) {
            SoundInfo@ sf = g_remoteSounds[i];
            if (sf is null || sf.sourceType != SoundSourceType::Remote) continue;

            bool previouslyDownloaded = sf.isDownloaded;
            string expectedLocalPath = Path::Join(g_downloadedSoundsFolder, sf.remoteFilename);

            if (IO::FileExists(expectedLocalPath)) {
                if (!sf.isDownloaded || sf.loadState == SoundLoadState::LoadFailed_Download) {
                    Debug::Print("SoundPlayer", "Found previously missing/failed download: " + sf.displayName);
                    changed = true;
                }
                sf.isDownloaded = true;
                // If it was Idle or failed download, now it's Downloaded.
                // If it was already Downloaded or Downloading (though unlikely to be downloading here), state remains.
                if (sf.loadState == SoundLoadState::Idle || sf.loadState == SoundLoadState::LoadFailed_Download) {
                     sf.loadState = SoundLoadState::Downloaded;
                }
                // If sample load had failed previously, but file now exists, reset sample load state
                // to allow a new attempt if LoadAudioSample is called.
                if (sf.loadState == SoundLoadState::LoadFailed_Sample) {
                    sf.loadState = SoundLoadState::Downloaded; // Reset to allow re-attempt of sample loading
                    @sf.sample = null; // Ensure sample is reloaded
                    Debug::Print("SoundPlayer", "Resetting sample load status for: " + sf.displayName + " (file found)");
                    changed = true;
                }

            } else { // File does not exist locally
                if (sf.isDownloaded) {
                    Debug::Print("SoundPlayer", "Previously downloaded sound no longer found: " + sf.displayName);
                    changed = true;
                }
                sf.isDownloaded = false;
                sf.loadState = SoundLoadState::Idle; // Or some other state indicating not available
                if (sf.sample !is null) {
                    @sf.sample = null; // Unload sample if file is gone
                    Debug::Print("SoundPlayer", "Unloaded sample for missing file: " + sf.displayName);
                    changed = true;
                }
            }
        }

        if (changed) {
            Debug::Print("SoundPlayer", "Downloaded sound statuses updated. Rebuilding playable list.");
            RebuildPlayableSoundsList();
        } else {
            Debug::Print("SoundPlayer", "No changes to downloaded sound statuses.");
        }
    }

    void ReleaseAllSamples() {
        ProcessSoundListForRelease(g_defaultSounds);
        ProcessSoundListForRelease(g_localCustomSounds);
        ProcessSoundListForRelease(g_remoteSounds);
        Debug::Print("SoundPlayer", "Released all audio samples and cleared download requests.");
    }

    // --- Initialization & Loading ---

    /**
     * Initializes the sound player module.
     */
    void Initialize() {
        if (g_isInitialized) { // If re-initializing, clear old data
            ReleaseAllSamples();
            g_defaultSounds.Resize(0);
            g_localCustomSounds.Resize(0);
            g_remoteSounds.Resize(0);
            g_playableSounds.Resize(0);
        }

        string basePluginStoragePath = IO::FromStorageFolder("");
        Debug::Print("SoundPlayer", "Base Plugin Storage Path: " + basePluginStoragePath);
        
        // Define and create the "DownloadedSounds" subfolder
        g_downloadedSoundsFolder = Path::Join(basePluginStoragePath, "DownloadedSounds/");
        if (!IO::FolderExists(g_downloadedSoundsFolder)) {
            try {
                IO::CreateFolder(g_downloadedSoundsFolder, true);
                Debug::Print("SoundPlayer", "Created DownloadedSounds folder: " + g_downloadedSoundsFolder);
            } catch {
                warn("[Bonk++] Failed to create DownloadedSounds folder: " + g_downloadedSoundsFolder + ". Error: " + getExceptionInfo());
            }
        }

        // Define and create the "LocalSounds" subfolder (renamed from "Sounds/")
        g_userLocalSoundsFolder = Path::Join(basePluginStoragePath, "LocalSounds/");
        if (!IO::FolderExists(g_userLocalSoundsFolder)) {
            try {
                IO::CreateFolder(g_userLocalSoundsFolder, true);
                Debug::Print("SoundPlayer", "Created LocalSounds folder: " + g_userLocalSoundsFolder);
            } catch {
                warn("[Bonk++] Failed to create LocalSounds folder: " + g_userLocalSoundsFolder + ". Error: " + getExceptionInfo());
            }
        }
        PopulateDefaultSoundList();
        ReloadLocalCustomSounds();
        startnew(Coroutine_FetchAndProcessRemoteSoundList);

        g_isInitialized = true;
        Debug::Print("SoundPlayer", "Module Initialized.");
    }

    void AddDefaultSound(const string &in filename) {
        string relativePath = "Sounds/" + filename;
        IO::FileSource fs(relativePath);
        if (fs.EOF()) {
            warn("[Bonk++] Default sound file not found in plugin resources: '" + relativePath + "'");
            return;
        }

        SoundInfo@ info = SoundInfo();
        info.displayName = filename;
        info.path = relativePath;
        info.sourceType = SoundSourceType::Default;
        info.loadState = SoundLoadState::Idle;
        g_defaultSounds.InsertLast(info);
        Debug::Print("SoundPlayer", "Added default sound: " + filename + ", Initial Enabled: " + info.isEnabledByUser);
    }

    void PopulateDefaultSoundList() {
        g_defaultSounds.Resize(0);
        Debug::Print("SoundPlayer", "Populating default sound list...");
        AddDefaultSound("bonk.wav");
        AddDefaultSound("oof.wav");
        AddDefaultSound("vineboom.mp3");
        RebuildPlayableSoundsList(); // Rebuild after populating
    }

    void ReloadLocalCustomSounds() {
        g_localCustomSounds.Resize(0); // Clear current before reloading
        Debug::Print("SoundPlayer", "Reloading local custom sounds from: " + g_userLocalSoundsFolder);

        if (!Setting_EnableLocalCustomSounds) {
            Debug::Print("SoundPlayer", "Local custom sounds are disabled by master setting.");
            RebuildPlayableSoundsList();
            return;
        }
        if (!IO::FolderExists(g_userLocalSoundsFolder)) {
            warn("[Bonk++] LocalSounds folder does not exist: " + g_userLocalSoundsFolder);
            RebuildPlayableSoundsList();
            return;
        }
        array<string>@ files = IO::IndexFolder(g_userLocalSoundsFolder, false);
        if (files !is null) {
            for (uint i = 0; i < files.Length; i++) {
                string fullPath = files[i];
                string filename = Path::GetFileName(fullPath);
                string ext = Path::GetExtension(filename).ToLower();
                if (ext == ".wav" || ext == ".ogg" || ext == ".mp3") {
                    SoundInfo@ info = SoundInfo();
                    info.displayName = filename;
                    info.path = fullPath;
                    info.sourceType = SoundSourceType::LocalCustom;
                    info.isEnabledByUser = true; // Always enabled if master toggle is on
                    info.loadState = SoundLoadState::Idle;
                    g_localCustomSounds.InsertLast(info);
                }
            }
        }
        Debug::Print("SoundPlayer", "Found " + g_localCustomSounds.Length + " local custom sounds in " + g_userLocalSoundsFolder);
        RebuildPlayableSoundsList();
    }

    void Coroutine_FetchAndProcessRemoteSoundList() {

        Debug::Print("SoundPlayer", "Fetching remote sound list from: " + REMOTE_SOUND_LIST_URL);
        ProcessSoundListForRelease(g_remoteSounds); // Release old remote samples/requests
        g_remoteSounds.Resize(0);

        Net::HttpRequest@ request = Net::HttpGet(REMOTE_SOUND_LIST_URL);
        yield(); // Allow request to start
        while (!request.Finished()) { yield(); }

        if (request.ResponseCode() == 200) {
            string responseString = request.String(); // Get the response string
            string responseExcerpt = responseString.SubStr(0, Math::Min(500, responseString.Length));
            Debug::Print("SoundPlayer", "Remote sound list HTTP 200. Response content (first " + responseExcerpt.Length + " chars): '''\n" + responseExcerpt + "\n'''");

            Json::Value@ jsonData = null;
            try {
                if (responseString.Trim().Length == 0) {
                    warn("[Bonk++] Remote sound list response string is empty. Cannot parse JSON.");
                } else {
                    @jsonData = Json::Parse(responseString);
                }
            } catch {
                warn("[Bonk++] EXCEPTION during Json::Parse for remote sound list. Error: " + getExceptionInfo());
            }

            if (jsonData !is null) {
                Json::Type parsedType = jsonData.GetType(); // Get the type of the parsed JSON root
                if (parsedType == Json::Type::Array) {
                    Debug::Print("SoundPlayer", "Remote sound list JSON parsed successfully as Array. Processing " + jsonData.Length + " entries.");
                    for (uint i = 0; i < jsonData.Length; i++) {
                        Json::Value@ item = jsonData[i];
                        if (item.GetType() == Json::Type::Object && item.HasKey("name") && item.HasKey("file")) {
                            string displayName = item["name"];
                            string remoteFilename = item["file"];

                            SoundInfo@ info = SoundInfo();
                            info.displayName = displayName;
                            info.remoteFilename = remoteFilename;
                            info.remoteUrl = REMOTE_SOUND_BASE_URL + remoteFilename;
                            info.path = Path::Join(g_downloadedSoundsFolder, remoteFilename);
                            info.sourceType = SoundSourceType::Remote;
                            info.loadState = SoundLoadState::Idle;

                            if (IO::FileExists(info.path)) {
                                info.isDownloaded = true;
                                info.loadState = SoundLoadState::Downloaded;
                            } else {
                                info.isDownloaded = false;
                            }
                            g_remoteSounds.InsertLast(info);
                        } else {
                            warn("[Bonk++] Malformed item in remote sound list JSON at index " + i + ". Expected Object with 'name' and 'file'. Got type: " + item.GetType());
                        }
                    }
                } else {
                    warn("[Bonk++] Remote sound list JSON root is not an Array. Parsed type: " + parsedType);
                }
            } else {
                warn("[Bonk++] Json::Parse returned null for remote sound list.");
            }
        } else {
            warn("[Bonk++] Failed to fetch remote sound list. HTTP: " + request.ResponseCode() + ", Error: " + request.Error());
        }
        RebuildPlayableSoundsList();
        Debug::Print("SoundPlayer", "Remote sound list processing finished. Total remote sounds: " + g_remoteSounds.Length);
    }


    /**
     * Ensures a specific remote sound is downloaded. Starts download if needed.
     */
    void EnsureRemoteSoundDownloaded(SoundInfo@ sf) {
        if (sf is null || sf.sourceType != SoundSourceType::Remote) return;
        if (sf.isDownloaded || sf.loadState == SoundLoadState::Downloading || sf.loadState == SoundLoadState::LoadFailed_Download) return;

        // Ensure downloaded sounds folder exists
        if (!IO::FolderExists(g_downloadedSoundsFolder)) {
            try {
                IO::CreateFolder(g_downloadedSoundsFolder, true);
            } catch {
                warn("[Bonk++] Failed to create downloaded sounds folder: " + g_downloadedSoundsFolder + ". Error: " + getExceptionInfo());
                sf.loadState = SoundLoadState::LoadFailed_Download;
                RebuildPlayableSoundsList();
                return;
            }
        }
        startnew(Coroutine_DownloadSingleSound, sf);
    }

    void Coroutine_DownloadSingleSound(ref userdata) {
        SoundInfo@ sf = cast<SoundInfo@>(userdata);
        if (sf is null) { warn("[Bonk++] Coroutine_DownloadSingleSound: userdata was null."); yield(); return; }
        if (sf.activeDownloadRequest !is null) { Debug::Print("SoundPlayer", "Download already in progress for " + sf.displayName); yield(); return; }

        Debug::Print("SoundPlayer", "Starting download for: " + sf.displayName + " from " + sf.remoteUrl);
        sf.loadState = SoundLoadState::Downloading;
        RebuildPlayableSoundsList();

        @sf.activeDownloadRequest = Net::HttpGet(sf.remoteUrl);
        yield();
        while(!sf.activeDownloadRequest.Finished()) { yield(); }

        if (sf.activeDownloadRequest.ResponseCode() == 200) {
            try {
                sf.activeDownloadRequest.SaveToFile(sf.path);
                sf.isDownloaded = true;
                sf.loadState = SoundLoadState::Downloaded;
                Debug::Print("SoundPlayer", "Downloaded: " + sf.displayName);
            } catch {
                warn("[Bonk++] Failed to save downloaded file '" + sf.path + "'. Error: " + getExceptionInfo());
                sf.isDownloaded = false; sf.loadState = SoundLoadState::LoadFailed_Download;
            }
        } else {
            warn("[Bonk++] Failed to download '" + sf.displayName + "'. HTTP: " + sf.activeDownloadRequest.ResponseCode() + " Error: " + sf.activeDownloadRequest.Error());
            sf.isDownloaded = false; sf.loadState = SoundLoadState::LoadFailed_Download;
        }
        @sf.activeDownloadRequest = null;
        RebuildPlayableSoundsList();
    }

    /**
     * Loads the Audio::Sample@ for a SoundInfo if not already loaded.
     * Returns true if sample is loaded and ready, false otherwise.
     */
    bool LoadAudioSample(SoundInfo@ sf) {
        if (sf is null) return false;
        if (sf.sample !is null) return true;
        if (sf.loadState == SoundLoadState::LoadFailed_Sample || sf.loadState == SoundLoadState::LoadFailed_Download) return false;

        if (sf.sourceType == SoundSourceType::Remote && !sf.isDownloaded) {
            Debug::Print("SoundPlayer", "Cannot load sample for remote sound '" + sf.displayName + "', not downloaded. Requesting download.");
            EnsureRemoteSoundDownloaded(sf);
            return false;
        }

        Debug::Print("SoundPlayer", "Attempting to load audio sample for: " + sf.displayName + " (Path: " + sf.path + ")");
        Audio::Sample@ loadedSample = null;
        try {
            if (sf.sourceType == SoundSourceType::Default) @loadedSample = Audio::LoadSample(sf.path);
            else @loadedSample = Audio::LoadSampleFromAbsolutePath(sf.path);
        } catch { warn("[Bonk++] EXCEPTION loading sample for '" + sf.path + "'. Error: " + getExceptionInfo()); }

        if (loadedSample is null) {
            warn("[Bonk++] Failed to load Audio::Sample for: " + sf.displayName + " from path: " + sf.path);
            sf.loadState = SoundLoadState::LoadFailed_Sample; @sf.sample = null; return false;
        } else {
            Debug::Print("SoundPlayer", "Audio::Sample loaded for: " + sf.displayName);
            @sf.sample = loadedSample; return true;
        }
    }

    // Helper to get the string setting value for remote sound enable state
    string GetRemoteSoundEnableSettingName(const string &in remoteFilename) {
        string settingName = "Setting_Enable_Remote_" + remoteFilename;
        // Sanitize for setting variable name (AngelScript variable names can't have '.')
        settingName = settingName.Replace(".mp3", "_mp3").Replace(".wav", "_wav").Replace(".ogg", "_ogg");
        settingName = settingName.Replace("-", "_"); // And hyphens
        return settingName;
    }

    /**
     * Rebuilds the g_playableSounds list based on current settings and states.
     * This list contains references to SoundInfo objects that are currently eligible for playback.
     */
    void RebuildPlayableSoundsList() {
        Debug::Print("SoundPlayer", "Rebuilding playable sounds list...");
        g_playableSounds.Resize(0);

        // 1. Default Sounds
        if (Setting_EnableDefaultSounds) {
            for (uint i = 0; i < g_defaultSounds.Length; i++) {
                SoundInfo@ sf = g_defaultSounds[i];
                if (sf is null) continue;
                // Check the specific Setting_Enable_Default_X for this sound
                bool isThisSoundEnabled = false;
                if (sf.displayName == "bonk.wav") isThisSoundEnabled = Setting_Enable_Default_bonkwav;
                else if (sf.displayName == "oof.wav") isThisSoundEnabled = Setting_Enable_Default_oofwav;
                else if (sf.displayName == "vineboom.mp3") isThisSoundEnabled = Setting_Enable_Default_vineboommp3;
                // Add more else if for other default sounds

                if (isThisSoundEnabled && sf.loadState != SoundLoadState::LoadFailed_Sample) {
                    g_playableSounds.InsertLast(sf);
                }
            }
        }

        // 2. Local Custom Sounds (globally enabled/disabled by Setting_EnableLocalCustomSounds)
        if (Setting_EnableLocalCustomSounds) {
            for (uint i = 0; i < g_localCustomSounds.Length; i++) {
                SoundInfo@ sf = g_localCustomSounds[i];
                if (sf is null) continue;
                if (sf.loadState != SoundLoadState::LoadFailed_Sample) {
                    g_playableSounds.InsertLast(sf);
                }
            }
        }

        // 3. Remote Sounds
        if (Setting_EnableRemoteSounds) {
            for (uint i = 0; i < g_remoteSounds.Length; i++) {
                SoundInfo@ sf = g_remoteSounds[i];
                if (sf is null) continue;

                string settingName = GetRemoteSoundEnableSettingName(sf.remoteFilename);
                bool isThisRemoteSoundEnabled = GetSettingBool(settingName, false); // Default to false if setting not found

                if (isThisRemoteSoundEnabled && sf.isDownloaded &&
                    sf.loadState != SoundLoadState::LoadFailed_Sample &&
                    sf.loadState != SoundLoadState::LoadFailed_Download) {
                    g_playableSounds.InsertLast(sf);
                }
            }
        }
        Debug::Print("SoundPlayer", "Rebuilt playable sounds list. Count: " + g_playableSounds.Length);
        if (g_playableSounds.Length > 0) g_orderedSoundIndex = g_orderedSoundIndex % g_playableSounds.Length;
        else g_orderedSoundIndex = 0;
    }


    /**
     * Selects a sound based on current settings, loads its audio sample if needed, and plays it.
     */
    void PlayBonkSound() {
        if (!g_isInitialized) Initialize();
        if (g_playableSounds.Length == 0) { Debug::Print("Playback", "No sounds available. Cannot play bonk."); return; }

        SoundInfo@ soundToPlay = null;
        int selectedPlayableIndex = -1;

        if (Setting_SoundPlaybackMode == SoundMode::Random) {
            uint potentialPlayableIndex = Math::Rand(0, g_playableSounds.Length);
            string potentialPath = g_playableSounds[potentialPlayableIndex].path;

            if (g_playableSounds.Length > 1 && potentialPath == g_lastPlayedPath && g_consecutivePlayCount >= int(Setting_MaxConsecutiveRepeats)) {
                Debug::Print("Playback", "Anti-repeat constraint hit for '" + g_playableSounds[potentialPlayableIndex].displayName + "'. Retrying...");
                int retryCount = 0; const int MAX_RETRIES = 10;
                while (potentialPath == g_lastPlayedPath && retryCount < MAX_RETRIES) {
                    potentialPlayableIndex = Math::Rand(0, g_playableSounds.Length);
                    potentialPath = g_playableSounds[potentialPlayableIndex].path;
                    retryCount++;
                }
            }
            selectedPlayableIndex = int(potentialPlayableIndex);
        } else { // Ordered
            g_orderedSoundIndex = g_orderedSoundIndex % g_playableSounds.Length; // Wrap index
            selectedPlayableIndex = g_orderedSoundIndex;
            g_orderedSoundIndex = (g_orderedSoundIndex + 1) % g_playableSounds.Length; // Increment for next time
        }

        if (selectedPlayableIndex < 0 || selectedPlayableIndex >= int(g_playableSounds.Length)) {
            warn("[Bonk++] Failed to select a sound from playable list.");
            return;
        }

        @soundToPlay = g_playableSounds[selectedPlayableIndex];

        // Update anti-repeat state
        if (soundToPlay.path == g_lastPlayedPath) g_consecutivePlayCount++;
        else { g_lastPlayedPath = soundToPlay.path; g_consecutivePlayCount = 1; }
        Debug::Print("Playback", "Selected: '" + soundToPlay.displayName + "', Consecutive: " + g_consecutivePlayCount);


        // Ensure sample is loaded (this also handles remote sounds not yet downloaded by trying to trigger download)
        if (!LoadAudioSample(soundToPlay)) {
            // LoadAudioSample already logs warnings if it fails or if a remote sound isn't downloaded
            Debug::Print("Playback", "Failed to ensure sample was loaded for: " + soundToPlay.displayName + ". Skipping playback.");
            return;
        }

        // Final check for sample before playing
        if (soundToPlay.sample is null) {
            warn("[Bonk++] Sample is null for '" + soundToPlay.displayName + "' right before playback. This shouldn't happen.");
            return;
        }

        Debug::Print("Playback", "Playing sound: '" + soundToPlay.displayName + "' (Volume: " + Setting_BonkVolume + "%)");
        Audio::Voice@ voice = null;
        try {
            @voice = Audio::Play(soundToPlay.sample);
            if (voice !is null) voice.SetGain(float(Setting_BonkVolume) / 100.0f);
            else warn("[Bonk++] Audio::Play returned null for: " + soundToPlay.displayName);
        } catch { warn("[Bonk++] EXCEPTION playing '" + soundToPlay.displayName + "'. Error: " + getExceptionInfo()); }

    }

    // --- Public Functions for Settings UI ---

    /**
     * Initiates download for a specific remote sound.
     */
    void RequestDownloadRemoteSound(uint index) {
        if (index < g_remoteSounds.Length) {
            Debug::Print("SoundPlayer", "Download requested for remote sound: " + g_remoteSounds[index].displayName);
            EnsureRemoteSoundDownloaded(g_remoteSounds[index]); // This will start the coroutine if needed
        }
    }

    /**
     * Triggers a refresh of the remote sound list from the JSON file.
     */
    void RequestRefreshRemoteSoundList() {
        Debug::Print("SoundPlayer", "Refresh remote sound list requested.");
        startnew(Coroutine_FetchAndProcessRemoteSoundList);
    }

    // --- Helper to get setting value by name (used for dynamic default sound settings) ---
    bool GetSettingBool(const string &in varName, bool defaultValue) {
        Meta::Plugin@plugin = Meta::ExecutingPlugin();
        if (plugin is null) return defaultValue;
        Meta::PluginSetting@ setting = plugin.GetSetting(varName);
        if (setting !is null && setting.Type == Meta::PluginSettingType::Bool) return setting.ReadBool();
        return defaultValue;
    }

    void SetSettingBool(const string &in varName, bool value) {
        Meta::Plugin@plugin = Meta::ExecutingPlugin();
        if (plugin is null) return;
        Meta::PluginSetting@ setting = plugin.GetSetting(varName);
        if (setting !is null && setting.Type == Meta::PluginSettingType::Bool) setting.WriteBool(value);
    }

} // namespace SoundPlayer