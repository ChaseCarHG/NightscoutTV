' main.brs
' RunUserInterface      - launch from home screen; goes to setup if not configured, else live display
' RunScreenSaver        - auto-launched by Roku screensaver timer; shows live display
' RunScreenSaverSettings - Settings > Screensaver > NightscoutTV for Roku > Settings (production)

sub RunUserInterface()
    ' Check if URL is configured; if not, go straight to setup
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
    runSetup()
end sub

sub runLive()
    screen = CreateObject("roSGScreen")
    port   = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    screen.CreateScene("NightscoutLive")
    screen.show()
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub


sub runSetup()
    screen = CreateObject("roSGScreen")
    port   = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    screen.CreateScene("NightscoutSetup")
    screen.show()
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub
