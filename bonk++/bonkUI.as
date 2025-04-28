// --- bonkUI.as ---
// Handles rendering the visual bonk effect (vignette).

#include "settings" // Needed for settings access and Debug namespace

namespace BonkUI {

    // --- State Variables ---
    bool g_visualActive = false;
    uint64 g_visualStartTime = 0;
    bool g_isInitialized = false;

    // --- Initialization ---
    void Initialize() {
        // Reset state
        g_visualActive = false;
        g_visualStartTime = 0;
        g_isInitialized = true;
        Debug::Print("Visual", "BonkUI Initialized/Reset.");
    }

     // --- Public Control Functions ---
    void TriggerVisualEffect() {
        if (!Setting_EnableVisual) return; // Double check setting
        g_visualActive = true;
        g_visualStartTime = Time::Now;
         Debug::Print("Visual", "Visual Effect Triggered.");
    }

    void DeactivateVisualEffect() {
        if (g_visualActive) {
             Debug::Print("Visual", "Visual Effect Deactivated.");
        }
        g_visualActive = false;
    }


    // --- Rendering Logic ---
    // Called by main.as Render()
    void RenderEffect() {
        if (!Setting_EnableVisual || !g_visualActive) {
            if (g_visualActive) { g_visualActive = false; } // Ensure flag is reset if disabled mid-effect
            return;
        }
         if (!g_isInitialized) Initialize(); // Safety init

        uint64 currentTime = Time::Now;
        uint64 elapsed = currentTime - g_visualStartTime;

        if (elapsed >= Setting_VisualDuration) {
            g_visualActive = false;
             Debug::Print("Visual", "Visual Effect Duration Ended.");
            return;
        }

        float progress = (Setting_VisualDuration > 0) ? (float(elapsed) / float(Setting_VisualDuration)) : 1.0f;
        float currentAlpha = Setting_VisualMaxOpacity * (1.0f - progress);
        currentAlpha = Math::Clamp(currentAlpha, 0.0f, 1.0f);

        float w = float(Draw::GetWidth());
        float h = float(Draw::GetHeight());

        nvg::BeginPath();
        nvg::Rect(0, 0, w, h);

        float radius = h * Setting_VisualRadius;
        float feather = w * Setting_VisualFeather;

        nvg::Paint gradient = nvg::BoxGradient(
                                  vec2(0,0),
                                  vec2(w,h),
                                  radius,
                                  feather,
                                  vec4(0,0,0,0),
                                  vec4(Setting_VisualColor.x, Setting_VisualColor.y, Setting_VisualColor.z, currentAlpha)
                              );

        nvg::FillPaint(gradient);
        nvg::Fill();
         // Debug::Print("Visual", "Rendering effect frame. Alpha: " + currentAlpha); // Too spammy usually
    }

} // namespace BonkUI