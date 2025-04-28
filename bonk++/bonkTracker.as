// --- bonkTracker.as ---
// Core logic for detecting bonks based on physics changes (jerk calculation)
// and managing related state like debounce timers.

namespace BonkTracker {

    // --- State Variables ---
    // Store physics data from the previous frame for comparison
    vec3 g_previousVel = vec3(0, 0, 0);         // Vehicle velocity last frame
    float g_previousSpeed = 0.0f;               // Vehicle speed last frame
    vec3 g_previousVdt = vec3(0, 0, 0);         // Filtered velocity change last frame
    uint64 g_lastBonkTime = 0;                  // Timestamp of the last detected bonk (for debouncing)
    bool g_isInitialized = false;               // Flag to ensure state is reset on first run/enable

    // --- Bonk Event Info ---
    // A simple class to pass information about a detected bonk back to the main module.
    // Can be expanded later to include more details (e.g., impact surface, speed).
    class BonkEventInfo {
        float jerkMagnitude = 0.0f; // The calculated jerk value that triggered the bonk
    }

    // --- Initialization ---
    /**
     * @desc Resets the tracker's state variables. Called on plugin load/enable.
     */
    void Initialize() {
        g_previousVel = vec3(0, 0, 0);
        g_previousSpeed = 0.0f;
        g_previousVdt = vec3(0, 0, 0);
        g_lastBonkTime = 0; // Reset debounce
        g_isInitialized = true;
        Debug::Print("Crash", "BonkTracker Initialized/Reset.");
    }

    // --- Helper Functions ---
    /**
     * @desc Counts how many wheels have contact with a surface.
     * @param visState The current vehicle visualization state.
     * @return Integer from 0 to 4 indicating the number of wheels grounded.
     */
    int GetWheelContactCount(CSceneVehicleVisState@ visState) {
        if (visState is null) return 0;
        // Sum 1 for each wheel whose contact material is not the "null" type
        return
            (visState.FLGroundContactMaterial != CSceneVehicleVisState::EPlugSurfaceMaterialId::XXX_Null ? 1 : 0) +
            (visState.FRGroundContactMaterial != CSceneVehicleVisState::EPlugSurfaceMaterialId::XXX_Null ? 1 : 0) +
            (visState.RLGroundContactMaterial != CSceneVehicleVisState::EPlugSurfaceMaterialId::XXX_Null ? 1 : 0) +
            (visState.RRGroundContactMaterial != CSceneVehicleVisState::EPlugSurfaceMaterialId::XXX_Null ? 1 : 0);
    }

