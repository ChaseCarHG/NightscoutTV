' NightscoutScene.brs
' Setup screen: Up/Down to move focus between rows, OK to activate.
' Row 0 = URL (KeyboardDialog, pre-filled with "https://")
' Row 1 = Token (KeyboardDialog)
' Row 2 = Units (OK toggles mg/dL <-> mmol/L checkboxes)
' Row 3 = Connect button

' Focus bar Y positions: 168, 268, 348, 438
' NUM_ROWS = 4  (used as literals below)

sub init()
    ' -- Live screen nodes only --
    m.bgValue     = m.top.findNode("bgValue")
    m.trendLabel  = m.top.findNode("trendLabel")
    m.deltaLabel  = m.top.findNode("deltaLabel")
    m.timeLabelBold = m.top.findNode("timeLabelBold")
    m.timeLabelAge  = m.top.findNode("timeLabelAge")
    m.statusMsg   = m.top.findNode("statusMsg")
    m.graphGroup  = m.top.findNode("graphGroup")
    m.customTitle = m.top.findNode("customTitle")
    m.debugMsg     = m.top.findNode("debugMsg")
    m.iageLabel    = m.top.findNode("iageLabel")
    m.cageLabel    = m.top.findNode("cageLabel")
    m.sageLabel    = m.top.findNode("sageLabel")
    m.bageLabel    = m.top.findNode("bageLabel")
    m.clockLabel   = m.top.findNode("clockLabel")

    m.hourBtns = {
        "2":  [m.top.findNode("s2h"),  m.top.findNode("l2h")],
        "3":  [m.top.findNode("s3h"),  m.top.findNode("l3h")],
        "4":  [m.top.findNode("s4h"),  m.top.findNode("l4h")],
        "6":  [m.top.findNode("s6h"),  m.top.findNode("l6h")],
        "12": [m.top.findNode("s12h"), m.top.findNode("l12h")],
        "24": [m.top.findNode("s24h"), m.top.findNode("l24h")]
    }

    m.nsUrl         = ""
    m.nsToken       = ""
    m.unitsMgdl     = true
    m.graphHours    = 3
    m.bgLow         = 80
    m.bgHigh        = 180
    m.nsTitle       = ""
    m.lastDebugInfo = ""
    m.bolusMinU     = 0.5
    m.basalRender   = "icicle"
    m.enabledPlugins  = ""
    m.pillData        = {}
    m.timeFormat      = 12
    m.utcOffMin       = 0
    m.batteryPct      = -1
    m.pillThresholds  = {cageWarn:72, cageUrgent:96, sageWarn:144, sageUrgent:164, iageWarn:44, iageUrgent:48, bageWarn:240, bageUrgent:360, bageWarnP:-1, bageUrgentP:-1}
    m.treatments    = []
    m.basals        = []
    m.basalSchedule  = []
    m.combinedBasals = []
    m.lastEntries    = []
    m.lastResult     = invalid

    ' Task node refs - initialized to invalid so cleanup guards work first run
    m.fetchTask   = invalid
    m.statusTask  = invalid
    m.basalTask   = invalid
    m.treatTask   = invalid
    m.deviceTask  = invalid
    m.pillTask    = invalid
    m.profileTask = invalid
    m.saveTask    = invalid

    ' 60s refresh timer
    m.timer          = CreateObject("roSGNode", "Timer")
    m.timer.duration = 60
    m.timer.repeat   = true
    m.timer.observeFieldScoped("fire", "onTimer")
    m.timer.control  = "start"

    m.poll          = CreateObject("roSGNode", "Timer")
    m.poll.duration = 3
    m.poll.repeat   = true
    m.poll.observeFieldScoped("fire", "onPoll")

    ' -- Load settings on startup --
    m.loadTask = CreateObject("roSGNode", "NightscoutTask")
    m.loadTask.observeFieldScoped("settingsLoaded", "onSettingsLoaded")
    m.loadTask.action  = "load"
    m.loadTask.control = "RUN"

    m.top.setFocus(true)
end sub

sub onSettingsLoaded()
    s = m.loadTask.settingsLoaded
    if s = invalid then return
    m.nsUrl      = s.url
    m.nsToken    = s.token
    m.unitsMgdl  = s.unitsMgdl
    m.graphHours = s.graphHours
    if s.bolusMinU   <> invalid then m.bolusMinU   = val(s.bolusMinU.ToStr())
    if s.basalRender <> invalid then m.basalRender = s.basalRender.ToStr()
    if left(m.nsUrl, 7) = "http://"
        m.nsUrl = "https://" + mid(m.nsUrl, 8)
    end if
    refreshHourBtns()
    if m.nsUrl <> ""
        doFetch()
        doFetchTreatments()
        doFetchBasals()
        doFetchProfile()
        doFetchStatus()
        doFetchPills()
        doFetchDeviceStatus()
        startClock()
    else
        m.statusMsg.text = "Not configured. Go to: Settings > Theme > Screensaver > NightscoutTV for Roku > Settings"
    end if
    m.top.setFocus(true)
end sub

' -----------------------------------------------------------------
' KEYBOARD DIALOGS
' -----------------------------------------------------------------






