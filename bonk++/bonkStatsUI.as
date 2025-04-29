// --- bonkStatsUI.as ---
// Handles rendering the Bonk Counter statistics GUI window.
// V1.1 - Added check to hide GUI when not actively playing on a map.

namespace BonkStatsUI {

    /**
     * @desc Renders the Bonk Counter GUI window if enabled in settings
     *       AND if the player is currently in an active gameplay state.
     *       Accesses global settings (Setting_*) and stats (g_*) from main/settings.
     *       Uses tables for aligned stat display.
     */
    void RenderGUIWindow() {
        // --- Early Exit Checks ---

        // 1. Check if the GUI is globally enabled in settings
        if (!Setting_EnableBonkCounterGUI) {
            return;
        }

        // 2. *** NEW CHECK: Check if the player is actively playing ***
        //    Uses the function defined in main.as
        if (!IsPlayerActivelyPlaying()) {
            // If debugging GUI, log why we're skipping
            if (Setting_Debug_EnableMaster && Setting_Debug_GUI) {
                Debug::Print("GUI", "Skipping GUI render: IsPlayerActivelyPlaying() returned false.");
            }
            // Don't render the window if not in an active play state (e.g., menus, editor)
            return;
        }

        // 3. Check if the overlay itself is hidden AND if the setting requires hiding with overlay
        if (!Setting_GUIAlwaysVisible && !UI::IsOverlayShown()) {
             if (Setting_Debug_EnableMaster && Setting_Debug_GUI) {
                 Debug::Print("GUI", "Skipping GUI render: Overlay hidden and 'Always Show' is off.");
             }
            return;
        }
        // --- End Early Exit Checks ---

        // --- Determine Window Flags and Condition ---
        int windowFlags = UI::WindowFlags::NoCollapse | UI::WindowFlags::NoTitleBar;
        UI::Cond positionCondition = UI::Cond::FirstUseEver;
        UI::Cond sizeCondition = UI::Cond::FirstUseEver;
        float windowWidth = Setting_GUIWidth;
        float windowHeight = 0.0f; // Default to auto-resize

        if (Setting_GUILocked) {
            windowFlags |= UI::WindowFlags::NoResize;
            windowFlags |= UI::WindowFlags::NoMove;
            positionCondition = UI::Cond::Always;
            sizeCondition = UI::Cond::Always;
            windowHeight = Setting_GUIHeight; // Use fixed height only when locked
             if (Setting_Debug_EnableMaster && Setting_Debug_GUI) Debug::Print("GUI", "Window Locked: Using fixed height: " + windowHeight);
        } else {
            windowFlags |= UI::WindowFlags::AlwaysAutoResize; // Auto-resize when not locked
             if (Setting_Debug_EnableMaster && Setting_Debug_GUI) Debug::Print("GUI", "Window Unlocked: Using AlwaysAutoResize for height.");
        }

        // --- Set Window Position & Size ---
        UI::SetNextWindowPos(int(Setting_GUIPosX), int(Setting_GUIPosY), positionCondition);
        // Set width always, height only if locked (otherwise relies on auto-resize)
        UI::SetNextWindowSize(int(windowWidth), int(windowHeight), sizeCondition);

        // --- Begin the Window ---
        // The boolean reference (&Setting_EnableBonkCounterGUI) allows the user to close the window
        // via the (invisible) title bar X if it's NOT locked, effectively disabling the setting.
        // If locked, the boolean reference has no effect as the close button isn't available.
        if (UI::Begin("Bonk Counter", Setting_EnableBonkCounterGUI, windowFlags)) {

            // --- Check if ANY stats are enabled ---
            bool statsEnabled = Setting_ShowSessionBonks || Setting_ShowMapBonks ||
                                Setting_ShowMapMaxSpeed || Setting_ShowLastBonkSpeed ||
                                Setting_ShowBonkRate || Setting_ShowAllTimeBonks ||
                                Setting_ShowHighestAllTimeBonk;

            if (statsEnabled) {
                // --- Use a Table for Stat Display ---
                int tableFlags = UI::TableFlags::SizingStretchProp | UI::TableFlags::PadOuterX;
                if (UI::BeginTable("StatsTable", 2, tableFlags)) {

                    // --- Display Stats Conditionally ---
                    // (Stat rendering logic remains exactly the same as before)
                    if (Setting_ShowSessionBonks) {
                        UI::TableNextRow(); UI::TableNextColumn();
                        if (Setting_UseCompactLabels) { UI::Text("Session Bonks:"); }
                        else { UI::Text(Icons::Play + " Total Session Bonks:"); }
                        UI::TableNextColumn(); UI::Text("" + g_sessionTotalBonks);
                    }
                    if (Setting_ShowMapBonks) {
                        UI::TableNextRow(); UI::TableNextColumn();
                        if (Setting_UseCompactLabels) { UI::Text("Map Bonks:"); }
                        else { UI::Text(Icons::Map + " Total Map Bonks:"); }
                        UI::TableNextColumn(); UI::Text("" + g_mapTotalBonks);
                    }
                    if (Setting_ShowAllTimeBonks) {
                         UI::TableNextRow(); UI::TableNextColumn();
                         if (Setting_UseCompactLabels) { UI::Text("Total Bonks:"); UI::TableNextColumn(); UI::Text("" + g_totalAllTimeBonks); }
                         else { UI::Text(Icons::Globe + " You have bonked:"); UI::TableNextColumn(); UI::Text("" + g_totalAllTimeBonks + " times"); }
                    }
                    if (Setting_ShowHighestAllTimeBonk) {
                         UI::TableNextRow(); UI::TableNextColumn();
                         if (Setting_UseCompactLabels) { UI::Text("Fastest Bonk:"); UI::TableNextColumn(); string s = (g_highestAllTimeBonkSpeedKmh > 0.1f) ? Text::Format("%.2f", g_highestAllTimeBonkSpeedKmh) : "N/A"; UI::Text(s); }
                         else { UI::Text(Icons::Star + " Fastest Bonk Ever:"); UI::TableNextColumn(); string s = (g_highestAllTimeBonkSpeedKmh > 0.1f) ? Text::Format("%.2f", g_highestAllTimeBonkSpeedKmh) : "N/A"; UI::Text(s + " Units"); }
                    }
                    if (Setting_ShowMapMaxSpeed) {
                        UI::TableNextRow(); UI::TableNextColumn();
                        if (Setting_UseCompactLabels) { UI::Text("Map Fastest:"); UI::TableNextColumn(); string s = (g_mapHighestBonkSpeed > 0.1f) ? Text::Format("%.2f", g_mapHighestBonkSpeed) : "N/A"; UI::Text(s); }
                        else { UI::Text(Icons::Tachometer + " Fastest Bonk (map):"); UI::TableNextColumn(); string s = (g_mapHighestBonkSpeed > 0.1f) ? Text::Format("%.2f", g_mapHighestBonkSpeed) : "N/A"; UI::Text(s + " Units"); }
                    }
                    if (Setting_ShowLastBonkSpeed) {
                        UI::TableNextRow(); UI::TableNextColumn();
                        if (Setting_UseCompactLabels) { UI::Text("Last Speed:"); UI::TableNextColumn(); string s = (g_lastBonkSpeedKmh > 0.1f) ? Text::Format("%.2f", g_lastBonkSpeedKmh) : "N/A"; UI::Text(s); }
                        else { UI::Text(Icons::History + " Last Speed:"); UI::TableNextColumn(); string s = (g_lastBonkSpeedKmh > 0.1f) ? Text::Format("%.2f", g_lastBonkSpeedKmh) : "N/A"; UI::Text(s + " Units"); }
                    }
                    if (Setting_ShowBonkRate) {
                         UI::TableNextRow(); UI::TableNextColumn();
                         if (Setting_UseCompactLabels) { UI::Text("BPM:"); UI::TableNextColumn(); string s = "N/A"; if (g_mapActiveTimeSeconds > 5.0f && g_mapTotalBonks > 0) { s = Text::Format("%.1f", (float(g_mapTotalBonks) / g_mapActiveTimeSeconds) * 60.0f); } UI::Text(s); }
                         else { UI::Text(Icons::BarChart + " Bonks Per Min:"); UI::TableNextColumn(); string s = "N/A"; if (g_mapActiveTimeSeconds > 5.0f && g_mapTotalBonks > 0) { s = Text::Format("%.1f/min", (float(g_mapTotalBonks) / g_mapActiveTimeSeconds) * 60.0f); } UI::Text(s); }
                    }
                    UI::EndTable();
                } // End if BeginTable
            } else {
                // Show message if no stats are enabled AND window isn't locked (otherwise fixed height might look weird)
                 if (!Setting_GUILocked) {
                    UI::TextDisabled("(No stats enabled in settings)");
                 }
            }

            // Optional padding removed as auto-resize handles it better

        }
        UI::End(); // Must always call End() if Begin() was called
    }

} // namespace BonkStatsUI