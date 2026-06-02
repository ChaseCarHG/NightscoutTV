CHANGELOG     
  
TUESDAY 02 JUNE 2926 0 v0.8.00015-Alpha  
DEBUGGING ONLY  
• Working [Issue #11 - No data loaded when launched as Screensaver, yet launches as app works fine.](https://github.com/ChaseCarHG/NightscoutTV/issues/11) by changing main.brs to exit more gracefully and clean up after itself.  
• NOTE: Roku has screensaver debugging output go to :8087 (RAW).  
  
FRIDAY 29 MAY 2926 0 v0.8.00014-Alpha  
  DEBUGGING ONLY  
  • Working [Issue #11 - No data loaded when launched as Screensaver, yet launches as app works fine.](https://github.com/ChaseCarHG/NightscoutTV/issues/11) by adding debug statements in NightscoutLive.brs around init() and onSettingsLoaded().  
  • NOTE: Roku has screensaver debugging output go to :8087 (RAW).  

SUNDAY 29 MAR 2026 - v0.8.00013-Alpha  
  COMPATIBILITY  
  • Addressing [Issue #8 - Enhancement: Support Older Roku OS Versions](https://github.com/ChaseCarHG/NightscoutTV/issues/8) by declaring Minimum Roku OS of v10, and (Roku Scenegraph) rsg_version=1.2, at least until October 2026 when Roku App Certification requirements may be subject to change.   
  
SUNDAY 29 MAR 2026 - v0.8.00012-Alpha  
  BUGFIXES  
  • Tweaks to save timezone after retrieved from server (for after first launch). Prevents clock display from lagging for up to a minute (after first launch).   
  
SUNDAY 29 MAR 2026 - v0.8.00011-Alpha  
  BUGSFIXES  
  • Fixed [Issue #2 - Testing Needed: 12 hour clock](https://github.com/ChaseCarHG/NightscoutTV/issues/2) in NightscoutLive.brs: Right-aligned clock text to graph edge.   
  IMPROVEMENTS   
  • Fixed [Issue #1 - Add Scale Options beyond Logarithmic](https://github.com/ChaseCarHG/NightscoutTV/issues/1)  Added support for Scale per Nightscout server's config, either log or linear. Note log-dynamic falls back to log. Affected NightscoutLive and NightscoutTask files.   
  • Fixed [Issue #6 - Enhancement: Scale Bolus Treatment Indicators (Rectangles & Font) with Dose Size, and Respect Bolus Display Preferences.](https://github.com/ChaseCarHG/NightscoutTV/issues/6)Implemented dynamic sizing of bolus treatments like Nightscout server, and formatting of its text labels to respect config from Nightscout server.  
   
SUNDAY 29 MAR 2026 - V0.8.00010-Alpha   
  PUBLICATION   
  • Updating INITIAL SUBMISSION to Roku Store.  
  • Sent appeal to Roku to allow manually-launched app to remain interactive (for changing timespan displayed) while screensaver remains completely non-interactive.  

  ENHANCEMENTS  
  • Condenced wording in keyboard guidance durign URL entry. 
  
SATURDAY 28 MAR 2026 - V0.8.00009-Alpha   
  PUBLICATION   
  • This version for INITIAL SUBMISSION to Roku Store  
 
SATURDAY 28 MAR 2026 - V0.8.00008-Alpha   
  PUBLICATION   
  • To meet Roku Store Requirements:   
    - Failed to add anything to successfully clear Roku Store warning "EnableLowGeneralMemoryEvent usage not found." It doesn't seem to be implemented.  
    - Added explict exiting of onKeyPress when launched as a screensaver. This ensures screensaver is NOT interactive, to comply with Roku store checks, and actual practical OS limits.  
  
  BUGFIXES  
  • Restored on-screen keyboard messages to provide users guidance on inputs needed (and promote the Nightscout Project too now).  
       
SATURDAY 28 MAR 2026 - V0.8.00007-Alpha  
  PUBLICATION  
  • To meet Roku Store Requirements:  
    - In all .brs files, added _memoryApiStub() dead code stub to satisfy Roku static analyzer for memory API requirements. 
      These APIs are called in source/main.brs runLive(), and serve the entire app. 
      The analyzer requires them to appear as code references within the components directory.

SATURDAY 28 Mar 2026 - V0.8.00006-Alpha   
  PUBLICATION   
  • To meet Roku Store Requirements:  
    - Added right-sized image for Disclaimer Splash Screen in 720p.   
    - Clarified in all .brs files that low-memory warning and event detection is provided by main.brs.  
    - Made screensaver mode clear that it is NOT interactive, whereas some interactivity exists when launched in app mode (limited to change graph timespan, and manually request data refresh).  
  
SATURDAY 28 Mar 2026 - V0.8.00005-Alpha   
  PUBLICATION  
  • Resolved LOADS of Roku Store Errors & Warnings.   
  • Added low memory Warning & Event detection, and output to debugging log at RokuIP:8085 using RAW.  
  • Version Number will now display accurately within the Roku UI.  

SATURDAY 28 Mar 2026 - V0.8.00004-Alpha 
  DEFAULTS  
  • Default display timespan - changed from 3 hours to 4 hours in all places.   
    - All initial on-screen settings remain configurable.   
    - Note that when installing via sideloading, the screensaver settings screen is available only immediately after install via sideload. This is a Roku platform limitation.    
  
  STABILITY  
  • Performed line-by-line review of all code, and added comments heavily throughout.   
  
  
FRIDAY 27 Mar 2026
  DEFAULTS  
  • Default display bolus-threshold - changed from 0.5 to 0.1 in three places: The initial state, and the cycleBolus default index, and when no registry value exists.  
  
  STABILITY  
  • Reduced some Roku reboots - every doFetch* sub now stops and nulls its previous task node before creating a new one. 7 task types × cleanup = no more memory leak caused by node accumulation over hours of runtime.   
  • Fixed a silent exit - all observeField calls replaced with observeFieldScoped including the clock timer and setup disclaimer timer.  
  • Fixed some refresh stalls - m.timer.control = "start" was the single missing line that caused everything. The 60-second timer now actually runs.  
  
  UI  
  • Formatted "Last: HH:mm" as bold text. Split into timeLabelBold (MediumBoldSystemFont, right-aligned to x=1620) and timeLabelAge (MediumSystemFont, right-aligned to x=1860). Both are updated by updateAgeText().   
  • "N minutes ago" always updates - m.ageTimer fires every 30 seconds and calls updateAgeText(m.lastResult) regardless of network state. Even if fetches stall completely, the age text keeps ticking.   
  • Age calculation now computes so user reading screen can subtract clock from last timestamp and concur.   
  • Tried (and failed) to keep On-Screen-Keyboard cursor at the far right of text input. I cannot find a way to do it in Brightscript for Roku. 
    This may get documented as an issue, to improve convenience on users who will later get the app from the Roku store.  
    Meanwhile, the Roku QR Code option for text input from phone feature works.
    Also, the developer instructions to inject default text strings into a sideloaded zip file also works at least for me. 
  • Added GitHub URL to Disclaimer Screen.   
