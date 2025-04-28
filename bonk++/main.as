// --- main.as ---
// Bonk++ Entry Point and Lifecycle Management
// Coordinates other modules (BonkTracker, BonkUI, SoundPlayer).

/**
 * @desc Plugin entry point, called once when the plugin is loaded or reloaded.
 *       Initializes the different modules.
 */
void Main() {
    SoundPlayer::Initialize(); // Load initial sound metadata
    BonkTracker::Initialize(); // Initialize tracker state
    BonkUI::Initialize();      // Initialize UI state
    print("[Bonk++] Plugin Loaded! v" + Meta::ExecutingPlugin().Version);
}

/**
 * @desc Called when the plugin is enabled via UI or programmatically.
 *       Re-initializes modules to reset state.
 */
void OnEnable() {
    print("[Bonk++] Enabled");
    BonkTracker::Initialize();
    BonkUI::Initialize();
    // SoundPlayer::Initialize() might be called here too if sounds need reloading on enable,
    // but LoadSounds is already called on settings change, which often coincides with enabling.
}

/**
 * @desc Called when the plugin is disabled via UI or programmatically.
 *       Ensures visual effects are stopped.
 */
void OnDisable() {
    print("[Bonk++] Disabled");
    BonkUI::DeactivateVisualEffect(); // Ensure visual effect stops if disabled mid-effect
}

/**
 * @desc Called every frame for game logic updates.
 *       Delegates bonk detection and triggers effects based on the result.
 * @param dt Delta time since the last frame in milliseconds.
 */
void Update(float dt) {
    // 1. Check for bonk events using the tracker module
    BonkTracker::BonkEventInfo@ bonkInfo = BonkTracker::UpdateDetection(dt);

    // 2. If a bonk occurred this frame, process effects
    if (bonkInfo !is null) {
        Debug::Print("Main", "Bonk detected by Tracker. Checking effects...");

        // 3. Check if sound should play (global enable + chance check)
        if (Setting_EnableSound) {
            Debug::Print("Playback", "Performing chance check against Setting_BonkChance: " + Setting_BonkChance + "%");
            int chanceRoll = Math::Rand(0, 100); // Random number 0-99

            if (chanceRoll < int(Setting_BonkChance)) {
                // Sound chance succeeded
                Debug::Print("Playback", "Chance success (" + chanceRoll + " < " + Setting_BonkChance + ")! Playing sound...");
                SoundPlayer::PlayBonkSound(); // Delegate to sound player

                // Visual effect only triggers if sound chance succeeded
                if (Setting_EnableVisual) {
                    Debug::Print("Visual", "Visual enabled, triggering effect.");
                    BonkUI::TriggerVisualEffect(); // Delegate to UI module
                } else {
                    Debug::Print("Visual", "Visual Disabled (Setting) - skipped trigger.");
                }

            } else {
                // Sound chance failed
                Debug::Print("Playback", "Chance failed (" + chanceRoll + " >= " + Setting_BonkChance + "). Sound and Visual skipped.");
            }
        } else {
             // Sound globally disabled
             Debug::Print("Playback", "Sound Disabled (Setting). Sound and Visual skipped.");
        }
    }
}

/**
 * @desc Called every frame for rendering non-UI elements (like the vignette).
 *       Delegates rendering to the UI module.
 */
void Render() {
    // Delegate rendering the visual effect
    BonkUI::RenderEffect();
}

// Optional callbacks for future use
// void RenderInterface() { } // For ImGui UI elements rendered outside the main overlay menu
// void RenderMenu() { }      // For items in the plugin's specific menu in the overlay