' -----------------------------------------------------------------
' KEY EVENTS
' -----------------------------------------------------------------
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back"
        return false
    else if key = "select" or key = "OK" or key = "play"
        doFetch()
        return true
    else if key = "left" or key = "right"
        cycleHours(key)
        return true
    end if
    return false
end function



' -----------------------------------------------------------------
' FOCUS BAR
' -----------------------------------------------------------------


' -----------------------------------------------------------------
' DISPLAY REFRESH
' -----------------------------------------------------------------




sub refreshHourBtns()
    opts = ["2", "3", "4", "6", "12", "24"]
    for each h in opts
        pair = m.hourBtns[h]
        if h.ToInt() = m.graphHours
            pair[0].color = "0x2244CCFF"
            pair[1].color = "0xFFFFFFFF"
        else
            pair[0].color = "0x222244FF"
            pair[1].color = "0x888888FF"
        end if
    end for
end sub

' -----------------------------------------------------------------
' SCREEN TRANSITIONS
' -----------------------------------------------------------------


' showSetup removed - settings handled via RunScreenSaverSettings


sub doFetchStatus()
    if m.statusTask <> invalid then m.statusTask.control = "STOP" : m.statusTask = invalid
    t = CreateObject("roSGNode", "NightscoutTask")
    m.statusTask = t
    t.observeFieldScoped("nsCustomTitle",  "onStatus")
    t.observeFieldScoped("pillThresholds", "onPillThresholds")
    t.observeFieldScoped("timeFormat",     "onTimeFormat")
    t.nsUrl   = m.nsUrl
    t.nsToken = m.nsToken
    t.action  = "status"
    t.control = "RUN"
end sub

sub onStatus()
    ct = m.statusTask.nsCustomTitle
    if ct <> invalid and ct <> "" and ct <> "__unset__"
        m.nsTitle = ct
        m.customTitle.text = ct
    end if
    ep = m.statusTask.enabledPlugins
    if ep <> invalid then m.enabledPlugins = LCase(ep)
    renderPills()
end sub

sub doFetchBasals()
    if m.basalRender = "none"
        m.basals = []
        return
    end if
    if m.basalTask <> invalid then m.basalTask.control = "STOP" : m.basalTask = invalid
    t = CreateObject("roSGNode", "NightscoutTask")
    m.basalTask = t
    t.observeFieldScoped("basals", "onBasals")
    t.nsUrl      = m.nsUrl
    t.nsToken    = m.nsToken
    t.graphHours = m.graphHours
    t.action     = "basals"
    t.control    = "RUN"
end sub

sub onBasals()
    csv = m.basalTask.basals
    if csv = invalid then return
    m.basals = parseBasalsCSV(csv)
    rebuildBasals()
end sub

' Combine temp basals + profile gap-fills into m.combinedBasals, then redraw
sub rebuildBasals()
    if m.basalRender = "none" then return

    dtNow    = CreateObject("roDateTime")
    dtNow.Mark()
    nowSec   = dtNow.AsSeconds()
    ' Always rebuild with 24h window so maxRate scale stays constant
    ' drawGraph clips to the visible graphHours window when rendering
    startSec = nowSec - 24 * 3600

    ' Start with sorted temp basals, clamped to window
    temps = []
    if m.basals <> invalid
        for each b in m.basals
            bEnd = b.startSec + b.durationSec
            if bEnd > startSec and b.startSec < nowSec
                temps.Push({startSec: b.startSec, durationSec: b.durationSec, rateTenths: b.rateTenths, isTemp: true})
            end if
        end for
    end if

    ' Fill gaps with profile schedule
    combined = []
    cursor   = startSec
    for each t in temps
        tStart = t.startSec
        if tStart > cursor
            ' Gap before this temp basal - fill with profile
            fillStart = cursor
            fillEnd   = tStart
            while fillStart < fillEnd
                ' Profile schedule may change mid-gap at a schedule boundary
                rate = scheduledRateAt(fillStart)
                ' Find next schedule boundary within this gap
                dt2 = CreateObject("roDateTime")
                dt2.FromSeconds(fillStart)
                secOfDay  = fillStart - (fillStart mod 86400)  ' midnight
                nextBound = fillEnd  ' default: fill to end of gap
                if m.basalSchedule <> invalid
                    for each s in m.basalSchedule
                        sBoundSec = secOfDay + s.minOfDay * 60
                        if sBoundSec > fillStart and sBoundSec < nextBound
                            nextBound = sBoundSec
                        end if
                    end for
                end if
                combined.Push({startSec: fillStart, durationSec: nextBound - fillStart, rateTenths: rate, isTemp: false})
                fillStart = nextBound
            end while
        end if
        ' Add temp basal, clamped to window
        cStart = t.startSec : if cStart < startSec then cStart = startSec
        cEnd   = t.startSec + t.durationSec : if cEnd > nowSec then cEnd = nowSec
        if cEnd > cStart
            combined.Push({startSec: cStart, durationSec: cEnd - cStart, rateTenths: t.rateTenths, isTemp: true})
        end if
        cursor = t.startSec + t.durationSec
        if cursor < cStart then cursor = cStart
    end for

    ' Fill any remaining gap after last temp basal
    if cursor < nowSec
        fillStart = cursor
        fillEnd   = nowSec
        while fillStart < fillEnd
            rate = scheduledRateAt(fillStart)
            dt3 = CreateObject("roDateTime")
            dt3.FromSeconds(fillStart)
            secOfDay  = fillStart - (fillStart mod 86400)
            nextBound = fillEnd
            if m.basalSchedule <> invalid
                for each s in m.basalSchedule
                    sBoundSec = secOfDay + s.minOfDay * 60
                    if sBoundSec > fillStart and sBoundSec < nextBound
                        nextBound = sBoundSec
                    end if
                end for
            end if
            combined.Push({startSec: fillStart, durationSec: nextBound - fillStart, rateTenths: rate, isTemp: false})
            fillStart = nextBound
        end while
    end if

    ' Snap adjacent segments (already in order, no sort needed)
    n = combined.Count()
    for i = 0 to n - 2
        combined[i].durationSec = combined[i + 1].startSec - combined[i].startSec
    end for

    m.combinedBasals = combined
    if m.lastEntries <> invalid and m.lastEntries.Count() > 0
        drawGraph(m.lastEntries, m.graphHours, m.unitsMgdl)
    end if
