' NightscoutSetup.brs
' Row 0=URL, Row 1=Token, Row 2=Units, Row 3=Default Display, Row 4=Bolus Threshold, Row 5=Save

sub init()
    m.focusBar     = m.top.findNode("focusBar")
    m.urlDisplay   = m.top.findNode("urlDisplay")
    m.tokenDisplay = m.top.findNode("tokenDisplay")
    m.chkMgBox     = m.top.findNode("chkMgBox")
    m.chkMgMark    = m.top.findNode("chkMgMark")
    m.chkMmolBox   = m.top.findNode("chkMmolBox")
    m.chkMmolMark  = m.top.findNode("chkMmolMark")
    m.hoursDisplay = m.top.findNode("hoursDisplay")
    m.bolusDisplay = m.top.findNode("bolusDisplay")
    m.basalDisplay = m.top.findNode("basalDisplay")
    m.setupStatus        = m.top.findNode("setupStatus")
    m.disclaimerOverlay  = m.top.findNode("disclaimerOverlay")

    ' Disclaimer timer - hide overlay after 8 seconds
    m.discTimer          = CreateObject("roSGNode", "Timer")
    m.discTimer.duration = 8
    m.discTimer.repeat   = false
    m.discTimer.observeFieldScoped("fire", "onDisclaimerTimer")
    m.discTimer.control  = "start"

    m.saveTask      = invalid
    m.nsUrl         = ""
    m.nsToken       = ""
    m.unitsMgdl     = true
    m.graphHours    = 3
    m.bolusMinU     = 0.1
    m.basalRender   = "icicle"
    m.focusRow      = 0
    m.dialogPurpose = ""

    refreshDisplay()
    moveFocus(0)

    m.loadTask = CreateObject("roSGNode", "NightscoutTask")
    m.loadTask.observeFieldScoped("settingsLoaded", "onSettingsLoaded")
    m.loadTask.action  = "load"
    m.loadTask.control = "RUN"

    m.top.setFocus(true)
end sub

sub onDisclaimerTimer()
    if m.disclaimerOverlay <> invalid
        m.disclaimerOverlay.visible = false
    end if
end sub

sub onSettingsLoaded()
    s = m.loadTask.settingsLoaded
    if s = invalid then return
    if s.url        <> invalid then m.nsUrl      = s.url
    if s.token      <> invalid then m.nsToken    = s.token
    if s.unitsMgdl  <> invalid then m.unitsMgdl  = s.unitsMgdl
    if s.graphHours <> invalid then m.graphHours = s.graphHours
    if s.bolusMinU   <> invalid then m.bolusMinU   = val(s.bolusMinU.ToStr())
    if s.basalRender <> invalid then m.basalRender = s.basalRender.ToStr()
    refreshDisplay()
end sub

sub refreshDisplay()
    if m.nsUrl = ""
        m.urlDisplay.text  = "https://"
        m.urlDisplay.color = "0x666688FF"
    else
        m.urlDisplay.text  = m.nsUrl
        m.urlDisplay.color = "0xFFFFFFFF"
    end if

    if m.nsToken = ""
        m.tokenDisplay.text  = "(blank)"
        m.tokenDisplay.color = "0x666688FF"
    else
        n = m.nsToken.Len()
        if n <= 4
            m.tokenDisplay.text = string(n, "*")
        else
            m.tokenDisplay.text = left(m.nsToken, 4) + string(n - 4, "*")
        end if
        m.tokenDisplay.color = "0xFFFFFFFF"
    end if

    if m.unitsMgdl
        m.chkMgBox.color   = "0x2244AAFF"
        m.chkMgMark.text   = "X"
        m.chkMmolBox.color = "0x333355FF"
        m.chkMmolMark.text = ""
    else
        m.chkMgBox.color   = "0x333355FF"
        m.chkMgMark.text   = ""
        m.chkMmolBox.color = "0x2244AAFF"
        m.chkMmolMark.text = "X"
    end if

    m.hoursDisplay.text = m.graphHours.ToStr() + "h"
    m.bolusDisplay.text = bolusLabel(m.bolusMinU)
    m.basalDisplay.text = basalLabel(m.basalRender)
end sub

function basalLabel(v as String) as String
    if v = "icicle"  then return "Icicle (top-down)"
    if v = "default" then return "Default (bottom-up)"
    return "None"
end function

function bolusLabel(v as Float) as String
    if v < 0.0  then return "Off (hidden)"
    if v < 0.05 then return "Off (hidden)"
    if v < 0.2  then return ">= 0.1 U"
    if v < 0.75 then return ">= 0.5 U"
    if v < 2.5  then return ">= 1.0 U"
    return ">= 5.0 U"
end function

sub moveFocus(row as Integer)
    m.focusRow = row
    ys = [168, 268, 348, 448, 548, 648, 738]
    t     = m.focusBar.translation
    t[1]  = ys[row]
    m.focusBar.translation = t
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    ' Dismiss disclaimer on any key
    if m.disclaimerOverlay <> invalid and m.disclaimerOverlay.visible
        m.discTimer.control = "stop"
        m.disclaimerOverlay.visible = false
        return true
    end if
    if m.top.dialog <> invalid then return false

    if key = "down"
        moveFocus((m.focusRow + 1) mod 7)
        return true
    else if key = "up"
        r = m.focusRow - 1
        if r < 0 then r = 6
        moveFocus(r)
        return true
    else if key = "left"
        if m.focusRow = 3 then cycleHours("left")   : return true
        if m.focusRow = 4 then cycleBolus("left")   : return true
        if m.focusRow = 5 then cycleBasal("left")   : return true
        return false
    else if key = "right"
        if m.focusRow = 3 then cycleHours("right")  : return true
        if m.focusRow = 4 then cycleBolus("right")  : return true
        if m.focusRow = 5 then cycleBasal("right")  : return true
        return false
    else if key = "select" or key = "OK"
        activateRow(m.focusRow)
        return true
    else if key = "back"
        return false
    end if
    return false
end function

sub cycleHours(dir as String)
    opts = [2, 3, 4, 6, 12, 24]
    idx  = 0
    for i = 0 to opts.Count() - 1
        if opts[i] = m.graphHours then idx = i
    end for
    if dir = "right"
        idx = (idx + 1) mod opts.Count()
    else
        idx = idx - 1
        if idx < 0 then idx = opts.Count() - 1
    end if
    m.graphHours = opts[idx]
    m.hoursDisplay.text = m.graphHours.ToStr() + "h"
    saveSettings()
end sub

sub cycleBolus(dir as String)
    opts = [0.0, 0.1, 0.5, 1.0, 5.0]
    idx  = 1  ' default to 0.1
    for i = 0 to opts.Count() - 1
        if opts[i] = m.bolusMinU then idx = i
    end for
    if dir = "right"
        idx = (idx + 1) mod opts.Count()
    else
        idx = idx - 1
        if idx < 0 then idx = opts.Count() - 1
    end if
    m.bolusMinU = opts[idx]
    m.bolusDisplay.text = bolusLabel(m.bolusMinU)
    saveSettings()
end sub

sub cycleBasal(dir as String)
    opts = ["none", "default", "icicle"]
    idx  = 2  ' default to icicle
    for i = 0 to opts.Count() - 1
        if opts[i] = m.basalRender then idx = i
    end for
    if dir = "right"
        idx = (idx + 1) mod opts.Count()
    else
        idx = idx - 1
        if idx < 0 then idx = opts.Count() - 1
    end if
    m.basalRender = opts[idx]
    m.basalDisplay.text = basalLabel(m.basalRender)
    saveSettings()
end sub

sub activateRow(row as Integer)
    if row = 0
        showUrlDialog()
    else if row = 1
        showTokenDialog()
    else if row = 2
        m.unitsMgdl = not m.unitsMgdl
        refreshDisplay()
        saveSettings()
    else if row = 3
        cycleHours("right")
    else if row = 4
        cycleBolus("right")
    else if row = 5
        cycleBasal("right")
    else if row = 6
        if m.nsUrl = ""
            m.setupStatus.text = "Please enter a Nightscout URL first."
        else
            saveSettings()
            m.setupStatus.text = "Saved! Launch from Home Screen, and/or make Default Screen Saver in Settings > Themes."
        end if
    end if
end sub

sub showUrlDialog()
    m.dialogPurpose = "url"
    kbd = CreateObject("roSGNode", "KeyboardDialog")
    kbd.title   = "Nightscout URL"
    kbd.message = "Include https:// -- no trailing slash needed"
    kbd.buttons = ["Save", "Cancel"]
    kbd.observeFieldScoped("buttonSelected", "onDialogButton")
    m.top.dialog = kbd
    ' Set text AFTER dialog is live so cursor lands at end
    if m.nsUrl = ""
        ' CUSTOMIZE STRING BELOW TO EASE ROKU OSK INPUTS
        m.top.dialog.text = "https://www."
    else
        m.top.dialog.text = m.nsUrl
    end if
end sub

sub showTokenDialog()
    m.dialogPurpose = "token"
    kbd = CreateObject("roSGNode", "KeyboardDialog")
    kbd.title   = "Access Token"
    kbd.message = "Leave blank if no token is required."
    kbd.buttons = ["Save", "Cancel"]
    kbd.observeFieldScoped("buttonSelected", "onDialogButton")
    m.top.dialog = kbd
    ' Set text AFTER dialog is live so cursor lands at end
    if m.nsToken = ""
        ' CUSTOMIZE STRING BELOW TO EASE ROKU OSK INPUTS
        m.top.dialog.text = ""
    else
        m.top.dialog.text = m.nsToken
    end if
end sub

sub onDialogButton()
    dlg    = m.top.dialog
    btnIdx = dlg.buttonSelected
    txt    = dlg.text
    dlg.close         = true
    m.top.dialog      = invalid
    if btnIdx <> 0 then return

    if m.dialogPurpose = "url"
        m.nsUrl = txt.trim()
        while right(m.nsUrl, 1) = "/"
            m.nsUrl = left(m.nsUrl, len(m.nsUrl) - 1)
        end while
        if left(m.nsUrl, 7) = "http://"
            m.nsUrl = "https://" + mid(m.nsUrl, 8)
        end if
    else if m.dialogPurpose = "token"
        m.nsToken = txt.trim()
    end if
    m.dialogPurpose = ""
    refreshDisplay()
    saveSettings()
end sub

sub saveSettings()
    if m.saveTask <> invalid then m.saveTask.control = "STOP" : m.saveTask = invalid
    t = CreateObject("roSGNode", "NightscoutTask")
    t.settingsToSave = {
        url:         m.nsUrl,
        token:       m.nsToken,
        unitsMgdl:   m.unitsMgdl,
        graphHours:  m.graphHours,
        bolusMinU:   m.bolusMinU,
        basalRender: m.basalRender
    }
    t.action  = "save"
    t.control = "RUN"
    m.saveTask = t
end sub
