// --- bonkTracker.as ---
// Core logic for detecting bonks and managing related state.

#include "settings" // Needed for settings access and Debug namespace

namespace BonkTracker {

    // --- State Variables ---
    // Encapsulated within the namespace
    vec3 g_previousVel = vec3(0, 0, 0);
    float g_previousSpeed = 0.0f;
    vec3 g_previousVdt = vec3(0, 0, 0); // Stores the filtered velocity change from the previous frame
    uint64 g_lastBonkTime = 0;
    bool g_isInitialized = false;

    // --- Bonk Event Info ---
    // Simple class to return information about a detected bonk (can be expanded later)
    class BonkEventInfo {
        float jerkMagnitude = 0.0f;
        // Add other info like impact speed, position, surface type etc. if needed
    }

    // --- Initialization ---
    void Initialize() {
        // Reset state variables if needed (e.g., on plugin load/enable)
        g_previousVel = vec3(0, 0, 0);
        g_previousSpeed = 0.0f;
        g_previousVdt = vec3(0, 0, 0);
        g_lastBonkTime = 0; // Reset debounce timer
        g_isInitialized = true;
         Debug::Print("Crash", "BonkTracker Initialized/Reset.");
    }

    // --- Helper Functions ---
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

    // --- Core Detection Logic ---
    // Called by main.as Update()
    // Returns a BonkEventInfo object if a bonk occurred, otherwise null.
    BonkEventInfo@ UpdateDetection(float dt) {
        if (!g_isInitialized) Initialize(); // Ensure initialized

        // Need the VehicleState dependency for this
        CSceneVehicleVisState@ visState = VehicleState::ViewingPlayerState();
        if (visState is null) {
            // Reset state if we lose the vehicle visualization
            g_previousVel = vec3(0,0,0); g_previousSpeed = 0.0f; g_previousVdt = vec3(0,0,0);
            return null; // No bonk possible
        }

        vec3 currentVel = visState.WorldVel;
        float currentSpeed = currentVel.Length();
        // Ensure dtSeconds is not zero to prevent division errors
        float dtSeconds = dt > 0.0f ? (dt / 1000.0f) : 0.016f; // Use a small default if dt is 0

        // --- Respawn Check using MLFeed (if available) ---
        #if DEPENDENCY_MLFEEDRACEDATA && DEPENDENCY_MLHOOK
            auto mlf = MLFeed::GetRaceData_V3();
            if (mlf !is null) {
                 auto plf = mlf.GetPlayer_V3(MLFeed::LocalPlayersName);
                 if (plf !is null) {
                    const uint INVALID_TIME = 0xFFFFFFFF;
                    bool lastTimeValid = (plf.LastRespawnRaceTime < INVALID_TIME);
                    bool currentTimeValid = (plf.CurrentRaceTime < INVALID_TIME);
                    bool isRecentRespawn = (lastTimeValid && currentTimeValid && plf.CurrentRaceTime < (plf.LastRespawnRaceTime + uint(100)));

                    if (plf.spawnStatus != MLFeed::SpawnStatus::Spawned || isRecentRespawn) {
                        Debug::Print("Crash", "MLFeed detected Not Spawned ("+plf.spawnStatus+") or Recent Respawn ("+isRecentRespawn+"). Resetting state.");
                        // Reset state immediately
                        Initialize();
                        g_lastBonkTime = Time::Now; // Also reset debounce specifically
                        return null; // Exit immediately, no bonk
                    }
                }
            }
        #endif
        // --- End of MLFeed Check ---

        // --- Bonk Detection Logic ---
        float currentAccel = (dtSeconds > 0) ? Math::Max(0.0f, (g_previousSpeed - currentSpeed) / dtSeconds) : 0.0f;
        float dynamicThreshold = Setting_BonkThreshold + g_previousSpeed * 1.5f;
        bool preliminaryBonkDetected = currentAccel > dynamicThreshold;

        float jerkMagnitude = 0.0f;
        vec3 vdt_Filtered = vec3(0,0,0);

        if (preliminaryBonkDetected || (Setting_Debug_EnableMaster && Setting_Debug_Crash)) {
            vec3 vdt = currentVel - g_previousVel;
            float vdtUp = Math::Dot(vdt, visState.Up);
            vec3 vdt_NoVertical = vdt - visState.Up * vdtUp;
            vdt_Filtered = vdt_NoVertical;
            float forwardComponent = Math::Dot(vdt_NoVertical, visState.Dir);
            if (forwardComponent > 0) {
                vdt_Filtered = vdt_NoVertical - visState.Dir * forwardComponent;
            }
            vec3 vdtdt = vdt_Filtered - g_previousVdt;
            jerkMagnitude = vdtdt.Length();

            if (preliminaryBonkDetected) {
                 Debug::Print("Crash", "Preliminary Detect Passed! Accel: " + currentAccel + ", DynThresh: " + dynamicThreshold);
                 Debug::Print("Crash", "  -> Jerk Mag (vdtdt.Length): " + jerkMagnitude);
            }
        }

        int wheelContactCount = GetWheelContactCount(visState);
        float sensitivityThreshold = (wheelContactCount == 4) ? Setting_SensitivityGrounded : Setting_SensitivityAirborne;

        uint64 currentTime = Time::Now;
        bool debounceOk = (currentTime - g_lastBonkTime) > Setting_BonkDebounce;
        bool speedOk = g_previousSpeed > 10.0f;
        bool sensitivityOk = jerkMagnitude > sensitivityThreshold;

        BonkEventInfo@ bonkEvent = null; // Initialize as null

        if (preliminaryBonkDetected && sensitivityOk && speedOk && debounceOk) {
            g_lastBonkTime = currentTime;
            Debug::Print("Crash", "Bonk CONFIRMED! JerkMag: " + jerkMagnitude + " > SensThresh: " + sensitivityThreshold);

            // Create and populate BonkEventInfo
            @bonkEvent = BonkEventInfo();
            bonkEvent.jerkMagnitude = jerkMagnitude;
            // Populate with more info if needed

        } else if (preliminaryBonkDetected && Setting_Debug_Crash) {
            if (!sensitivityOk) Debug::Print("Crash", "Bonk IGNORED: Jerk Magnitude (" + jerkMagnitude + ") <= Sensitivity Threshold (" + sensitivityThreshold + ")");
            else if (!speedOk) Debug::Print("Crash", "Bonk IGNORED: Previous Speed (" + g_previousSpeed + ") <= 10");
            else if (!debounceOk) Debug::Print("Crash", "Bonk IGNORED: Debounce Active (LastBonk: " + g_lastBonkTime + ", Now: " + currentTime + ")");
            else Debug::Print("Crash", "Bonk IGNORED: Unknown reason (Conditions: prelim=" + preliminaryBonkDetected + ", sens=" + sensitivityOk + ", speed=" + speedOk + ", debounce=" + debounceOk + ")");
        }

        // --- Update State for Next Frame ---
        g_previousVel = currentVel;
        g_previousSpeed = currentSpeed;
        g_previousVdt = vdt_Filtered;

        return bonkEvent; // Return the info object (or null if no bonk)
    }

} // namespace BonkTracker