end sub

function parseBasalsCSV(csv as String) as Object
    raw = []
    if csv = "" or csv = invalid then return raw
    for each entry in csv.split("|")
        parts = entry.split(",")
        if parts.Count() >= 3
            startSec    = parts[0].ToInt()
            durationSec = parts[1].ToInt()
            rateTenths  = parts[2].ToInt()
            if startSec > 0 and rateTenths >= 0
                raw.Push({
                    startSec:    startSec,
                    durationSec: durationSec,
                    rateTenths:  rateTenths
                })
            end if
        end if
    end for

    ' Sort ascending by startSec (insertion sort - arrays are small)
    n = raw.Count()
    for i = 1 to n - 1
        key = raw[i]
        j   = i - 1
        while j >= 0 and raw[j].startSec > key.startSec
            raw[j + 1] = raw[j]
            j = j - 1
        end while
        raw[j + 1] = key
    end for

    ' Snap each segment end to next segment start - eliminates gaps and overlaps
    for i = 0 to n - 2
        nextStart = raw[i + 1].startSec
        raw[i].durationSec = nextStart - raw[i].startSec
    end for

    return raw
end function


sub doFetchTreatments()
    if m.bolusMinU <= 0.0
        m.treatments = []
        return
    end if
    if m.treatTask <> invalid then m.treatTask.control = "STOP" : m.treatTask = invalid
    t = CreateObject("roSGNode", "NightscoutTask")
    m.treatTask = t
    t.observeFieldScoped("treatments", "onTreatments")
    t.nsUrl      = m.nsUrl
    t.nsToken    = m.nsToken
    t.graphHours = m.graphHours
    t.bolusMinU  = m.bolusMinU
    t.action     = "treatments"
    t.control    = "RUN"
end sub

sub onTreatments()
    csv = m.treatTask.treatments
    if csv = invalid then return
    m.treatments = parseTreatmentsCSV(csv)
    ' Redraw graph with boluses if we already have entries
    if m.lastEntries <> invalid and m.lastEntries.Count() > 0
        drawGraph(m.lastEntries, m.graphHours, m.unitsMgdl)
    end if
end sub

function parseTreatmentsCSV(csv as String) as Object
    result = []
    if csv = "" or csv = invalid then return result
    for each entry in csv.split("|")
        parts = entry.split(",")
        if parts.Count() >= 3
            dateSec       = parts[0].ToInt()
            insulinTenths = parts[1].ToInt()
            carbs         = parts[2].ToInt()
            if dateSec > 0 and insulinTenths > 0
                result.Push({
                    dateSec: dateSec,
                    insulin: insulinTenths,  ' stored as tenths (e.g. 43 = 4.3U)
                    carbs:   carbs
                })
            end if
        end if
    end for
    return result
end function

sub doFetchDeviceStatus()
    if not pluginEnabled("bage") then return
    if m.deviceTask <> invalid then m.deviceTask.control = "STOP" : m.deviceTask = invalid
    t = CreateObject("roSGNode", "NightscoutTask")
    m.deviceTask = t
    t.observeFieldScoped("batteryPct", "onBatteryPct")
    t.nsUrl   = m.nsUrl
    t.nsToken = m.nsToken
    t.action  = "devicestatus"
    t.control = "RUN"
end sub

sub onBatteryPct()
    m.batteryPct = m.deviceTask.batteryPct
    renderPills()
end sub

sub onTimeFormat()
    tf = m.statusTask.timeFormat
    if tf <> invalid then m.timeFormat = tf
    updateClock()
end sub

sub onPillThresholds()
    csv = m.statusTask.pillThresholds
    if csv = invalid or csv = "" then return
    parts = csv.split(",")
    if parts.Count() < 10 then return
    m.pillThresholds = {
        cageWarn:    parts[0].ToInt(),
        cageUrgent:  parts[1].ToInt(),
        sageWarn:    parts[2].ToInt(),
        sageUrgent:  parts[3].ToInt(),
        iageWarn:    parts[4].ToInt(),
        iageUrgent:  parts[5].ToInt(),
        bageWarn:    parts[6].ToInt(),
        bageUrgent:  parts[7].ToInt(),
        bageWarnP:   parts[8].ToInt(),
        bageUrgentP: parts[9].ToInt()
    }
    renderPills()