    // --- Core Detection Logic ---
    /**
     * @desc Performs bonk detection based on physics changes from the previous frame.
     *       Called every frame by main.as -> Update().
     * @param dt Delta time since the last frame in milliseconds.
     * @return A handle to a BonkEventInfo object if a bonk was detected this frame, otherwise null.
     */
    BonkEventInfo@ UpdateDetection(float dt) {
        if (!g_isInitialized) Initialize(); // Safety check

        // Get current vehicle state (requires VehicleState plugin dependency)
        CSceneVehicleVisState@ visState = VehicleState::ViewingPlayerState();
        if (visState is null) {
            // No vehicle state available, reset internal state and return
            Initialize(); // Resetting ensures we don't use stale data on next valid frame
            return null;
        }

        // Get current physics data
        vec3 currentVel = visState.WorldVel;
        float currentSpeed = currentVel.Length();
        float dtSeconds = dt > 0.0f ? (dt / 1000.0f) : 0.016f; // Convert dt to seconds, handle dt=0 case

        // --- Respawn Check (Optional Dependency) ---
        // If MLFeed/MLHook are available, use them for a more reliable immediate respawn check.
        // This helps prevent false positives right after respawning.
        #if DEPENDENCY_MLFEEDRACEDATA && DEPENDENCY_MLHOOK
            auto mlf = MLFeed::GetRaceData_V3();
            if (mlf !is null) {
                 auto plf = mlf.GetPlayer_V3(MLFeed::LocalPlayersName);
                 if (plf !is null) {
                    const uint INVALID_TIME = 0xFFFFFFFF; // Constant used by MLFeed
                    bool lastTimeValid = (plf.LastRespawnRaceTime < INVALID_TIME);
                    bool currentTimeValid = (plf.CurrentRaceTime < INVALID_TIME);
                    // Check if respawn happened very recently (within 100ms)
                    bool isRecentRespawn = (lastTimeValid && currentTimeValid && plf.CurrentRaceTime < (plf.LastRespawnRaceTime + uint(100)));

                    // If player isn't fully spawned OR just respawned, reset state and exit
                    if (plf.spawnStatus != MLFeed::SpawnStatus::Spawned || isRecentRespawn) {
                        Debug::Print("Crash", "MLFeed detected Not Spawned ("+plf.spawnStatus+") or Recent Respawn ("+isRecentRespawn+"). Resetting state.");
                        Initialize(); // Reset physics state
                        g_lastBonkTime = Time::Now; // Reset debounce too
                        return null; // No bonk detection this frame
                    }
                }
            }
        #endif
        // --- End of Respawn Check ---

        // --- Bonk Detection Algorithm ---

        // 1. Preliminary Acceleration Check: Is there significant deceleration?
        //    Compares instantaneous deceleration to a dynamic threshold based on speed.
        float currentAccel = (dtSeconds > 0) ? Math::Max(0.0f, (g_previousSpeed - currentSpeed) / dtSeconds) : 0.0f;
        float dynamicThreshold = Setting_BonkThreshold + g_previousSpeed * 1.5f; // Threshold increases with speed
        bool preliminaryBonkDetected = currentAccel > dynamicThreshold;

        // 2. Filtered Jerk Calculation: How abrupt was the change in filtered velocity?
        //    (Only calculate fully if preliminary check passed or debug enabled, for performance)
        float jerkMagnitude = 0.0f;
        vec3 vdt_Filtered = vec3(0,0,0); // Filtered velocity change for *this* frame

        if (preliminaryBonkDetected || (Setting_Debug_EnableMaster && Setting_Debug_Crash)) {
            vec3 vdt = currentVel - g_previousVel; // Raw velocity change

            // Filter 1: Remove vertical component (bumps)
            float vdtUp = Math::Dot(vdt, visState.Up);
            vec3 vdt_NoVertical = vdt - visState.Up * vdtUp;
            vdt_Filtered = vdt_NoVertical; // Start with vertically filtered change

            // Filter 2: Remove forward component (braking) IF the change is forwards
            // This is the part that ignores most reverse impacts
            float forwardComponent = Math::Dot(vdt_NoVertical, visState.Dir);
            if (forwardComponent > 0) {
                vdt_Filtered = vdt_NoVertical - visState.Dir * forwardComponent;
            }

            // Calculate Jerk: Change between this frame's filtered vdt and last frame's
            vec3 vdtdt = vdt_Filtered - g_previousVdt; // g_previousVdt is the vdt_Filtered from LAST frame
            jerkMagnitude = vdtdt.Length(); // Magnitude of the jerk vector

            // Debug log if preliminary check passed
            if (preliminaryBonkDetected) {
                 Debug::Print("Crash", "Preliminary Detect Passed! Accel: " + currentAccel + ", DynThresh: " + dynamicThreshold);
                 Debug::Print("Crash", "  -> Jerk Mag (vdtdt.Length): " + jerkMagnitude);
            }
        }

        // 3. Sensitivity Check: Is the jerk magnitude above the threshold based on wheel contact?
        int wheelContactCount = GetWheelContactCount(visState);
        float sensitivityThreshold = (wheelContactCount == 4) ? Setting_SensitivityGrounded : Setting_SensitivityAirborne;
        bool sensitivityOk = jerkMagnitude > sensitivityThreshold;

        // 4. Debounce & Speed Check: Has enough time passed since the last bonk? Was the car moving fast enough before?
        uint64 currentTime = Time::Now;
        bool debounceOk = (currentTime - g_lastBonkTime) > Setting_BonkDebounce;
        bool speedOk = g_previousSpeed > 10.0f; // Arbitrary minimum speed threshold

        // 5. Final Decision: If all checks pass, it's a bonk!
        BonkEventInfo@ bonkEvent = null; // Prepare return value (null by default)
        if (preliminaryBonkDetected && sensitivityOk && speedOk && debounceOk) {
            // Bonk detected!
            g_lastBonkTime = currentTime; // Reset debounce timer
            Debug::Print("Crash", "Bonk CONFIRMED! JerkMag: " + jerkMagnitude + " > SensThresh: " + sensitivityThreshold);

            // Create info object to return to main module
            @bonkEvent = BonkEventInfo();
            bonkEvent.jerkMagnitude = jerkMagnitude;
            // Can add more info here later (e.g., bonkEvent.speed = g_previousSpeed;)

        } else if (preliminaryBonkDetected && Setting_Debug_Crash) {
            // Log reasons why a potential bonk was ignored (if debug enabled)
            if (!sensitivityOk) Debug::Print("Crash", "Bonk IGNORED: Jerk Magnitude (" + jerkMagnitude + ") <= Sensitivity Threshold (" + sensitivityThreshold + ")");
            else if (!speedOk) Debug::Print("Crash", "Bonk IGNORED: Previous Speed (" + g_previousSpeed + ") <= 10");
            else if (!debounceOk) Debug::Print("Crash", "Bonk IGNORED: Debounce Active (LastBonk: " + g_lastBonkTime + ", Now: " + currentTime + ")");
            else Debug::Print("Crash", "Bonk IGNORED: Unknown reason (Conditions: prelim=" + preliminaryBonkDetected + ", sens=" + sensitivityOk + ", speed=" + speedOk + ", debounce=" + debounceOk + ")");
        }

        // --- Update State for Next Frame ---
        // Store current values for the next frame's calculation
        g_previousVel = currentVel;
        g_previousSpeed = currentSpeed;
        g_previousVdt = vdt_Filtered; // Store the filtered velocity change from *this* frame

        return bonkEvent; // Return the info object (or null)
    }

} // namespace BonkTracker