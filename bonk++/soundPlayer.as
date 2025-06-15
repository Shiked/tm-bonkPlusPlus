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
    string g_userLocalSoundsFolder;

    const string REMOTE_SOUND_LIST_URL = "https://file.shikes.space/api/bonkpp-sounds.json";
    const string REMOTE_SOUND_BASE_URL = "https://file.shikes.space/TM/BonkPP/";

    const string OLD_CUSTOM_SOUNDS_SUBFOLDER = "Sounds/"; // The old folder name
    const string NEW_CUSTOM_SOUNDS_SUBFOLDER = "LocalSounds/"; // The new folder name

/**
 * THIS WILL BE REMOVED IN A FUTURE VERSION - 
 * once it's safe to assume that people are not updating from pre-v1.6.9 versions
 * 
 * Performs a one-time migration of custom sounds.
 * Prioritizes renaming the old "Sounds" folder to "LocalSounds" if safe.
 * Falls back to a file-by-file merge if "LocalSounds" already exists and has content.
 */
void PerformOneTimeCustomSoundMigration() {
    string bonkHeader = Icons::Music + " Bonk++";
    vec4 headerWarnBgColor = vec4(1.0f, 0.5f, 0.0f, 1.0f); 
    vec4 headerSuccessBgColor = vec4(0.2f, 0.6f, 0.25f, 0.9f); 

    string basePluginStoragePath = IO::FromStorageFolder("");
    if (basePluginStoragePath == "") {
        warn("[Bonk++] Migration: Could not determine base plugin storage path. Skipping migration.");
        return;
    }

    string oldSoundsPath = Path::Join(basePluginStoragePath, OLD_CUSTOM_SOUNDS_SUBFOLDER);
    string newSoundsPath = Path::Join(basePluginStoragePath, NEW_CUSTOM_SOUNDS_SUBFOLDER);

    Debug::Print("SoundPlayer", "Migration Check: Old path: " + oldSoundsPath);
    Debug::Print("SoundPlayer", "Migration Check: New path: " + newSoundsPath);

    if (!IO::FolderExists(oldSoundsPath)) {
        Debug::Print("SoundPlayer", "Migration: Old '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' folder not found. No migration needed.");
        return;
    }

    print("[Bonk++] Old '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' folder found. Checking migration strategy...");
    UI::ShowNotification(bonkHeader, "Checking for custom sounds to migrate...", 5000);

    bool migrationViaRenameSuccessful = false;

    if (!IO::FolderExists(newSoundsPath)) {
        Debug::Print("SoundPlayer", "Migration: New '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "' folder does not exist. Attempting to rename old folder.");
        try {
            IO::Move(oldSoundsPath, newSoundsPath);
            migrationViaRenameSuccessful = true;
            print("[Bonk++] Migration: Successfully renamed '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' to '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "'.");
            UI::ShowNotification(bonkHeader, "Custom sounds migrated (folder renamed).", 7000);
        } catch {
            warn("[Bonk++] Migration: Failed to rename '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' to '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "'. Error: " + getExceptionInfo() + ". Falling back to file-by-file migration.");
        }
    } else {
        Debug::Print("SoundPlayer", "Migration: New '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "' folder exists. Checking if empty.");
        array<string>@ itemsInNewFolder = IO::IndexFolder(newSoundsPath, false);

        if (itemsInNewFolder !is null && itemsInNewFolder.Length == 0) {
            Debug::Print("SoundPlayer", "Migration: New '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "' folder is empty. Attempting to delete it and then rename old folder.");
            try {
                IO::DeleteFolder(newSoundsPath, false);
                Debug::Print("SoundPlayer", "Migration: Successfully deleted empty '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "' folder.");
                IO::Move(oldSoundsPath, newSoundsPath);
                migrationViaRenameSuccessful = true;
                print("[Bonk++] Migration: Deleted empty '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "' and renamed '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' to it.");
                UI::ShowNotification(bonkHeader, "Custom sounds migrated (folder replaced).", 7000);
            } catch {
                warn("[Bonk++] Migration: Failed during delete/rename of empty '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "' and '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "'. Error: " + getExceptionInfo() + ". Falling back to file-by-file migration.");
            }
        } else {
            Debug::Print("SoundPlayer", "Migration: New '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "' folder exists and is not empty (or unreadable: " + (itemsInNewFolder is null) + ", items: " + (itemsInNewFolder !is null ? itemsInNewFolder.Length : -1) + "). Proceeding with file-by-file merge.");
        }
    }

    if (migrationViaRenameSuccessful) {
        Debug::Print("SoundPlayer", "Migration completed successfully via folder rename/replace.");
        return;
    }

    print("[Bonk++] Attempting file-by-file migration/merge from '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' into '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "'.");

    if (!IO::FolderExists(newSoundsPath)) {
        Debug::Print("SoundPlayer", "Migration (File-by-File): New '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "' folder still not found. Attempting to create.");
        try {
            IO::CreateFolder(newSoundsPath, true);
        } catch {
            warn("[Bonk++] Migration (File-by-File): Critical error - Failed to create '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "' folder at '" + newSoundsPath + "'. Error: " + getExceptionInfo() + ". Migration aborted.");
            UI::ShowNotification(bonkHeader, "Error creating LocalSounds folder for merge. Migration failed. Please check logs.", headerWarnBgColor, 10000);
            return;
        }
    }

    array<string>@ itemsInOldFolder = IO::IndexFolder(oldSoundsPath, false);
    if (itemsInOldFolder is null) {
        warn("[Bonk++] Migration (File-by-File): Failed to list items in old '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' folder. Aborting file-by-file merge.");
        return;
    }
    
    if (itemsInOldFolder.Length == 0) {
        Debug::Print("SoundPlayer", "Migration (File-by-File): Old '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' folder is empty.");
    } else {
        Debug::Print("SoundPlayer", "Migration (File-by-File): Found " + itemsInOldFolder.Length + " item(s) in old folder to process for merge.");
    }

    int filesMovedCount = 0;
    bool anyMoveFailed = false;

    for (uint i = 0; i < itemsInOldFolder.Length; i++) {
        string sourceItemPath = itemsInOldFolder[i];
        string fileName = Path::GetFileName(sourceItemPath);

        if (IO::FileExists(sourceItemPath)) {
            // Item is confirmed to be a file.
            Debug::Print("SoundPlayer", "Migration (File-by-File): Identified FILE: " + fileName);
            string targetFilePath = Path::Join(newSoundsPath, fileName);

            if (IO::FileExists(targetFilePath)) {
                Debug::Print("SoundPlayer", "Migration (File-by-File): File '" + fileName + "' already exists in '" + NEW_CUSTOM_SOUNDS_SUBFOLDER + "'. Skipping move.");
            } else {
                Debug::Print("SoundPlayer", "Migration (File-by-File): Attempting to move FILE '" + fileName + "' to '" + targetFilePath + "'");
                try {
                    IO::Move(sourceItemPath, targetFilePath);
                    filesMovedCount++;
                    Debug::Print("SoundPlayer", "Migration (File-by-File): Successfully moved '" + fileName + "'.");
                } catch {
                    string errorMsg = getExceptionInfo();
                    warn("[Bonk++] Migration (File-by-File): Failed to move file '" + fileName + "'. Error: " + errorMsg);
                    anyMoveFailed = true;
                }
            }
        } else if (IO::FolderExists(sourceItemPath)) {
            // Item is confirmed to be a folder.
            Debug::Print("SoundPlayer", "Migration (File-by-File): Skipping actual SUBFOLDER found in old '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "': " + fileName);
        } else {
            // Item is neither a file nor a folder that IO can identify.
            warn("[Bonk++] Migration (File-by-File): Item '" + fileName + "' from old folder (" + sourceItemPath + ") is neither a recognized file nor folder. Skipping.");
        }
    }

    if (filesMovedCount > 0) {
         UI::ShowNotification(bonkHeader, "Merged " + filesMovedCount + " custom sound(s) into 'LocalSounds' folder.", headerSuccessBgColor, 7000);
    } else if (!anyMoveFailed && itemsInOldFolder.Length > 0) {
        bool anyFilesWerePresentInOld = false;
        for(uint i=0; i < itemsInOldFolder.Length; i++) { if(IO::FileExists(itemsInOldFolder[i])) { anyFilesWerePresentInOld = true; break; }}
        if(anyFilesWerePresentInOld) { // Only log this if there were actually files to potentially move
            Debug::Print("SoundPlayer", "Migration (File-by-File): No files needed to be moved (likely all already existed in new folder).");
        }
    }
    
    // --- Final Cleanup of the Old "Sounds" Folder ---
    if (IO::FolderExists(oldSoundsPath)) {
        array<string>@ remainingItemsInOldFolder = IO::IndexFolder(oldSoundsPath, false);
        bool oldFolderIsCompletelyEmpty = (remainingItemsInOldFolder !is null && remainingItemsInOldFolder.Length == 0);

        if (oldFolderIsCompletelyEmpty) {
            Debug::Print("SoundPlayer", "Migration Cleanup: Old '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' folder is completely empty. Attempting delete.");
            try {
                IO::DeleteFolder(oldSoundsPath, false); // false = non-recursive, only if empty
                print("[Bonk++] Migration Cleanup: Successfully deleted completely empty old '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' folder.");
            } catch {
                warn("[Bonk++] Migration Cleanup: Could not delete empty old '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' folder. Error: " + getExceptionInfo());
            }
        } else if (remainingItemsInOldFolder !is null) { // Not completely empty, but we have a list of what's left
            string renameSuffix = "_LEGACY_REVIEW-AND-DELETE";
            string oldSoundsPathParent = Path::GetDirectoryName(oldSoundsPath.SubStr(0, oldSoundsPath.Length -1)); // Get parent of "Sounds/"
            string oldSoundsFolderName = Path::GetFileName(oldSoundsPath.SubStr(0, oldSoundsPath.Length -1));    // Get "Sounds"
            string newNameForOldFolder = oldSoundsFolderName + renameSuffix;
            string renamedOldSoundsPath = Path::Join(oldSoundsPathParent, newNameForOldFolder) + "/";


            if (IO::FolderExists(renamedOldSoundsPath) || IO::FileExists(renamedOldSoundsPath.SubStr(0, renamedOldSoundsPath.Length-1))) {
                 warn("[Bonk++] Migration Cleanup: Wanted to rename old sounds folder to '" + newNameForOldFolder + "' but a folder or file with that name already exists. Old folder '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' left as is. Manual cleanup is required.");
                 UI::ShowNotification(bonkHeader, "Old 'Sounds' folder still contains items and could not be auto-renamed. Please check it manually.", headerWarnBgColor, 10000);
            } else {
                Debug::Print("SoundPlayer", "Migration Cleanup: Old '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' folder still contains items ("+remainingItemsInOldFolder.Length+"). Attempting to rename to '" + newNameForOldFolder + "'.");
                try {
                    IO::Move(oldSoundsPath, renamedOldSoundsPath);
                    print("[Bonk++] Migration Cleanup: Renamed old sounds folder to '" + newNameForOldFolder + "'. Please check its contents and delete manually if no longer needed.");
                    UI::ShowNotification(bonkHeader, "Old 'Sounds' folder renamed to '" + newNameForOldFolder + "'. Please confirm all sounds are in the LocalSounds folder and delete.", headerWarnBgColor, 10000);
                } catch {
                    warn("[Bonk++] Migration Cleanup: Failed to rename old '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' folder. Error: " + getExceptionInfo() + ". Manual cleanup may be needed.");
                     UI::ShowNotification(bonkHeader, "Old 'Sounds' folder still contains items and rename failed. Please check it manually.", headerWarnBgColor, 10000);
                }
            }
        } else { // remainingItemsInOldFolder is null - couldn't list contents
            warn("[Bonk++] Migration Cleanup: Could not re-index old folder '" + OLD_CUSTOM_SOUNDS_SUBFOLDER + "' to confirm its contents for final cleanup. Manual cleanup may be needed.");
            UI::ShowNotification(bonkHeader, "Could not verify old 'Sounds' folder contents. Please check it manually.", headerWarnBgColor, 10000);
        }
    } // end if (IO::FolderExists(oldSoundsPath))

    Debug::Print("SoundPlayer", "Migration process finished.");
}

// --- END MIGRATION ---

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

        // --- Perform one-time migration BEFORE defining g_userLocalSoundsFolder path fully ---
        PerformOneTimeCustomSoundMigration();

        string basePluginStoragePath = IO::FromStorageFolder("");
        Debug::Print("SoundPlayer", "Base Plugin Storage Path: " + basePluginStoragePath);

        g_downloadedSoundsFolder = Path::Join(basePluginStoragePath, "DownloadedSounds/");
        if (!IO::FolderExists(g_downloadedSoundsFolder)) {
            try { IO::CreateFolder(g_downloadedSoundsFolder, true); Debug::Print("SoundPlayer", "Created DownloadedSounds folder: " + g_downloadedSoundsFolder); }
            catch { warn("[Bonk++] Failed to create DownloadedSounds folder. Error: " + getExceptionInfo()); }
        }

        // Define and create the "LocalSounds" subfolder using the NEW name
        g_userLocalSoundsFolder = Path::Join(basePluginStoragePath, NEW_CUSTOM_SOUNDS_SUBFOLDER);
        if (!IO::FolderExists(g_userLocalSoundsFolder)) {
            try { IO::CreateFolder(g_userLocalSoundsFolder, true); Debug::Print("SoundPlayer", "Created LocalSounds folder: " + g_userLocalSoundsFolder); }
            catch { warn("[Bonk++] Failed to create LocalSounds folder. Error: " + getExceptionInfo()); }
        }

        PopulateDefaultSoundList();
        ReloadLocalCustomSounds(); // Will now use g_userLocalSoundsFolder (which might have just been renamed)
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