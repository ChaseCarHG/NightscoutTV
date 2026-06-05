' main.brs
' RunUserInterface       - Launch from home screen; goes to setup if not configured, else live display
' RunScreenSaver         - Auto-launched by Roku screensaver timer; shows live display
' RunScreenSaverSettings - Settings > Themes > Screensaver > NightscoutTV for Roku > Settings (production)

sub RunUserInterface()
    ' Launch from home screen; goes to setup if not configured, else live display
    ' First, check if URL is configured; if not, go straight to setup
    sec = CreateObject("roRegistrySection", "nightscout")
    if sec.Exists("url") and sec.Read("url") <> ""
        runLive(false)
    else
        runSetup()
        runLive(false)
    end if
end sub

sub RunScreenSaver()
    runLive(true)
end sub

sub RunScreenSaverSettings()
    ' Settings > Themes > Screensaver > NightscoutTV for Roku > Settings (production)
    ' Auto-launched by Roku screensaver timer; shows live display
    runSetup()
end sub

sub runLive(isScreensaver as Boolean)
    ' Create the SceneGraph screen and message port. 
    ' The port receives all system events for this screen. 
    screen = CreateObject("roSGScreen")
    port   = CreateObject("roMessagePort")
    screen.setMessagePort(port)

    ' Signal launch context to the scene via global node. 
    ' Must be set BEFORE CreateScene so init() can read it immediately. 
    ' isScreensaver=true hides interactive button hints in the footer, and display of other timespan options. 
    glb = screen.getGlobalNode()
    glb.addField("isScreensaver", "boolean", false)
    glb.isScreensaver = isScreensaver

    ' Load and display the NightscoutLive scene component. 
    ' This triggers NightscoutLive.brs init() on the render thread. 
    screen.CreateScene("NightscoutLive")
    screen.show()

    ' Register for Roku memory warning events, as required by Roku certification (RSG 1.3 / Requirement 4.x). 
    ' Gives Roku a way to warn us before we run out of memory, on the RokuIP:8085 port using RAW ouput. 
    ' roAppMemoryMonitor is the current Roku-recommended memory API (replaces legacy roAppManager). 
    ' SetMessagePort routes memory events to the same port as screen events - one wait() handles both. 
    appMonitor = CreateObject("roAppMemoryMonitor")
    appMonitor.EnableMemoryWarningEvent(true)
    appMonitor.SetMessagePort(port)

    ' Log memory thresholds to port 8085 at startup for diagnostics. 
    print "=============================="
    print "MEMORY MONITOR INITIALIZED"
    print "  Limit %:   " appMonitor.GetMemoryLimitPercent()
    print "  Available: " appMonitor.GetChannelAvailableMemory() " bytes"
    lim = appMonitor.GetChannelMemoryLimit()
    print "  Limit (fg): " lim.maxForegroundMemory " bytes"
    print "  Limit (bg): " lim.maxBackgroundMemory " bytes"
    print "=============================="

    ' Main event loop - runs for the lifetime of the live screen. The wait(0, port) blocks indefinitely until any message arrives.
    while true
        msg = wait(0, port)

        'if msg.isScreenClosed() then exit while 'Disabled as redundant code while trying to address Issue #11

        if type(msg) = "roSGScreenEvent"
            ' Screen was closed (e.g. user pressed Back, or OS dismissed screensaver).
            ' Returning here exits runLive() and returns control to the caller
            ' (RunUserInterface or RunScreenSaver in main.brs).
            if msg.isScreenClosed() 
                screen.getScene().close = true
                exit while
            end if

        else if type(msg) = "roAppMemoryMonitorEvent"
            ' Roku is warning us that system memory is running low. 
            ' Gather all available memory diagnostics for the debug log. 
            print "=============================="
            print "MEMORY WARNING"
            lim = appMonitor.GetChannelMemoryLimit()
            print "  Available: " appMonitor.GetChannelAvailableMemory() " bytes"
            print "  Limit %:   " appMonitor.GetMemoryLimitPercent()
            print "  Limit (fg): " lim.maxForegroundMemory " bytes"
            print "  Limit (bg): " lim.maxBackgroundMemory " bytes"
            print "=============================="

            if msg.isLowGeneralMemory()
                ' Memory is critically low - if we stay running we risk a Roku reboot. 
                ' Exit gracefully now so the OS can reclaim our memory cleanly. 
                ' The user will be returned to the Roku home screen. 
                print "MEMORY CRITICAL - Exiting gracefully to free resources."
                screen.getScene().close = true
                exit while
            end if
            ' Non-critical warning: logged above, stay running. 
            ' "low" is a heads-up; let the OS manage from here. 
        end if

    end while
    
    ' Explicit cleanup - null all refs so GC reclaims immediately. 
    ' Prevents lingering instances across screensaver launches.
    print "runLive() exiting - releasing resources"
    screen = invalid
    port = invalid
    appMonitor = invalid
    lim = invalid
    print "runLive resource releases completed"
end sub


sub runSetup()
    ' Run the Setup Screen
    screen = CreateObject("roSGScreen")
    port   = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    screen.CreateScene("NightscoutSetup") 'Uses Components NightscoutSetup.brs and .xml
    screen.show()
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub
