' NightscoutSetup.brs
' Row 0=URL, Row 1=Token, Row 2=Units, Row 3=Default Display, Row 4=Bolus Threshold, Row 5=Save

sub init() ' Runs when scene is created. 
    ' First, grab node references. 
    ' Each walks the XML tree and returns a live reference to the named node, to store in the m.* variable.
    ' Keeps the BRS from having to search the tree every time. 
    ' Note that in Brightscript, m is a component-scoped associative array (ala "this"). m dies with the component. 
    m.focusBar           = m.top.findNode("focusBar")
    m.urlDisplay         = m.top.findNode("urlDisplay")
    m.tokenDisplay       = m.top.findNode("tokenDisplay")
    m.chkMgBox           = m.top.findNode("chkMgBox")
    m.chkMgMark          = m.top.findNode("chkMgMark")
    m.chkMmolBox         = m.top.findNode("chkMmolBox")
    m.chkMmolMark        = m.top.findNode("chkMmolMark")
    m.hoursDisplay       = m.top.findNode("hoursDisplay")
    m.bolusDisplay       = m.top.findNode("bolusDisplay")
    m.basalDisplay       = m.top.findNode("basalDisplay")
    m.setupStatus        = m.top.findNode("setupStatus")
    m.disclaimerOverlay  = m.top.findNode("disclaimerOverlay")

    ' Disclaimer timer - Hide overlay after 8 seconds.
    ' Timer is built-in to SceneGraph. 
    m.discTimer          = CreateObject("roSGNode", "Timer")
    m.discTimer.duration = 8
    m.discTimer.repeat   = false
    m.discTimer.observeFieldScoped("fire", "onDisclaimerTimer")
    m.discTimer.control  = "start" ' Starts the timer. 

    ' Next, we'll initialize all the state variables to safe default values. 
    ' Also prepares for refreshDisplay() immeidately after, where they will be read. 
    m.saveTask      = invalid
    m.nsUrl         = ""
    m.nsToken       = ""
    m.unitsMgdl     = true
    m.graphHours    = 4
    m.bolusMinU     = 0.1
    m.basalRender   = "icicle"
    m.focusRow      = 0
    m.dialogPurpose = ""

    refreshDisplay()
    moveFocus(0)
    
    ' Fire the settings load task in the background to read the registry. 
    ' When it's all done, onSettingsLoaded() from below gets called. 
    m.loadTask = CreateObject("roSGNode", "NightscoutTask")
    m.loadTask.observeFieldScoped("settingsLoaded", "onSettingsLoaded")
    m.loadTask.action  = "load"
    m.loadTask.control = "RUN"
    
    ' Ensure SceneGraph knows this component should receive key events. 
    m.top.setFocus(true)
end sub

sub onDisclaimerTimer()
    ' Called 8 seconds after screen opens to hide the disclaimer. 
    if m.disclaimerOverlay <> invalid ' Best practice. m.disclaimerOverlay is expected to remain valid. 
        m.disclaimerOverlay.visible = false
    end if
end sub

sub onSettingsLoaded()
    ' Called after background task finishes reading the registry. 
    ' Each field is checked for validity so if not in registry, then crash avoided. 
    s = m.loadTask.settingsLoaded
    if s = invalid then return
    if s.url         <> invalid then m.nsUrl       = s.url
    if s.token       <> invalid then m.nsToken     = s.token
    if s.unitsMgdl   <> invalid then m.unitsMgdl   = s.unitsMgdl
    if s.graphHours  <> invalid then m.graphHours  = s.graphHours
    ' BrightScript method to safely convert string to float. First ensures value from regisry is a string, then gets value. 
    if s.bolusMinU   <> invalid then m.bolusMinU   = val(s.bolusMinU.ToStr()) 
    if s.basalRender <> invalid then m.basalRender = s.basalRender.ToStr()
    refreshDisplay() ' Calls sub immediately below to update the visible UI to reflect the loaded values. 
end sub

sub refreshDisplay()
    ' Update the visible UI to reflect the loaded values. Called whenever anything changes. 
    ' Reads all m.* state variables and updates corresponding label node. 
    ' refreshDisplay takes no parameters, but always reads from m.* directly. 
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
            m.tokenDisplay.text = string(n, "*") ' Hides token for privacy, e.g. during screenshots. BrightScript string(n, "*") generates a string of * of length n. 
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
    m.bolusDisplay.text = bolusLabel(m.bolusMinU) ' Called to convert stored float-or-string to people-friendly display string, used also by cycleBolus. 
    m.basalDisplay.text = basalLabel(m.basalRender) ' Called to convert stored float-or-string to people-friendly display string, used also by cycleBasal. 