end sub

sub doFetchPills()
    if m.pillTask <> invalid then m.pillTask.control = "STOP" : m.pillTask = invalid
    t = CreateObject("roSGNode", "NightscoutTask")
    m.pillTask = t
    t.observeFieldScoped("pills", "onPills")
    t.nsUrl   = m.nsUrl
    t.nsToken = m.nsToken
    t.action  = "pills"
    t.control = "RUN"
end sub

sub onPills()
    csv = m.pillTask.pills
    if csv = invalid then return

    ' Parse: name,epochSec|name,epochSec...
    pills = {}
    for each entry in csv.split("|")
        parts = entry.split(",")
        if parts.Count() >= 2
            pills[parts[0]] = parts[1].ToInt()
        end if
    end for

    ' SAGE = more recent of Sensor Change or Sensor Start
    sageSec = 0
    if pills["sage"] <> invalid      then sageSec = pills["sage"]
    if pills["sagestart"] <> invalid
        if pills["sagestart"] > sageSec then sageSec = pills["sagestart"]
    end if
    pills["sage"] = sageSec

    m.pillData = pills
    renderPills()
end sub

' Format age in hours or days+hours
function fmtAge(epochSec as Integer, nowSec as Integer) as String
    if epochSec <= 0 then return "?"
    ageSec  = nowSec - epochSec
    if ageSec < 0 then ageSec = 0
    hrs  = ageSec \ 3600
    days = hrs \ 24
    remH = hrs mod 24
    if days > 0
        return days.ToStr() + "d " + remH.ToStr() + "h"
    end if
    return hrs.ToStr() + "h"
end function

' Check if a plugin name appears in the enabled/show string
function pluginEnabled(name as String) as Boolean
    ep = m.enabledPlugins
    if ep = "" or ep = invalid then return true  ' fail-open: show if status not yet loaded
    return instr(1, ep, name) > 0
end function

sub renderPills()
    dtNow = CreateObject("roDateTime")
    dtNow.Mark()
    nowSec = dtNow.AsSeconds()

    pills = m.pillData
    thr   = m.pillThresholds

    if pluginEnabled("iage") and pills["iage"] <> invalid and pills["iage"] > 0
        m.iageLabel.text  = "IAGE " + fmtAge(pills["iage"], nowSec)
        m.iageLabel.color = pillColor(pills["iage"], nowSec, thr.iageWarn, thr.iageUrgent)
    else
        m.iageLabel.text  = ""
    end if

    if pluginEnabled("cage") and pills["cage"] <> invalid and pills["cage"] > 0
        m.cageLabel.text  = "CAGE " + fmtAge(pills["cage"], nowSec)
        m.cageLabel.color = pillColor(pills["cage"], nowSec, thr.cageWarn, thr.cageUrgent)
    else
        m.cageLabel.text  = ""
    end if

    if pluginEnabled("sage") and pills["sage"] <> invalid and pills["sage"] > 0
        m.sageLabel.text  = "SAGE " + fmtAge(pills["sage"], nowSec)
        m.sageLabel.color = pillColor(pills["sage"], nowSec, thr.sageWarn, thr.sageUrgent)
    else
        m.sageLabel.text  = ""
    end if

    if pluginEnabled("bage") and pills["bage"] <> invalid and pills["bage"] > 0
        pct = m.batteryPct
        if thr.bageWarnP > 0 and pct >= 0
            m.bageLabel.text = "BAGE " + pct.ToStr() + "%"
            if pct <= thr.bageUrgentP
                m.bageLabel.color = "0xFF4444FF"
            else if pct <= thr.bageWarnP
                m.bageLabel.color = "0xFFAA00FF"
            else
                m.bageLabel.color = "0x88FF88FF"
            end if
        else if thr.bageWarn > 0
            m.bageLabel.text  = "BAGE " + fmtAge(pills["bage"], nowSec)
            m.bageLabel.color = pillColor(pills["bage"], nowSec, thr.bageWarn, thr.bageUrgent)
        else
            m.bageLabel.text  = "BAGE " + fmtAge(pills["bage"], nowSec)
            m.bageLabel.color = "0x88FF88FF"
        end if
    else
        m.bageLabel.text  = ""
    end if
end sub


' -----------------------------------------------------------------
' CLOCK
' -----------------------------------------------------------------
sub startClock()
    updateClock()
    ' Fire at the next minute boundary, then every 60s
    dt = CreateObject("roDateTime")
    dt.Mark()
    secsLeft = 60 - dt.GetSeconds()
    if secsLeft <= 0 then secsLeft = 60
    m.clockTimer          = CreateObject("roSGNode", "Timer")
    m.clockTimer.duration = secsLeft
    m.clockTimer.repeat   = false
    m.clockTimer.observeFieldScoped("fire", "onClockTick")
    m.clockTimer.control  = "start"
end sub

sub onClockTick()
    updateClock()
    updateAgeText(m.lastResult)
    ' Now switch to a steady 60s repeating timer
    m.clockTimer.duration = 60
    m.clockTimer.repeat   = true
    m.clockTimer.control  = "start"
end sub

