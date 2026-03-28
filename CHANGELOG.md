CHANGELOG  
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
