// --- bonkTracker.as ---
// Core logic for detecting bonks based on physics changes (jerk and deceleration) and managing related state like debounce timers.
// V4.0 - Re-incorporated deceleration check from original to fix respawn bonk issue.

namespace BonkTracker {

    // --- Constants ---
    const uint RESPAWN_COOLDOWN_MS = 350;
    const float ZERO_SPEED_THRESHOLD = 0.1f;

    // --- State Variables ---
    vec3 g_previousVel = vec3(0, 0, 0);
    float g_previousSpeed = 0.0f;
    vec3 g_previousVdt = vec3(0, 0, 0); // Filtered velocity change from PREVIOUS frame
    uint64 g_lastBonkTime = 0;
    bool g_isInitialized = false;
    bool g_isInRespawnCooldown = false;
    uint64 g_respawnCooldownEndTime = 0;

    // --- Bonk Event Info ---
    class BonkEventInfo {
        float jerkMagnitude = 0.0f;
        float speed = 0.0f;
        float decelerationMagnitude = 0.0f; // Added for info, if needed
    }

    // --- Initialization ---
    void Initialize() {
        g_previousVel = vec3(0, 0, 0);
        g_previousSpeed = 0.0f;
        g_previousVdt = vec3(0, 0, 0);
        g_lastBonkTime = 0;
        g_isInRespawnCooldown = false;
        g_respawnCooldownEndTime = 0;
        g_isInitialized = true;
        if (Setting_Debug_EnableMaster && Setting_Debug_Crash) {
            Debug::Print("Crash", "BonkTracker Initialized/Reset.");
        }
    }

    // --- Helper Functions ---
    int GetWheelContactCount(CSceneVehicleVisState@ visState) {
        if (visState is null) return 0;
        return
            (visState.FLGroundContactMaterial != CSceneVehicleVisState::EPlugSurfaceMaterialId::XXX_Null ? 1 : 0) +
            (visState.FRGroundContactMaterial != CSceneVehicleVisState::EPlugSurfaceMaterialId::XXX_Null ? 1 : 0) +
            (visState.RLGroundContactMaterial != CSceneVehicleVisState::EPlugSurfaceMaterialId::XXX_Null ? 1 : 0) +
            (visState.RRGroundContactMaterial != CSceneVehicleVisState::EPlugSurfaceMaterialId::XXX_Null ? 1 : 0);
    }

