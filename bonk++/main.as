// --- main.as ---
// Bonk++ Entry Point and Lifecycle Management
// Coordinates other modules (BonkTracker, BonkUI, SoundPlayer).

// --- Global State for Main ---
uint g_sessionTotalBonks = 0;
string g_currentMapUid = "";
uint g_mapTotalBonks = 0;
float g_mapHighestBonkSpeed = 0.0f;
float g_mapActiveTimeSeconds = 0.0f;
bool g_wasInActivePlayStateLastFrame = false;
uint64 g_totalAllTimeBonks = 0; // Loaded/Saved via file
float g_lastBonkSpeedKmh = 0.0f;
float g_highestAllTimeBonkSpeedKmh = 0.0f; // All-time highest speed
uint g_initializationFrames = 0;
const uint INITIALIZATION_GRACE_FRAMES = 3; // Skip checks for 3 frames

// --- Define the persistence file name ---
const string ALL_TIME_STATS_FILENAME = "bonk_stats.txt";

/**
 * Resets statistics specific to the current map.
 */
void ResetMapStats() {
    Debug::Print("Main", "Resetting Map Stats (Bonks, Speed, Time)");
    g_mapTotalBonks = 0;
    g_mapHighestBonkSpeed = 0.0f;
    g_mapActiveTimeSeconds = 0.0f;
    g_wasInActivePlayStateLastFrame = false;
}

/**
 * Resets session-specific statistics.
 */
void ResetSessionStats() {
    Debug::Print("Main", "Resetting Session Stats (Bonks, Last Speed)");
    g_sessionTotalBonks = 0;
    g_lastBonkSpeedKmh = 0.0f;
}

/**
 * Loads the all-time bonk counter AND highest speed from its dedicated file.
 */
void LoadAllTimeStatsFromFile() {
    // Get the FULL path within the plugin's dedicated storage folder
    string filePath = IO::FromStorageFolder(ALL_TIME_STATS_FILENAME);
    print("[Bonk++] Attempting to load All-Time Stats from: " + filePath); // Use print for higher visibility
    g_totalAllTimeBonks = 0; // Default values
    g_highestAllTimeBonkSpeedKmh = 0.0f;

    if (IO::FileExists(filePath)) {
        IO::File file;
        try {
            file.Open(filePath, IO::FileMode::Read);

            // Read Line 1: Count
            if (!file.EOF()) {
                string countLine = file.ReadLine().Trim();
                int64 parsedCount = 0;
                if (Text::TryParseUInt64(countLine, parsedCount)) {
                    g_totalAllTimeBonks = uint64(parsedCount);
                    Debug::Print("Main", "Loaded All-Time Bonk Count: " + g_totalAllTimeBonks);
                } else {
                    warn("[Bonk++] Failed to parse count from '" + filePath + "'. Line 1: '" + countLine + "'");
                }
            } else {
                 warn("[Bonk++] Stats file '" + filePath + "' seems empty or missing count line.");
            }

            // Read Line 2: Speed
            if (!file.EOF()) {
                string speedLine = file.ReadLine().Trim();
                float parsedSpeed = 0.0f;
                if (Text::TryParseFloat(speedLine, parsedSpeed)) {
                     g_highestAllTimeBonkSpeedKmh = parsedSpeed;
                     Debug::Print("Main", "Loaded Highest All-Time Speed: " + g_highestAllTimeBonkSpeedKmh);
                } else {
                     warn("[Bonk++] Failed to parse speed from '" + filePath + "'. Line 2: '" + speedLine + "'");
                }
            } else {
                 Debug::Print("Main", "Highest speed line not found in stats file (might be old format or just count).");
            }

            file.Close(); // Close explicitly
        } catch {
            warn("[Bonk++] EXCEPTION reading '" + filePath + "'. Error: " + getExceptionInfo() + ". Resetting counters.");
            try { file.Close(); } catch {}
            g_totalAllTimeBonks = 0;
            g_highestAllTimeBonkSpeedKmh = 0.0f;
        }
    } else {
        print("[Bonk++] All-Time Stats file NOT FOUND at: " + filePath + ". Initializing counters to 0."); // Use print for higher visibility
        g_totalAllTimeBonks = 0;
        g_highestAllTimeBonkSpeedKmh = 0.0f;
    }
}

/**
 * Saves the all-time bonk counter AND highest speed to its dedicated file.
 */