sub updateClock()
    dt = CreateObject("roDateTime")
    dt.Mark()
    ' roDateTime.Mark() returns UTC. Apply the Nightscout server's utcOffset
    ' (from the most recent entry) to get local time.
    localSec = dt.AsSeconds() + m.utcOffMin * 60
    dt.FromSeconds(localSec)
    h  = dt.GetHours()
    mn = dt.GetMinutes()
    if m.timeFormat = 24
        hStr = h.ToStr()
        if h < 10 then hStr = "0" + hStr
        m.clockLabel.text = hStr + ":" + zp2(mn)
    else
        ampm = "AM"
        if h >= 12 then ampm = "PM"
        h12 = h mod 12
        if h12 = 0 then h12 = 12
        m.clockLabel.text = h12.ToStr() + ":" + zp2(mn) + " " + ampm
    end if
end sub

function zp2(n as Integer) as String
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function


' Color: green < warnHrs, yellow < urgentHrs, red >= urgentHrs
function pillColor(epochSec as Integer, nowSec as Integer, warnHrs as Integer, urgentHrs as Integer) as String
    hrs = (nowSec - epochSec) \ 3600
    if hrs >= urgentHrs then return "0xFF4444FF"
    if hrs >= warnHrs   then return "0xFFAA00FF"
    return "0x88FF88FF"
end function

sub doFetchProfile()
    if m.profileTask <> invalid then m.profileTask.control = "STOP" : m.profileTask = invalid
    t = CreateObject("roSGNode", "NightscoutTask")
    m.profileTask = t
    t.observeFieldScoped("profile",       "onProfile")
    t.observeFieldScoped("basalSchedule", "onBasalSchedule")
    t.nsUrl   = m.nsUrl
    t.nsToken = m.nsToken
    t.action  = "profile"
    t.control = "RUN"
end sub

sub onProfile()
    p = m.profileTask.profile
    if p = invalid then return
    if p.bgLow  > 0 then m.bgLow  = p.bgLow
    if p.bgHigh > 0 then m.bgHigh = p.bgHigh
end sub

sub onBasalSchedule()
    csv = m.profileTask.basalSchedule
    if csv = invalid then return
    m.basalSchedule = parseBasalScheduleCSV(csv)
    ' Rebuild basal display if we have temp basal data
    rebuildBasals()
end sub

function parseBasalScheduleCSV(csv as String) as Object
    result = []
    if csv = "" then return result
    for each entry in csv.split("|")
        parts = entry.split(",")
        if parts.Count() >= 2
            result.Push({
                minOfDay:   parts[0].ToInt(),
                rateTenths: parts[1].ToInt()
            })
        end if
    end for
    ' Sort by minOfDay ascending
    n = result.Count()
    for i = 1 to n - 1
        key = result[i]
        j   = i - 1
        while j >= 0 and result[j].minOfDay > key.minOfDay
            result[j + 1] = result[j]
            j = j - 1
        end while
        result[j + 1] = key
    end for
    return result
end function

' Look up scheduled basal rate (rateTenths) for a given epoch second
function scheduledRateAt(epochSec as Integer) as Integer
    if m.basalSchedule = invalid or m.basalSchedule.Count() = 0 then return 0
    dt = CreateObject("roDateTime")
    dt.FromSeconds(epochSec)
    minOfDay = dt.GetHours() * 60 + dt.GetMinutes()
    ' Walk schedule backwards to find last entry <= minOfDay
    rate = m.basalSchedule[0].rateTenths  ' default to first entry
    for each s in m.basalSchedule
        if s.minOfDay <= minOfDay
            rate = s.rateTenths
        end if
    end for
    return rate
end function

' -----------------------------------------------------------------
' FETCH
' -----------------------------------------------------------------
sub doFetch()
    m.statusMsg.text    = "Fetching..."
    m.debugMsg.text     = "URL: " + m.nsUrl
    m.lastDebugInfo     = ""
    if m.fetchTask <> invalid then m.fetchTask.control = "STOP" : m.fetchTask = invalid
    t = CreateObject("roSGNode", "NightscoutTask")
    t.observeFieldScoped("result", "onResult")
    t.action     = "fetch"
    t.nsUrl      = m.nsUrl
    t.nsToken    = m.nsToken
    t.unitsMgdl  = m.unitsMgdl
    t.graphHours = m.graphHours
    t.control    = "RUN"
    m.fetchTask  = t
end sub

sub onTimer()
    doFetch()
end sub

sub updateAgeText(r as Object)
    if r = invalid then return
    dt = CreateObject("roDateTime")
    dt.Mark()
    ' Use local time (same offset as clock) so "N minutes ago" matches clock display
    localNowSec  = dt.AsSeconds() + m.utcOffMin * 60
    localAgeSec  = r.ageSec      + m.utcOffMin * 60
    ' Truncate both to minute boundaries, then diff - matches what clock shows
    ageMins = (localNowSec \ 60) - (localAgeSec \ 60)
    if ageMins < 1
        agoStr = "(just now)"
    else if ageMins = 1
        agoStr = "(1 minute ago)"
    else
        agoStr = "(" + ageMins.ToStr() + " minutes ago)"
    end if
    m.timeLabelBold.text = "Last: " + r.timeStr
    m.timeLabelAge.text  = agoStr
end sub

' Poll fallback - kept as no-op; real result delivery via observeFieldScoped
sub onPoll()
end sub

