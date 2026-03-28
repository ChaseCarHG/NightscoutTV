' main.brs
' RunUserInterface       - Launch from home screen; goes to setup if not configured, else live display
' RunScreenSaver         - Auto-launched by Roku screensaver timer; shows live display
' RunScreenSaverSettings - Settings > Themes > Screensaver > NightscoutTV for Roku > Settings (production)

sub RunUserInterface()
    ' Launch from home screen; goes to setup if not configured, else live display
    ' First, check if URL is configured; if not, go straight to setup
    sec = CreateObject("roRegistrySection", "nightscout")
    if sec.Exists("url") and sec.Read("url") <> ""
        runLive()
    else
        runSetup()
        runLive()
    end if
end sub

sub RunScreenSaver()
    runLive()
end sub

sub RunScreenSaverSettings()
    ' Settings > Themes > Screensaver > NightscoutTV for Roku > Settings (production)
    ' Auto-launched by Roku screensaver timer; shows live display
    runSetup()
end sub

sub runLive()
    ' Create the SceneGraph screen and message port. 
    ' The port receives all system events for this screen. 
    screen = CreateObject("roSGScreen")
    port   = CreateObject("roMessagePort")
    screen.setMessagePort(port)

    ' Load and display the NightscoutLive scene component. 
    ' This triggers NightscoutLive.brs init() on the render thread. 
    screen.CreateScene("NightscoutLive")
    screen.show()

    ' Register for Roku memory warning events, as required by Roku certification (RSG 1.3 / Requirement 4.x).
    ' Gives Roku a way to warn us before we run out of memory, on the RokuIP:8085 port using RAW ouput.
    app = CreateObject("roAppManager")
    app.EnableLowGeneralMemoryEvent(true)   ' fires roAppMemoryNotification when memory is low or critical
    app.EnableMemoryWarningEvent(true)       ' companion API - enables the older memory warning system

    ' Main event loop - runs for the lifetime of the live screen. The wait(0, port) blocks indefinitely until any message arrives.
    while true
        msg = wait(0, port)

        if type(msg) = "roSGScreenEvent"
            ' Screen was closed (e.g. user pressed Back, or OS dismissed screensaver).
            ' Returning here exits runLive() and returns control to the caller
            ' (RunUserInterface or RunScreenSaver in main.brs).
            if msg.isScreenClosed() then return

        else if type(msg) = "roAppMemoryNotification"
            ' Roku is warning us that system memory is running low.
            ' Gather all available memory diagnostics for the debug log.
            level      = msg.GetGeneralMemoryLevel()  ' "low" or "critical"
            limitPct   = app.GetMemoryLimitPercent()  ' % of our memory budget currently used
            available  = app.GetChannelAvailableMemory() ' bytes still available to us
            limitBytes = app.GetChannelMemoryLimit()     ' our total memory budget in bytes

            ' Print a clearly visible block to port 8085 (Raw mode PuTTY).
            print "=============================="
            print "MEMORY WARNING"
            print "  Level:     " level
            print "  Used:      " limitPct "% of limit"
            print "  Available: " available " bytes"
            print "  Limit:     " limitBytes " bytes"
            print "=============================="

            if level = "critical"
                ' Memory is critically low - if we stay running we risk a Roku reboot.
                ' Exit gracefully now so the OS can reclaim our memory cleanly.
                ' The user will be returned to the Roku home screen.
                print "MEMORY CRITICAL - Exiting gracefully to free resources."
                return
            end if
            ' If level = "low" we log it but stay running.
            ' "low" is a heads-up; "critical" is the point of no return.

        end if
    end while
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