void SaveAllTimeStatsToFile() {
    // Get the FULL path within the plugin's dedicated storage folder
    string filePath = IO::FromStorageFolder(ALL_TIME_STATS_FILENAME);
    print("[Bonk++] Attempting to save All-Time Stats (Count: " + g_totalAllTimeBonks + ", Speed: " + g_highestAllTimeBonkSpeedKmh + ") to: " + filePath); // Use print for higher visibility

    IO::File file;
    try {
        // Get the directory path *containing* the file
        string dirPath = Path::GetDirectoryName(filePath);
        // Check if the *directory* exists, create if not
        if (!IO::FolderExists(dirPath)) {
             Debug::Print("Main", "Storage directory does not exist, creating: " + dirPath);
             try { IO::CreateFolder(dirPath, true); }
             catch {
                 // Log warning but proceed, Open might still work if only file is missing
                 warn("[Bonk++] Failed to create storage directory: " + dirPath + " - Error: " + getExceptionInfo());
             }
        }

        file.Open(filePath, IO::FileMode::Write);
        file.WriteLine("" + g_totalAllTimeBonks); // Write count + newline
        file.Write("" + g_highestAllTimeBonkSpeedKmh); // Write speed (no newline needed at end)
        file.Close();
         print("[Bonk++] All-Time Stats saved successfully to: " + filePath); // Use print for higher visibility
    } catch {
        warn("[Bonk++] EXCEPTION writing '" + filePath + "'. Error: " + getExceptionInfo()); // Log full path
        try { file.Close(); } catch {}
    }
}

// --- Reset All-Time Stats ---
/**
 * Resets the all-time bonk counter and highest speed, then saves the changes immediately.
 */
void ResetAllTimeStats() {
    Debug::Print("Main", "Resetting All-Time Stats (Bonks, Speed) to 0.");
    g_totalAllTimeBonks = 0;
    g_highestAllTimeBonkSpeedKmh = 0.0f;
    SaveAllTimeStatsToFile(); // Immediately save the reset values
}


/**
 * Plugin entry point, called once when the plugin is loaded or reloaded.
 */
void Main() {
    ResetSessionStats();
    g_currentMapUid = "";
    ResetMapStats();
    LoadAllTimeStatsFromFile(); // Load persistent counter & speed from file
    g_initializationFrames = INITIALIZATION_GRACE_FRAMES;
    SoundPlayer::Initialize();
    BonkTracker::Initialize();
    BonkUI::Initialize();
    print("[Bonk++] Plugin Loaded! v" + Meta::ExecutingPlugin().Version);
}

/**
 * Called when the plugin is enabled via UI or programmatically.
 */
void OnEnable() {
    print("[Bonk++] Enabled");
    BonkTracker::Initialize();
    BonkUI::Initialize();
    g_currentMapUid = "";
    ResetMapStats();
    ResetSessionStats();
    // No need to reload all-time stats here
    g_initializationFrames = INITIALIZATION_GRACE_FRAMES; // Reset on map change too
    BonkTracker::Initialize(); // Ensure tracker state is also reset
    Debug::Print("Main", "Resetting Map Stats & Init Grace Period (" + INITIALIZATION_GRACE_FRAMES + " frames)");
}

/**
 * Called when the plugin is disabled via UI or programmatically.
 */
void OnDisable() {
    print("[Bonk++] Disabled");
    BonkUI::DeactivateVisualEffect();
    g_wasInActivePlayStateLastFrame = false;
}

/**
 * Called when the plugin is unloaded/removed from memory.
 */
void OnDestroyed() {
    print("[Bonk++] Unloading. Saving All-Time Stats...");
    SaveAllTimeStatsToFile(); // Save the counters before exiting
}


/**
 * Gets the local player's handle using the GameTerminals pattern.
 */
CSmPlayer@ GetLocalPlayerHandle(CGameCtnApp@ app, CGameCtnPlayground@ playground) {
    if (app is null || playground is null) {
        return null;
    }
    if (playground.GameTerminals.Length == 0) {
         Debug::Print("GetLocalPlayerHandle", "Playground.GameTerminals is empty.");
         return null;
    }
    CGameTerminal@ terminal = playground.GameTerminals[0];
    if (terminal is null) {
         Debug::Print("GetLocalPlayerHandle", "Playground.GameTerminals[0] is null.");
         return null;
    }
    CSmPlayer@ player = cast<CSmPlayer>(terminal.GUIPlayer);
    if (player is null) {
        @player = cast<CSmPlayer>(terminal.ControlledPlayer);
        if (player is null) {
             Debug::Print("GetLocalPlayerHandle", "Terminal's GUIPlayer and ControlledPlayer are null or not CSmPlayer.");
             return null;
        }
    }
    return player;
}

/**
 * Checks if the player is currently in an active gameplay state.
 */
bool IsPlayerActivelyPlaying() {
    CGameCtnApp@ app = GetApp();
    if (app is null) return false;
    CGameCtnPlayground@ playground = cast<CGameCtnPlayground>(app.CurrentPlayground);
    if (playground is null) return false;
    CSmPlayer@ localPlayer = GetLocalPlayerHandle(app, playground);
    CSmPlayer@ viewingPlayer = VehicleState::GetViewingPlayer();
    if (localPlayer is null) return false; // Cannot determine if playing without local player handle
    if (viewingPlayer is null || viewingPlayer !is localPlayer) return false; // Spectating or in editor/replay
    // Add other checks like pause state if necessary
    return true;
}


/**
 * Called every frame for game logic updates.
 */
void Update(float dt) {
    CGameCtnApp@ app = GetApp();
    if (app is null) {
        if (g_currentMapUid != "") {
            // print("[Bonk++] App handle became null, resetting stats."); // More visible log
            g_currentMapUid = "";
            ResetMapStats();
        }
        return;
    }

    // --- Map Change Detection ---
    string currentMapUidInFrame = "";
    CGameCtnChallengeInfo@ mapInfo = null;
    CGameCtnPlayground@ playground = cast<CGameCtnPlayground>(app.CurrentPlayground);
    bool foundInfoViaPlayground = false;

     if (playground !is null) {
         auto smArenaPlayground = cast<CSmArenaClient>(playground);
         if (smArenaPlayground !is null) {
             CGameCtnChallenge@ currentMap = smArenaPlayground.Map;
             if (currentMap !is null) {
                @mapInfo = currentMap.MapInfo;
                if (mapInfo !is null) foundInfoViaPlayground = true;
             }
         }
     }
     if (!foundInfoViaPlayground) {
         if (app.RootMap !is null) {
             @mapInfo = app.RootMap.MapInfo;
         }
     }

    if (mapInfo !is null) {
        currentMapUidInFrame = mapInfo.MapUid;
        if (currentMapUidInFrame == "") currentMapUidInFrame = mapInfo.IdName;
    }

    if (currentMapUidInFrame != "" && currentMapUidInFrame != g_currentMapUid) {
        Debug::Print("Main", "Map changed from '" + g_currentMapUid + "' to '" + currentMapUidInFrame + "'");
        g_currentMapUid = currentMapUidInFrame;
        ResetMapStats();
    } else if (currentMapUidInFrame == "" && g_currentMapUid != "") {
        Debug::Print("Main", "Current map UID became invalid (left server/map?), resetting stats.");
        g_currentMapUid = "";
        ResetMapStats();
    }

    // --- Active Playtime Tracking ---
    bool isActiveNow = IsPlayerActivelyPlaying();
    float dtSeconds = dt / 1000.0f;

    if (isActiveNow) {
        if (g_wasInActivePlayStateLastFrame) {
             g_mapActiveTimeSeconds += dtSeconds;
        }
        g_wasInActivePlayStateLastFrame = true;
    } else {
        g_wasInActivePlayStateLastFrame = false;
    }

    // --- Bonk Detection & Stat Update ---
    if(isActiveNow) {
        BonkTracker::BonkEventInfo@ bonkInfo = BonkTracker::UpdateDetection(dt);
        if (bonkInfo !is null) {
             g_sessionTotalBonks++;
             g_mapTotalBonks++;
             g_totalAllTimeBonks++; // Increment in-memory counter
             g_lastBonkSpeedKmh = bonkInfo.speed;
             Debug::Print("Main", "Counters - Session: " + g_sessionTotalBonks + ", Map: " + g_mapTotalBonks + ", AllTime: " + g_totalAllTimeBonks + ", LastSpeed: " + g_lastBonkSpeedKmh);

             // Update Map Highest Speed
             if (bonkInfo.speed > g_mapHighestBonkSpeed) {
                 g_mapHighestBonkSpeed = bonkInfo.speed;
                 Debug::Print("Main", "New Map Highest Speed Bonk: " + g_mapHighestBonkSpeed + " km/h");
             }

             // Update All-Time Highest Speed
             if (bonkInfo.speed > g_highestAllTimeBonkSpeedKmh) {
                 g_highestAllTimeBonkSpeedKmh = bonkInfo.speed;
                 Debug::Print("Main", "New *** ALL-TIME *** Highest Speed Bonk: " + g_highestAllTimeBonkSpeedKmh + " km/h");
                 // Potential immediate save (optional, OnDestroyed is safer)
                 SaveAllTimeStatsToFile();
             }

             // Sound/Visual Trigger Logic
             if (Setting_EnableSound) {
                 int chanceRoll = Math::Rand(0, 100);
                 if (chanceRoll < int(Setting_BonkChance)) {
                     SoundPlayer::PlayBonkSound();
                     if (Setting_EnableVisual) BonkUI::TriggerVisualEffect();
                 } else {
                      if (Setting_EnableVisual) BonkUI::TriggerVisualEffect();
                 }
             } else if (Setting_EnableVisual) {
                 BonkUI::TriggerVisualEffect();
             }
        }
    } else {
        BonkTracker::UpdateDetection(dt); // Maintain physics state
    }
}

/**
 * Called every frame for rendering game overlays.
 */
void Render() {
    BonkUI::RenderEffect();
    BonkStatsUI::RenderGUIWindow();
}

/**
 * Called every frame for rendering interface elements.
 */
void RenderInterface() {
    // GUI rendering moved to Render()
}