sub onResult()
    if m.fetchTask = invalid then return
    r = m.fetchTask.result
    if r = invalid then return
    processResult(r)
end sub

sub processResult(r as Object)
    if r = invalid
        m.statusMsg.text = "Error: no response"
        m.debugMsg.text  = "result=invalid"
        return
    end if
    if r.error <> ""
        m.statusMsg.text = "Err: " + r.error
        m.debugMsg.text  = ""
        return
    end if
    m.statusMsg.text = ""

    ' BG value and color
    m.bgValue.text     = r.dispBg
    liveColor          = gBgColor(r.rawBg, m.bgLow, m.bgHigh)
    m.bgValue.color    = liveColor
    m.trendLabel.text  = r.trendStr
    m.trendLabel.color = liveColor

    ' Delta with units
    if m.unitsMgdl
        m.deltaLabel.text = r.dispDelta + " mg/dL"
    else
        deltaInt = r.dispDelta.ToInt()
        absD     = deltaInt : if absD < 0 then absD = -deltaInt
        tenths   = int(absD * 0.0555 * 10.0 + 0.5)
        mmolStr  = (tenths \ 10).ToStr() + "." + (tenths mod 10).ToStr()
        if deltaInt >= 0
            m.deltaLabel.text = "+" + mmolStr + " mmol/L"
        else
            m.deltaLabel.text = "-" + mmolStr + " mmol/L"
        end if
    end if

    ' Timestamp with age - updated on refresh and on each clock tick
    m.lastResult = r
    updateAgeText(r)

    ' Status line, like this: "OK.  102 mg/dL.  Values Loaded: 42."
    unitStr = "mg/dL"
    bgDisp  = r.dispBg
    if not m.unitsMgdl
        unitStr  = "mmol/L"
        tenths2  = int(r.rawBg * 0.0555 * 10.0 + 0.5)
        bgDisp   = (tenths2 \ 10).ToStr() + "." + (tenths2 mod 10).ToStr()
    end if
    parts = r.entriesCSV.split("|")
    m.debugMsg.text = "OK.  " + bgDisp + " " + unitStr + ".  Values Loaded: " + parts.Count().ToStr() + "."

    if r.utcOffMin <> invalid then m.utcOffMin = r.utcOffMin
    entries = parseEntriesCSV(r.entriesCSV)
    m.lastEntries = entries
    rebuildBasals()
    drawGraph(entries, m.graphHours, m.unitsMgdl)
end sub

' -----------------------------------------------------------------
' HOURS
' -----------------------------------------------------------------
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
    refreshHourBtns()
    saveSettings()
    doFetch()
    doFetchTreatments()
    doFetchBasals()
end sub

' -----------------------------------------------------------------
' SAVE SETTINGS (via Task)
' -----------------------------------------------------------------
sub saveSettings()
    if m.saveTask <> invalid then m.saveTask.control = "STOP" : m.saveTask = invalid
    t = CreateObject("roSGNode", "NightscoutTask")
    t.settingsToSave = {
        url:        m.nsUrl,
        token:      m.nsToken,
        unitsMgdl:  m.unitsMgdl,
        graphHours: m.graphHours
    }
    t.action  = "save"
    t.control = "RUN"
    m.saveTask = t
end sub


' Parse 'sec,sgv|sec,sgv|...' CSV string back into array of {dateSec, sgv}
function parseEntriesCSV(csv as String) as Object
    entries = []
    if csv = "" then return entries
    rows = csv.split("|")
    for each row in rows
        parts = row.split(",")
        if parts.Count() = 2
            sec = parts[0].ToInt()
            sgv = parts[1].ToInt()
            if sec > 0 and sgv > 0
                entries.Push({dateSec: sec, sgv: sgv})
            end if
        end if
    end for
    return entries
end function

