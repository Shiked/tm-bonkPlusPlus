// --- bonkUI.as ---
// Handles rendering the visual bonk effect (vignette using NanoVG).

namespace BonkUI {

    // --- State Variables ---
    bool g_visualActive = false;        // Is the effect currently being displayed?
    uint64 g_visualStartTime = 0;       // Timestamp when the current effect started
    bool g_isInitialized = false;       // Flag to ensure state is reset on first run/enable

    // --- Initialization ---
    /**
     * @desc Resets the visual effect state. Called on plugin load/enable.
     */
    void Initialize() {
        g_visualActive = false;
        g_visualStartTime = 0;
        g_isInitialized = true;
        Debug::Print("Visual", "BonkUI Initialized/Reset.");
    }

     // --- Public Control Functions ---
     /**
      * @desc Starts the visual effect if it's enabled in settings.
      *       Called by main.as when a bonk is confirmed and sound chance passes.
      */
    void TriggerVisualEffect() {
        if (!Setting_EnableVisual) return; // Double-check setting just in case
        g_visualActive = true;
        g_visualStartTime = Time::Now; // Record start time
         Debug::Print("Visual", "Visual Effect Triggered.");
    }

    /**
     * @desc Immediately stops the visual effect. Called when the plugin is disabled.
     */
    void DeactivateVisualEffect() {
        if (g_visualActive) {
             Debug::Print("Visual", "Visual Effect Deactivated.");
        }
        g_visualActive = false;
    }


    // --- Rendering Logic ---
    /**
     * @desc Draws the vignette effect if active. Called every frame by main.as -> Render().
     */
    void RenderEffect() {
        // Exit early if the effect isn't enabled or isn't currently active
        if (!Setting_EnableVisual || !g_visualActive) {
            // Ensure flag is reset if disabled externally while active
            if (g_visualActive) { g_visualActive = false; }
            return;
        }
        if (!g_isInitialized) Initialize(); // Safety check

        // Calculate effect progress and alpha
        uint64 currentTime = Time::Now;
        uint64 elapsed = currentTime - g_visualStartTime;

        // Check if effect duration has passed
        if (elapsed >= Setting_VisualDuration) {
            g_visualActive = false; // Deactivate effect
            Debug::Print("Visual", "Visual Effect Duration Ended.");
            return;
        }

        // Calculate alpha based on time elapsed (linear fade out)
        float progress = (Setting_VisualDuration > 0) ? (float(elapsed) / float(Setting_VisualDuration)) : 1.0f;
        float currentAlpha = Setting_VisualMaxOpacity * (1.0f - progress); // Fade from max opacity to 0
        currentAlpha = Math::Clamp(currentAlpha, 0.0f, 1.0f); // Ensure alpha is valid

        // Get screen dimensions for drawing
        float w = float(Draw::GetWidth());
        float h = float(Draw::GetHeight());

        // Draw using NanoVG (nvg namespace)
        nvg::BeginPath();
        // Define the drawing area as the entire screen
        nvg::Rect(0, 0, w, h);

        // Calculate gradient parameters based on settings and screen size
        float radius = h * Setting_VisualRadius;   // Corner rounding relative to height
        float feather = w * Setting_VisualFeather; // Gradient feathering relative to width

        // Create the vignette gradient (transparent center, colored edges)
        nvg::Paint gradient = nvg::BoxGradient(
                                  vec2(0,0),          // Top-left position
                                  vec2(w,h),          // Size (bottom-right position relative to top-left)
                                  radius,             // Corner radius
                                  feather,            // Feathering width
                                  vec4(0,0,0,0),      // Inner color (fully transparent black)
                                  vec4(Setting_VisualColor.x, Setting_VisualColor.y, Setting_VisualColor.z, currentAlpha) // Outer color (user-defined color with calculated alpha)
                              );

        // Apply the gradient paint and fill the rectangle
        nvg::FillPaint(gradient);
        nvg::Fill();
        // nvg::ClosePath(); // Generally not needed after nvg::Fill()
    }

} // namespace BonkUI