end sub

function basalLabel(v as String) as String
    ' Called to convert stored float-or-string to people-friendly display string, used by refreshDisplay and cycleBasal. 
    if v = "icicle"  then return "Icicle (top-down)"
    if v = "default" then return "Default (bottom-up)"
    return "None"
end function

function bolusLabel(v as Float) as String
    ' Called to convert stored float-or-string to people-friendly display string, used by refreshDisplay and cycleBolus. 
    if v < 0.0  then return "Off (hidden)"
    if v < 0.05 then return "Off (hidden)"
    if v < 0.2  then return ">= 0.1 U"
    if v < 0.75 then return ">= 0.5 U"
    if v < 2.5  then return ">= 1.0 U"
    return ">= 5.0 U"
end function

sub moveFocus(row as Integer)
    ' Moves blue highlight bar to the correct row. 
    ' Translation array portion direct setting not possible in BrightScript, so we read, modify, then write. 
    m.focusRow = row
    ys = [168, 268, 348, 448, 548, 648, 738] ' Array of coordinates for each row's focus bar position. 
    t     = m.focusBar.translation ' translation is a 2-element array of x and y. We'll change only the y component at index 1 (starting counting from zero). 
    t[1]  = ys[row] ' Assign new y position to array. 
    m.focusBar.translation = t ' Write back result. 
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    ' Keypress Handler. Currently disabled on Setup Disclaimer screen. 
    ' Returns true if key handled, and false if it should pass the keypress event up to the system (like for the BACK button). 
    if not press then return false ' Distinguishes button press events vs button release events. This only cares about button press events. 
    
    '' Keypress to exit disclaimer currently disabled 
    'if m.disclaimerOverlay <> invalid and m.disclaimerOverlay.visible
    '    m.discTimer.control = "stop"
    '    m.disclaimerOverlay.visible = false
    '    return true
    'end if
    
    ' If a StandardKeyboardDialog is open, let it handle all key events. 
    if m.top.dialog <> invalid then return false

    ' Handle row navigation around-the-bend... 
    if key = "down"
        moveFocus((m.focusRow + 1) mod 7) ' Handle row navigation wrapping while going downward... 
        return true
    else if key = "up"
        r = m.focusRow - 1
        if r < 0 then r = 6 ' Handle row navigation wrapping while going upward (manually, since BrightScript historically cannot always handle negative modulo (negative modulus)... 
        moveFocus(r)
        return true
    else if key = "left" ' Cycle thru array of predefined options based on current value and accounting for wrapping. Each calls saveSettings() immediately. 
        if m.focusRow = 3 then cycleHours("left")   : return true
        if m.focusRow = 4 then cycleBolus("left")   : return true
        if m.focusRow = 5 then cycleBasal("left")   : return true
        return false
    else if key = "right" ' Cycle thru array of predefined options based on current value and accounting for wrapping. Each calls saveSettings() immediately. 
        if m.focusRow = 3 then cycleHours("right")  : return true
        if m.focusRow = 4 then cycleBolus("right")  : return true
        if m.focusRow = 5 then cycleBasal("right")  : return true
        return false
    else if key = "select" or key = "OK" ' Changes focus. 
        activateRow(m.focusRow) ' Different actions per row (0 & 1 open a Keyboard Dialog, 2 toggles booleans, 3 4 and 5 advance right for convenience, and 6 validates URL and saves). 
        return true
    else if key = "back" ' Lets Roku system handle this one... 
        return false
    end if
    return false ' This was not the keypress we were looking for... 
end function

