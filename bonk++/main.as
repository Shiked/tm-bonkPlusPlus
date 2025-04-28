// --- Bonk++ Plugin ---
// Version: 1.1.0

// --- main.as ---
// Bonk++ Entry Point and Lifecycle Management
// Coordinates other modules (BonkTracker, BonkUI, SoundPlayer).

#include "settings" // Include settings first for global settings vars/debug namespace
#include "bonkTracker"
#include "bonkUI"
#include "soundPlayer"

// Plugin entry point
void Main() {
    SoundPlayer::Initialize(); // Load initial sound metadata
    BonkTracker::Initialize(); // Initialize tracker state if needed
    BonkUI::Initialize();      // Initialize UI state if needed
    print("[Bonk++] Plugin Loaded! v" + Meta::ExecutingPlugin().Version);
}

// Called when the plugin is enabled
void OnEnable() {
    print("[Bonk++] Enabled");
    // Reset any state if necessary upon re-enabling
    BonkTracker::Initialize();
    BonkUI::Initialize();
}

// Called when the plugin is disabled
void OnDisable() {
    print("[Bonk++] Disabled");
    BonkUI::DeactivateVisualEffect(); // Ensure visual effect stops
    // Optionally stop any ongoing sounds if desired
}

// Called every frame for game logic updates
void Update(float dt) {
    // Delegate bonk detection logic
    BonkTracker::BonkEventInfo@ bonkInfo = BonkTracker::UpdateDetection(dt);

    // If a bonk was detected this frame
    if (bonkInfo !is null) {
        Debug::Print("Main", "Bonk detected by Tracker. Triggering effects...");
        // Trigger sound playback logic
        if (Setting_EnableSound) {
            SoundPlayer::PlayBonkSound();
        } else {
             Debug::Print("Playback", "Sound Disabled (Setting) - skipped PlayBonkSound call.");
        }

        // Trigger visual effect logic
        if (Setting_EnableVisual) {
            BonkUI::TriggerVisualEffect();
        } else {
             Debug::Print("Visual", "Visual Disabled (Setting) - skipped TriggerVisualEffect call.");
        }
    }
}

// Called every frame for rendering non-UI elements (like the vignette)
void Render() {
    // Delegate rendering the visual effect
    BonkUI::RenderEffect();
}

// Called every frame for rendering ImGui UI (if needed in the future)
// void RenderInterface() { }

// Called every frame for rendering plugin menu items (if needed)
// void RenderMenu() { }