' -----------------------------------------------------------------
' DRAW GRAPH  (logarithmic Y scale, Nightscout-style)
' Entries: array of {dateSec, sgv}
' Thresholds: m.bgLow, m.bgHigh (mg/dL, from profile or defaults)
' -----------------------------------------------------------------
sub drawGraph(entries as Object, hours as Integer, mgdl as Boolean)
    grp = m.graphGroup
    if grp = invalid then return

    while grp.getChildCount() > 0
        grp.removeChildIndex(0)
    end while

    if entries = invalid or entries.Count() = 0 then return

    ' Graph canvas size
    GRPW = 1800
    GRPH = 560
    PAL  = 66
    PAR  = 10
    PAT  = 10
    PAB  = 28
    GW   = GRPW - PAL - PAR
    GH   = GRPH - PAT - PAB

    ' Time range
    dt = CreateObject("roDateTime")
    dt.Mark()
    nowSec   = dt.AsSeconds()
    startSec = nowSec - hours * 3600
    spanSec  = nowSec - startSec

    ' Threshold values (mg/dL) - use profile values if fetched
    bgLow  = m.bgLow
    bgHigh = m.bgHigh
    if bgLow  = 0 or bgLow  = invalid then bgLow  = 80
    if bgHigh = 0 or bgHigh = invalid then bgHigh = 180

    ' Log scale: map mg/dL to Y using natural log
    ' Range: 40..400 mg/dL
    YMIN_MG = 40
    YMAX_MG = 400
    logMin  = logY(YMIN_MG)
    logMax  = logY(YMAX_MG)
    logSpan = logMax - logMin

    ' Background
    mkRect(grp, 0, 0, GRPW, GRPH, "0x08080EFF")

    ' --- Colored bands ---
    ' Low band (below bgLow): red tint
    yLow  = logPx(bgLow,  logMin, logSpan, PAT, GH)
    yHigh = logPx(bgHigh, logMin, logSpan, PAT, GH)
    yBot  = PAT + GH
    mkRect(grp, PAL, yLow,  GW, yBot  - yLow,  "0xFF000028")
    ' High band (above bgHigh): amber tint
    mkRect(grp, PAL, PAT, GW, yHigh - PAT,     "0xFF880018")

    ' --- Basal bars (drawn first, below everything else) ---
    basalSrc = m.combinedBasals
    if basalSrc = invalid or basalSrc.Count() = 0 then basalSrc = m.basals
    if basalSrc <> invalid and m.basalRender <> "none" and basalSrc.Count() > 0
        ' Compute maxRate from ALL fetched data (full combinedBasals),
        ' not just the visible window -- prevents rescaling on timespan change
        maxRate = 0
        allSrc = m.combinedBasals
        if allSrc = invalid or allSrc.Count() = 0 then allSrc = m.basals
        if allSrc <> invalid
            for each b in allSrc
                if b.rateTenths > maxRate then maxRate = b.rateTenths
            end for
        end if
        if maxRate < 1 then maxRate = 10
        basalH = int(GH * 0.25)
        for each b in basalSrc
            bStart = b.startSec
            bEnd   = bStart + b.durationSec
            if bStart < startSec then bStart = startSec
            if bEnd   > nowSec   then bEnd   = nowSec
            if bStart < bEnd and b.rateTenths > 0
                bx1 = PAL + int((bStart - startSec) / spanSec * GW)
                bx2 = PAL + int((bEnd   - startSec) / spanSec * GW)
                bw  = bx2 - bx1
                if bw < 1 then bw = 1
                bh  = int(basalH * b.rateTenths / maxRate)
                if bh < 1 then bh = 1
                ' isTemp=true -> Temp Basal #0E2D41, isTemp=false -> Profile #0F1E29
                col = "0x0F1E29FF"  ' default: profile
                if b.isTemp = true then col = "0x0E2D41FF"

                if m.basalRender = "icicle"
                    mkRect(grp, bx1, PAT, bw, bh, col)
                else
                    mkRect(grp, bx1, PAT + GH - bh, bw, bh, col)
                end if
            end if
        end for
    end if

    ' --- Grid lines (log scale ticks: 40,55,80,120,180,260,400) ---
    ticks = [40, 55, 80, 120, 180, 260, 400]
    for each mg in ticks
        yy  = logPx(mg, logMin, logSpan, PAT, GH)
        col = "0x334466AA"
        if mg = bgLow  then col = "0xFF660099"
        if mg = bgHigh then col = "0xFFAA0099"
        mkRect(grp, PAL, yy, GW, 1, col)
    end for

    ' --- Y-axis labels ---
    for each mg in ticks
        yy  = logPx(mg, logMin, logSpan, PAT, GH)
        lbl = fmtMg(mg, mgdl)
        mkLabel(grp, 2, yy - 10, lbl, "0x888888FF")
    end for

    ' --- X-axis labels (5 positions: 0%, 25%, 50%, 75%, Now) ---
    mkLabel(grp, PAL,                  PAT + GH + 4, gFmtHHMM(startSec),                   "0x555577FF")
    mkLabel(grp, PAL + GW/4 - 20,     PAT + GH + 4, gFmtHHMM(startSec + spanSec / 4),     "0x555577FF")
    mkLabel(grp, PAL + GW/2 - 20,     PAT + GH + 4, gFmtHHMM(startSec + spanSec / 2),     "0x555577FF")
    mkLabel(grp, PAL + GW*3/4 - 20,   PAT + GH + 4, gFmtHHMM(startSec + spanSec * 3 / 4), "0x555577FF")
    mkLabel(grp, PAL + GW - 52,       PAT + GH + 4, "Now",                                 "0x8888AAFF")

    ' --- Border ---
    mkRect(grp, PAL, PAT,      GW, 1,  "0x334466FF")
    mkRect(grp, PAL, PAT + GH, GW, 1,  "0x334466FF")
    mkRect(grp, PAL, PAT,      1,  GH, "0x334466FF")

    ' --- Units label below X-axis timestamps ---
    unitLbl = "mg/dL"
    if not mgdl then unitLbl = "mmol/L"
    mkLabel(grp, 2, PAT + GH + 26, unitLbl, "0x888888FF")

    ' --- Glucose Dots ---
    DOT = 8
    i   = entries.Count() - 1
    while i >= 0
        e  = entries[i]
        es = e.dateSec
        if es >= startSec - 30 and es <= nowSec + 60
            xp = PAL + int((es - startSec) / spanSec * GW)
            yp = logPx(e.sgv, logMin, logSpan, PAT, GH)
            mkRect(grp, xp - DOT/2, yp - DOT/2, DOT, DOT, gBgColor(e.sgv, bgLow, bgHigh))
        end if
        i = i - 1
    end while

    ' --- Bolus markers ---
    if m.treatments <> invalid
        for each bolus in m.treatments
            bs = bolus.dateSec
            if bs >= startSec and bs <= nowSec
                bx = PAL + int((bs - startSec) / spanSec * GW)
                ' Find nearest glucose y position
                bSgv = nearestSgv(entries, bs)
                if bSgv > 0
                    by = logPx(bSgv, logMin, logSpan, PAT, GH)
                else
                    by = PAT + GH / 2
                end if
                drawBolus(grp, bx, by, bolus.insulin, bolus.carbs)
            end if
        end for
    end if
end sub

' Draw a bolus marker: white top half, blue bottom half, text above/below
sub drawBolus(grp as Object, cx as Integer, cy as Integer, insulinTenths as Integer, carbs as Integer)
    R = 10  ' radius (half-width of the pill)
    ' White top half
    mkRect(grp, cx - R, cy - R*2, R*2, R, "0xFFFFFFFF")
    ' Blue bottom half
    mkRect(grp, cx - R, cy - R,   R*2, R, "0x4488FFFF")
    ' Thin border outline
    mkRect(grp, cx - R,     cy - R*2, R*2, 1,    "0x000000AA")  ' top
    mkRect(grp, cx - R,     cy,       R*2, 1,    "0x000000AA")  ' bottom
    mkRect(grp, cx - R,     cy - R*2, 1,   R*2,  "0x000000AA")  ' left
    mkRect(grp, cx + R - 1, cy - R*2, 1,   R*2,  "0x000000AA")  ' right
    ' Insulin text below
    iWhole  = insulinTenths \ 10
    iFrac   = insulinTenths mod 10
    iStr    = iWhole.ToStr() + "." + iFrac.ToStr() + "U"
    mkLabel(grp, cx - 16, cy + 2, iStr, "0x88CCFFFF")
    ' Carbs text above (if present)
    if carbs > 0
        mkLabel(grp, cx - 12, cy - R*2 - 18, carbs.ToStr() + "g", "0xFFDD88FF")
    end if
end sub

' Find the SGV value of the entry closest in time to targetSec
function nearestSgv(entries as Object, targetSec as Integer) as Integer
    best    = 0
    bestDiff = 99999
    for each e in entries
        diff = e.dateSec - targetSec
        if diff < 0 then diff = -diff
        if diff < bestDiff
            bestDiff = diff
            best     = e.sgv
        end if
    end for
    return best
end function

' Natural log approximation (BrightScript has no math library)
' ln(x) via series or table -- use lookup table for our fixed values
function logY(mg as Integer) as Float
    ' Use ln via identity: ln(x) = ln(a) + (x-a)/a - (x-a)^2/(2a^2) ...
    ' Simpler: use Log() -- BrightScript DOES have Log() as natural log
    if mg < 1 then mg = 1
    return Log(mg)
end function

function logPx(mg as Integer, logMin as Float, logSpan as Float, padT as Integer, gH as Integer) as Integer
    c = mg
    if c < 1 then c = 1
    frac = (Log(c) - logMin) / logSpan
    ' Invert: high mg = top of chart = small Y pixel
    return padT + int((1.0 - frac) * gH)
end function


function gYPx(mg as Integer, yMin as Integer, yMax as Integer, padT as Integer, gH as Integer) as Integer
    c = mg
    if c < yMin then c = yMin
    if c > yMax then c = yMax
    return padT + int((yMax - c) / (1.0 * (yMax - yMin)) * gH)
end function

function gBgColor(mg as Integer, bgLow as Integer, bgHigh as Integer) as String
    urgLow  = bgLow - 20 : if urgLow < 40 then urgLow = 40
    urgHigh = bgHigh + 60
    if mg <= urgLow  then return "0xFF2222FF"
    if mg < bgLow    then return "0xFF6600FF"
    if mg >= urgHigh then return "0xFF2222FF"
    if mg > bgHigh   then return "0xFFAA00FF"
    return "0x44FF88FF"
end function

function fmtMg(mg as Integer, mgdl as Boolean) as String
    if mgdl then return mg.ToStr()
    tenths = int(mg * 0.0555 * 10.0 + 0.5)
    return (tenths \ 10).ToStr() + "." + (tenths mod 10).ToStr()
end function

function gFmtHHMM(sec as Integer) as String
    dt = CreateObject("roDateTime")
    dt.FromSeconds(sec + m.utcOffMin * 60)
    h  = dt.GetHours()
    mn = dt.GetMinutes()
    hs  = h.ToStr()  : if h  < 10 then hs  = "0" + hs
    mns = mn.ToStr() : if mn < 10 then mns = "0" + mns
    return hs + ":" + mns
end function

sub mkRect(grp as Object, x as Integer, y as Integer, w as Integer, h as Integer, col as String)
    r = grp.createChild("Rectangle")
    r.translation = [x, y]
    r.width  = w
    r.height = h
    r.color  = col
end sub

sub mkLabel(grp as Object, x as Integer, y as Integer, txt as String, col as String)
    lbl = grp.createChild("Label")
    lbl.translation = [x, y]
    lbl.text  = txt
    lbl.color = col
    lbl.font  = "font:SmallestSystemFont"
end sub