sub cycleHours(dir as String)
    ' Cycles options for default display timespan (horizontal axis). 
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
    ' Cycles options for default display timespan (horizontal axis). 
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
    ' Cycles options for default basal (temp basal and profile basal) display options (non, from bottom, from top). 
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
    ' Called by onKeyEvent. Performs different actions per row: 
    '   0 & 1 open a Keyboard Dialog, 
    '   2 toggles booleans, 
    '   3 4 and 5 advance right for convenience, and 
    '   6 validates URL and saves). 
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
    m.dialogPurpose = "url" ' Early assignment to ensure dialog knows format and/or where to send results. 
    kbd = CreateObject("roSGNode", "StandardKeyboardDialog") ' Creates a StandardKeyboardDialog (built-in to Roku) named kbd. 
    kbd.title   = "Nightscout URL"
    kbd.message = "Include https:// -- no trailing slash needed"
    kbd.buttons = ["Save", "Cancel"]
    kbd.observeFieldScoped("buttonSelected", "onDialogButton")
    m.top.dialog = kbd ' Assigned kbd to the m.top.dialog to show it. m.top.dialog is a special SceneGraph field that auto-displays when loaded with a dialog node. 
    ' Set text AFTER dialog is live so, ideally, cursor lands at end. Unsuccessful. 
    if m.nsUrl = ""
        ' CUSTOMIZE STRING BELOW TO EASE ROKU OSK INPUTS
        m.top.dialog.text = "https://www."
    else
        m.top.dialog.text = m.nsUrl
    end if
end sub

sub showTokenDialog()
    m.dialogPurpose = "token" ' Early assignment to ensure dialog knows format and/or where to send results. 
    kbd = CreateObject("roSGNode", "StandardKeyboardDialog") ' Creates a StandardKeyboardDialog (built-in to Roku) named kbd. 
    kbd.title   = "Access Token"
    kbd.message = "Leave blank if no token is required."
    kbd.buttons = ["Save", "Cancel"]
    kbd.observeFieldScoped("buttonSelected", "onDialogButton")
    m.top.dialog = kbd ' Assigned kbd to the m.top.dialog to show it. m.top.dialog is a special SceneGraph field that auto-displays when loaded with a dialog node. 
    ' Set text AFTER dialog is live so, ideally, cursor lands at end. Unsuccessful. 
    if m.nsToken = ""
        ' CUSTOMIZE STRING BELOW TO EASE ROKU OSK INPUTS
        m.top.dialog.text = ""
    else
        m.top.dialog.text = m.nsToken
    end if
end sub

sub onDialogButton()
    ' Called when user presses Save or Cancel on the keyboard dialog. 
    dlg    = m.top.dialog
    btnIdx = dlg.buttonSelected ' Index into buttons array where 0 is Save, and 1 is Cancel. 
    txt    = dlg.text
    dlg.close         = true ' Part 1 of 2 to Exit. This part causes the dismissal animation. 
    m.top.dialog      = invalid ' Part 2 of 2 to Exit. This part releases the reference. 
    if btnIdx <> 0 then return ' Canceled. Function returns early without any changes. 

    ' URL Cleaning Steps
    if m.dialogPurpose = "url" ' Removes any leading whitespace and removes any trailing whitespace. 
        m.nsUrl = txt.trim()
        while right(m.nsUrl, 1) = "/" ' Look for any trailing slashes... 
            m.nsUrl = left(m.nsUrl, len(m.nsUrl) - 1) ' And if any trailing slashes were found, remove them. 
        end while
        if left(m.nsUrl, 7) = "http://" ' Ensure secure connection. Insecure connection is prohibited. 
            m.nsUrl = "https://" + mid(m.nsUrl, 8)
        end if
    else if m.dialogPurpose = "token"
        m.nsToken = txt.trim() ' Removes any leading whitespace and removes any trailing whitespace from Access Tokens. 
    end if
    m.dialogPurpose = ""
    refreshDisplay()
    saveSettings()
end sub

sub saveSettings()
    if m.saveTask <> invalid then m.saveTask.control = "STOP" : m.saveTask = invalid ' Cleanup guard, stops any in-progress save task before creating a new one, to prevent task node accumulation, a form of memory leakage, which could easily be induced by holding the left or right arrow on a cycle row. 
    t = CreateObject("roSGNode", "NightscoutTask") ' Package settings into an assocarray and hand to a new NightscoutTask with Save action. 
    t.settingsToSave = {
        url:         m.nsUrl,
        token:       m.nsToken,
        unitsMgdl:   m.unitsMgdl,
        graphHours:  m.graphHours,
        bolusMinU:   m.bolusMinU,
        basalRender: m.basalRender
    }
    t.action  = "save"
    t.control = "RUN" ' Run on the background thread and write each field to the Roku registry. 
    m.saveTask = t ' Scene fires and forgets, and does NOT wait for conclusion or return. 
end sub
