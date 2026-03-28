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
    ' Run the Live Display Graph Screen
    screen = CreateObject("roSGScreen")
    port   = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    screen.CreateScene("NightscoutLive") 'Uses Components NightscoutLive.brs and .xml
    screen.show()
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
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