    // --- Core Detection Logic ---
    BonkEventInfo@ UpdateDetection(float dt) {
        if (!g_isInitialized) Initialize();

        CSceneVehicleVisState@ visState = VehicleState::ViewingPlayerState();
        if (visState is null) {
            if (g_isInRespawnCooldown || g_isInitialized) { Initialize(); }
            return null;
        }

        vec3 currentVel = visState.WorldVel;
        float currentSpeed = currentVel.Length();
        float dtSeconds = dt > 0.0f ? (dt / 1000.0f) : 0.016f; // Avoid division by zero, use a typical frame time if dt is 0
        uint64 currentTime = Time::Now;

        bool skipDetectionThisFrame = false;
        bool justFinishedCooldown = false;

        // --- Respawn State Check & Cooldown Management ---
        bool mlFeedSpawned = true;
        #if DEPENDENCY_MLFEEDRACEDATA && DEPENDENCY_MLHOOK
            auto mlf = MLFeed::GetRaceData_V3();
            if (mlf !is null) {
                 auto plf = mlf.GetPlayer_V3(MLFeed::LocalPlayersName);
                 if (plf !is null) {
                     mlFeedSpawned = (plf.spawnStatus == MLFeed::SpawnStatus::Spawned);
                    if (Setting_Debug_EnableMaster && Setting_Debug_Crash) {
                         Debug::Print("Crash", "MLFeed Status: spawnStatus=" + plf.spawnStatus + ", g_isInRespawnCooldown=" + g_isInRespawnCooldown + ", cooldownEndTime=" + g_respawnCooldownEndTime + ", currentTime="+currentTime);
                    }
                 } else { if (Setting_Debug_EnableMaster && Setting_Debug_Crash) Debug::Print("Crash", "MLFeed Player Data is null."); }
            } else { if (Setting_Debug_EnableMaster && Setting_Debug_Crash) Debug::Print("Crash", "MLFeed Race Data is null."); }
        #endif

        if (!mlFeedSpawned) { // Not spawned
            if (!g_isInRespawnCooldown) { g_isInRespawnCooldown = true; g_respawnCooldownEndTime = 0; }
            skipDetectionThisFrame = true;
        } else { // Spawned
            if (g_isInRespawnCooldown) {
                if (g_respawnCooldownEndTime == 0) { // Just spawned, start timer
                     g_respawnCooldownEndTime = currentTime + RESPAWN_COOLDOWN_MS;
                     skipDetectionThisFrame = true;
                } else { // Timer running
                    if (currentTime < g_respawnCooldownEndTime) { // Still cooling down
                        skipDetectionThisFrame = true;
                    } else { // Cooldown ended
                        g_isInRespawnCooldown = false;
                        g_respawnCooldownEndTime = 0;
                        justFinishedCooldown = true;
                    }
                }
            }
        }

        // --- Update State if Skipping or Cooldown Just Finished ---
        if (skipDetectionThisFrame || justFinishedCooldown) {
             if (Setting_Debug_EnableMaster && Setting_Debug_Crash) Debug::Print("Crash", "[State Update] Updating prev state (Skip="+skipDetectionThisFrame+", JustFinishedCooldown="+justFinishedCooldown+"). CurrentSpeed="+currentSpeed);
             g_previousVel = currentVel;
             g_previousSpeed = currentSpeed;
             g_previousVdt = vec3(0,0,0);
        }

        // --- Early Exit if Skipping ---
        if (skipDetectionThisFrame) {
            if (Setting_Debug_EnableMaster && Setting_Debug_Crash) Debug::Print("Crash", "Final Skip Decision: Skipping frame (Respawn/Cooldown).");
            return null;
        }
        // --- End Skip Logic ---

        // --- Bonk Detection Algorithm (Now includes deceleration) ---

        // Step 1: Calculate Deceleration
        float currentDecel = 0.0f;
        if (dtSeconds > 0.0f) { // Avoid division by zero if dt was 0
            currentDecel = Math::Max(0.0f, (g_previousSpeed - currentSpeed) / dtSeconds);
        }
        float targetDecelThreshold = Setting_DecelerationThreshold + g_previousSpeed * 1.5f; // Dynamic threshold
        bool decelOk = currentDecel > targetDecelThreshold;

        // Log Deceleration check always if debugging crash detection
        if (Setting_Debug_EnableMaster && Setting_Debug_Crash) {
            Debug::Print("Crash", "[Decel Check] Decel: " + currentDecel + " > TargetThresh: " + targetDecelThreshold + " (Base:" + Setting_DecelerationThreshold + ", PrevSpeedBonus:" + (g_previousSpeed * 1.5f) + ") ? -> " + decelOk); // Spammy
        }

        // Step 2: Calculate Filtered Jerk Magnitude
        vec3 vdt = currentVel - g_previousVel;
        float vdtUpComponent = Math::Dot(vdt, visState.Up);
        vec3 vdt_NoVertical = vdt - visState.Up * vdtUpComponent;
        vec3 vdt_Filtered = vdt_NoVertical;
        float forwardComponent = Math::Dot(vdt_NoVertical, visState.Dir);
        if (forwardComponent > 0) { vdt_Filtered = vdt_NoVertical - visState.Dir * forwardComponent; }
        vec3 vdtdt = vdt_Filtered - g_previousVdt;
        float jerkMagnitude = vdtdt.Length();

        // Step 3: Perform Jerk Sensitivity Check
        int wheelContactCount = GetWheelContactCount(visState);
        float sensitivityThreshold = (wheelContactCount == 4) ? Setting_SensitivityGrounded : Setting_SensitivityAirborne;
        bool sensitivityOk = jerkMagnitude > sensitivityThreshold;

        // Log Jerk check always if debugging crash detection
         if (Setting_Debug_EnableMaster && Setting_Debug_Crash) {
            Debug::Print("Crash", "[Jerk Sensitivity Check] Jerk: " + jerkMagnitude + " > Threshold (" + (wheelContactCount == 4 ? "Ground" : "Air") + "): " + sensitivityThreshold + " ? -> " + sensitivityOk);  // Spammy
         }

        // Step 4: Debounce and Minimum Speed Check
        bool debounceOk = (currentTime - g_lastBonkTime) > Setting_BonkDebounce;
        bool speedOk = g_previousSpeed > 10.0f; // Check previous speed was significant

        // Step 5: Final Decision - Now includes deceleration check
        BonkEventInfo@ bonkEvent = null;
        bool allConditionsMet = decelOk && sensitivityOk && speedOk && debounceOk; // ADDED decelOk

        if (allConditionsMet) {
            // Check for zero speed override (respawn)
            if (currentSpeed < ZERO_SPEED_THRESHOLD) {
                 if (Setting_Debug_EnableMaster && Setting_Debug_Crash) {
                    Debug::Print("Crash", "Bonk OVERRIDDEN: Conditions met, but CurrentSpeed (" + currentSpeed + ") is near zero. Likely respawn.");
                 }
            } else {
                // All conditions met, including non-zero speed. Confirm bonk.
                g_lastBonkTime = currentTime;
                float speedToStoreKmh = g_previousSpeed * 3.6f;
                 if (Setting_Debug_EnableMaster && Setting_Debug_Crash) {
                    Debug::Print("Crash", "Bonk CONFIRMED! Speed: " + speedToStoreKmh + " km/h. DecelOK: " + decelOk + " (Val:" + currentDecel + ", Thresh:" + targetDecelThreshold + "). JerkOK: " + sensitivityOk + " (Val:" + jerkMagnitude + ", Thresh:" + sensitivityThreshold + "). DebounceOK: " + debounceOk + ". SpeedOK: " + speedOk);
                 }

                @bonkEvent = BonkEventInfo();
                bonkEvent.jerkMagnitude = jerkMagnitude;
                bonkEvent.speed = speedToStoreKmh;
                bonkEvent.decelerationMagnitude = currentDecel; // Store for info
            }
        } else if (Setting_Debug_EnableMaster && Setting_Debug_Crash) {
             // Log failure reasons only if car was moving somewhat
             if (g_previousSpeed > 5.0f) {
                 string reason = "";
                 if (!decelOk) reason += "Decel (Val:" + currentDecel + " <= TargetThresh:" + targetDecelThreshold + ") "; // ADDED
                 if (!sensitivityOk) reason += "Jerk (Val:" + jerkMagnitude + " <= Thresh:" + sensitivityThreshold + ") ";
                 if (!speedOk) reason += "Speed (Prev:" + g_previousSpeed + " <= 10) ";
                 if (!debounceOk) reason += "Debounce (Time since last: " + (currentTime - g_lastBonkTime) + "ms <= " + Setting_BonkDebounce + "ms) ";
                 if (reason == "") reason = "Unknown Failure (Conditions: decel=" + decelOk + ", sens=" + sensitivityOk + ", speed=" + speedOk + ", debounce=" + debounceOk + ")"; // ADDED decel
                 if (reason != "Unknown Failure") {
                    Debug::Print("Crash", "Bonk IGNORED: " + reason);
                 }
            }
        }

        // --- Update State for Next Frame ---
        // Update state normally if detection ran. If cooldown finished, it was already updated.
        if (!justFinishedCooldown) {
             g_previousVel = currentVel;
             g_previousSpeed = currentSpeed;
             g_previousVdt = vdt_Filtered;
        } else {
             g_previousVdt = vdt_Filtered;
        }

        return bonkEvent;
    }

} // namespace BonkTracker