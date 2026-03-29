' NightscoutTask.brs - For troubleshooting task threads
' This background thread is called upon by NightscoutSetup, and extensively by NightscoutLive
' The render thread cannot support HTTP or similar tasks without freezing the GUI. 
' So, this background thread handles all network calls, registry reads and writes, etc. 
' This task is STATELESS. That is, every call creates a fresh task node, does its work, writes to output field, and exits. 
' That is, NO STATE PERSISTS BETWEEN CALLS. All state lives in the scene (NightscoutLive.brs) in m.* variables. 

sub init()
    m.top.functionName = "taskRun" ' m.top is the node itself. This tells Roku which function to call when the task's control field is set to RUN.
end sub

sub taskRun() ' Called upon by the init function above. 
    ' Dispatches events. When the scene does t.action = "fetch" : t.control = "RUN", Roku calls taskRun() on the background thread.
    ' A big switch statement to choose the right subroutine based on m.top.action (the node's queued action).
    if m.top.action = "fetch" ' Get CGM Entries. 
        doFetch()
    else if m.top.action = "treatments" ' Get bolus treatments. 
        doFetchTreatments()
    else if m.top.action = "basals" ' Get temp basal treatments. 
        doFetchBasals()
    else if m.top.action = "profile" ' Get profile basal data, and glucose threshold values for graph bands and coloring datapoints. 
        doFetchProfile()
    else if m.top.action = "status" ' Get custom title, enabled plugins, and pill thresholds for IAGE CAGE SAGE and-or BAGE. 
        doFetchStatus()
    else if m.top.action = "pills" ' Gets IAGE CAGE SAGE and BAGE (pill) ages or percent-ages (percentages). 
        doFetchPills()
    else if m.top.action = "devicestatus" ' Get pump battery percentage. 
        doFetchDeviceStatus()
    else if m.top.action = "save" ' Write settings to the registry. 
        doSaveSettings()
    else
        doLoadSettings() ' Read settings from the registry. 
    end if

end sub

sub doLoadSettings() ' Loads settings from Roku's persistent registry storage system, scoped to the Roku Channel ID. 
    ' Persistance here means it survives app restarts and Roku reboots. 
    ' Reads all saved settings and packages them into a single assocarray (settingsLoaded) that is later read in onSettingsLoaded(). 
    ' In absence of a stored value, will apply default values.
    url   = regRead("url")
    token = regRead("token")
    units = regRead("units")
    hours = regReadInt("graphHours", 4)

    if left(url, 7) = "http://"
        url = "https://" + mid(url, 8)
        regWrite("url", url)
    end if

    mgdl = true
    if units = "mmol" then mgdl = false

    bolusMin    = regRead("bolusMinU")   : if bolusMin    = "" then bolusMin    = "0.1"
    basalRender = regRead("basalRender") : if basalRender = "" then basalRender = "icicle"
    utcOff      = regReadInt("utcOffMin", 0)
    m.top.settingsLoaded = {
        url:         url,
        token:       token,
        unitsMgdl:   mgdl,
        graphHours:  hours,
        bolusMinU:   bolusMin,
        basalRender: basalRender,
        utcOffMin:   utcOff
    }
end sub

sub doSaveSettings() ' Writes all settings to the persistent Roku registry, which survives app restarts and Roku reboots. 
    ' Entries are scoped to the Channel ID. 
    s = m.top.settingsToSave
    if s = invalid then return
    regWrite("url",   s.url)
    regWrite("token", s.token)
    if s.unitsMgdl
        regWrite("units", "mgdl")
    else
        regWrite("units", "mmol")
    end if
    regWriteInt("graphHours", s.graphHours)
    if s.bolusMinU    <> invalid then regWrite("bolusMinU",    s.bolusMinU.ToStr())
    if s.basalRender  <> invalid then regWrite("basalRender",  s.basalRender.ToStr())
    if s.utcOffMin    <> invalid then regWriteInt("utcOffMin", s.utcOffMin)
end sub

sub doFetch() ' Fetches CGM data from Nightscout Server's /api/v1/entries.json
    ' Count calc is graphHours * 12 + 6, as Nightscout stores a value every 5 minutes, and so there are 12 per hour. 
    ' The 6 (arbitrary) extra serves as a buffer, for off the left edge of the graph, in case of data gaps, except the api returns in reverse-chronological order anyway. 
    result = {
        rawBg:      0,
        dispBg:     "---",
        ageSec:     0,
        utcOffMin:  0,
        bgColorHex: "0xFFFFFFFF",
        trendStr:   "?",
        dispDelta:  "",
        timeStr:    "",
        entriesCSV: "",
        debugInfo:  "",
        error:      ""
    }

    baseUrl = m.top.nsUrl.trim()
    token   = m.top.nsToken.trim()

    if baseUrl = ""
        result.error = "No URL"
        m.top.result = result
        return
    end if

    while right(baseUrl, 1) = "/"
        baseUrl = left(baseUrl, len(baseUrl) - 1)
    end while
    if left(baseUrl, 7) = "http://"
        baseUrl = "https://" + mid(baseUrl, 8)
    end if

    count  = m.top.graphHours * 12 + 6
    apiUrl = baseUrl + "/api/v1/entries.json?count=" + count.ToStr()
    if token <> "" then apiUrl = apiUrl + "&token=" + token

    ' First example of our typical HTTP pattern...
    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.SetUrl(apiUrl)
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.AddHeader("Accept", "application/json")
    http.InitClientCertificates()
    http.SetMessagePort(port)

    if not http.AsyncGetToString() ' Fire off our HTTP request, non-blocking. 
        result.error = "AsyncGetToString failed" ' Block THIS thread only, up to 15 seconds, to await response. Avoids blocking the render thread. 
        m.top.result = result
        return
    end if

    msg = wait(15000, port)

    if msg = invalid
        http.AsyncCancel()
        result.error = "Timeout"
        m.top.result = result
        return
    end if

    if type(msg) <> "roUrlEvent"
        result.error = "Bad msg type: " + type(msg)
        m.top.result = result
        return
    end if

    code = msg.GetResponseCode()
    raw  = msg.GetString()

    if code <> 200
        result.error = "HTTP " + code.ToStr()
        m.top.result = result
        return
    end if

    data = ParseJson(raw)
    if data = invalid or type(data) <> "roArray" or data.Count() = 0
        result.error = "Bad JSON"
        m.top.result = result
        return
    end if

    entryStr = ""
    firstSgv = 0
    secondSgv = 0
    firstSec  = 0
    firstDir  = "Flat"
    n = 0

    ' Entry loop. Walks JSON array, extracts SGV (Sensor Glucose Value, in mg/dL) and date (epoch milliseconds, converted within from ms to s). 
    for each e in data
        sgvVal = e["sgv"]
        if sgvVal <> invalid ' Error check
            sgv = int(sgvVal) ' Ensure integer
            if sgv > 0
                dateVal = e["date"] ' Returns epoch milliseconds
                dateSec = 0
                if dateVal <> invalid
                    ds = dateVal.ToStr()
                    dl = len(ds)
                    ' The date conversion strips the last 3 digits, to convert from ms to s. Because metric. 
                    if dl > 3 then dateSec = left(ds, dl - 3).ToInt()
                end if
                if dateSec > 0
                    if n = 0
                        firstSgv = sgv
                        firstSec = dateSec
                        dirVal = e["direction"]
                        if dirVal <> invalid then firstDir = dirVal.ToStr()
                    else if n = 1
                        secondSgv = sgv
                    end if
                    ' Build entryStr as a pipe-delimited list, to prep for passing data to the scene
                    if entryStr <> "" then entryStr = entryStr + "|"
                    entryStr = entryStr + dateSec.ToStr() + "," + sgv.ToStr()
                    n = n + 1
                end if
            end if
        end if
    end for


    if n = 0
        result.error = "No valid entries"
        m.top.result = result
        return
    end if

    delta = 0
    if secondSgv > 0 then delta = firstSgv - secondSgv

    ' Read utcOffset from first entry (minutes, e.g. -240 for UTC-4). 
    ' Nightscout entries carry the server's UTC offset in minutes, and imported for clock and axis-label TZ correction. 
    utcOffMin = 0
    offsetVal = data[0]["utcOffset"]
    if offsetVal <> invalid then utcOffMin = int(offsetVal)

    result.rawBg      = firstSgv
    result.dispBg     = firstSgv.ToStr()
    result.bgColorHex = bgColor(firstSgv)
    result.trendStr   = arrow(firstDir)
    result.ageSec     = firstSec
    result.utcOffMin  = utcOffMin
    result.timeStr    = fmtSec(firstSec + utcOffMin * 60)
    result.entriesCSV = entryStr
    result.debugInfo  = "OK. "

    if delta >= 0
        result.dispDelta = "+" + delta.ToStr()
    else
        result.dispDelta = delta.ToStr()
    end if

    m.top.result = result
end sub

sub doFetchBasals()
    ' Fetches Temp basal treatments, ALWAYS 25 hours, or 300 records, worth. 
    ' Fetching 25 hours worth of data keeps the vertical scale stable when the graph timespan changes. 
    baseUrl = m.top.nsUrl.trim()
    token   = m.top.nsToken.trim()

    if baseUrl = "" then return

    while right(baseUrl, 1) = "/"
        baseUrl = left(baseUrl, len(baseUrl) - 1)
    end while
    if left(baseUrl, 7) = "http://"
        baseUrl = "https://" + mid(baseUrl, 8)
    end if

    count  = 25 * 12  ' 24h + 1h buffer at max, at 12 temp basals/hr
    if count < 48 then count = 48

    apiUrl = baseUrl + "/api/v1/treatments.json?count=" + count.ToStr()
    apiUrl = apiUrl + "&find[eventType]=Temp+Basal"
    if token <> "" then apiUrl = apiUrl + "&token=" + token

    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.SetUrl(apiUrl)
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.AddHeader("Accept", "application/json")
    http.InitClientCertificates()
    http.SetMessagePort(port)

    if not http.AsyncGetToString() then return
    msg = wait(10000, port)
    if msg = invalid or type(msg) <> "roUrlEvent" then return
    if msg.GetResponseCode() <> 200 then return

    data = ParseJson(msg.GetString())
    if data = invalid or type(data) <> "roArray" then return

    ' Compute window. 
    dtNow    = CreateObject("roDateTime")
    dtNow.Mark()
    nowSec   = dtNow.AsSeconds()
    startSec = nowSec - 25 * 3600  ' always 24h+ window for scale consistency. 

    ' Build CSV (|SV aka PSV): startSec,durationSec,rateTenths. 
    ' Rate stored as tenths of U/hr (e.g. 12 = 1.2 U/hr), just to dodge Brightscript's Floating Point issues. 
    result = ""
    for each t in data
        absolute = 0.0
        duration = 0
        startT   = 0

        av = t["absolute"]
        if av <> invalid then absolute = val(av.ToStr())
        dv = t["duration"]
        if dv <> invalid then duration = int(val(dv.ToStr()))
        ca = t["created_at"]
        if ca <> invalid then startT = isoToSec(ca.ToStr())

        ' Filter to records in union with the 24 hour window. 
        ' Records temp basal rate as INTEGER TENTHS of U/hr (e.g. 12 for 1.2 U/hr), just to dodge Brightscript's Floating Point issues. 
        endT = startT + duration * 60
        if startT > 0 and endT >= startSec
            rateTenths = int(absolute * 10.0 + 0.5)
            if result <> "" then result = result + "|"
            result = result + startT.ToStr() + "," + (duration * 60).ToStr() + "," + rateTenths.ToStr()
        end if
    end for

    m.top.basals = result
end sub


sub doFetchTreatments()
    ' Fetch BOLUS Treatments. 
    ' Brightscript issues with 32-bit integer overflows for epoch seconds timestamps are avoided, 
    ' by accomodating a sufficient number of boluses (up to (hours+1)*6) count, rather than a date filter. 
    ' That is, for a 4 hour plot, we'll be prepared for up to 30 boluses. 6 Boluses per hour should be plenty.
    ' Nightscout returns treatments also in reverse-chronological order.
    ' All date filtering is done in-scene, using integer seconds. 
    baseUrl  = m.top.nsUrl.trim()
    token    = m.top.nsToken.trim()
    hours    = m.top.graphHours
    bolusMin = m.top.bolusMinU

    if baseUrl = "" then return

    while right(baseUrl, 1) = "/"
        baseUrl = left(baseUrl, len(baseUrl) - 1)
    end while
    if left(baseUrl, 7) = "http://"
        baseUrl = "https://" + mid(baseUrl, 8)
    end if

    ' Fetch enough treatments to cover the window.
    count  = (hours + 1) * 6
    if count < 24 then count = 24

    apiUrl = baseUrl + "/api/v1/treatments.json?count=" + count.ToStr()
    apiUrl = apiUrl + "&find[insulin][$gt]=0"
    if token <> "" then apiUrl = apiUrl + "&token=" + token

    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.SetUrl(apiUrl)
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.AddHeader("Accept", "application/json")
    http.InitClientCertificates()
    http.SetMessagePort(port)

    if not http.AsyncGetToString() then return
    msg = wait(10000, port) ' 10 seconds. 
    if msg = invalid or type(msg) <> "roUrlEvent" then return
    if msg.GetResponseCode() <> 200 then return

    data = ParseJson(msg.GetString())
    if data = invalid or type(data) <> "roArray" then return

    ' Compute window start using integer seconds (avoids ms overflow)
    dtNow    = CreateObject("roDateTime")
    dtNow.Mark()
    nowSec   = dtNow.AsSeconds()
    startSec = nowSec - (hours + 1) * 3600

    ' Build CSV aka PSV: dateSec,insulin,carbs per bolus entry
    ' Only include entries with insulin >= bolusMin and within time window
    result = ""
    for each t in data
        insulin = 0.0
        carbs   = 0
        dateSec = 0

        iv = t["insulin"]
        if iv <> invalid then insulin = val(iv.ToStr())
        cv = t["carbs"]
        if cv <> invalid then carbs = int(val(cv.ToStr()))

        ' Parse created_at ISO string to epoch seconds
        ca = t["created_at"]
        if ca <> invalid
            dateSec = isoToSec(ca.ToStr())
        end if

        if insulin >= bolusMin and dateSec >= startSec
            ' Encode insulin as integer tenths to avoid float strings
            insulinTenths = int(insulin * 10.0 + 0.5)
            if result <> "" then result = result + "|"
            result = result + dateSec.ToStr() + "," + insulinTenths.ToStr() + "," + carbs.ToStr()
        end if
    end for

    m.top.treatments = result
end sub

' Convert epoch ms integer to ISO 8601 date string for API query. 
function fromMsToISO(ms as LongInteger) as String
    sec = int(ms / 1000)
    dt  = CreateObject("roDateTime")
    dt.FromSeconds(sec)
    y   = dt.GetYear().ToStr()
    mo  = zp2(dt.GetMonth())
    d   = zp2(dt.GetDayOfMonth())
    h   = zp2(dt.GetHours())
    mn  = zp2(dt.GetMinutes())
    return y + "-" + mo + "-" + d + "T" + h + ":" + mn + ":00.000Z"
end function

' Parse ISO 8601 string "2025-03-25T14:30:00.000Z" to epoch seconds. 
function isoToSec(iso as String) as Integer
    if len(iso) < 19 then return 0
    yr  = left(iso, 4).ToInt()
    mo  = mid(iso, 6, 2).ToInt()
    dy  = mid(iso, 9, 2).ToInt()
    hr  = mid(iso, 12, 2).ToInt()
    mn  = mid(iso, 15, 2).ToInt()
    sc  = mid(iso, 18, 2).ToInt()

    ' Days since epoch using Julian Day Number method. 
    a   = int((14 - mo) / 12)
    y2  = yr + 4800 - a
    m2  = mo + 12 * a - 3
    jdn = dy + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045
    ' Julian Day Number of Unix epoch (1970-01-01) = 2440588
    days = jdn - 2440588
    return days * 86400 + hr * 3600 + mn * 60 + sc
end function

function zp2(n as Integer) as String
    'Adds leading zeros to integers, and returns a string.
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function


sub doFetchDeviceStatus()
    ' Fetches insulin pump battery information. 
    baseUrl = m.top.nsUrl.trim()
    token   = m.top.nsToken.trim()
    if baseUrl = "" then return

    while right(baseUrl, 1) = "/"
        baseUrl = left(baseUrl, len(baseUrl) - 1)
    end while
    if left(baseUrl, 7) = "http://"
        baseUrl = "https://" + mid(baseUrl, 8)
    end if

    apiUrl = baseUrl + "/api/v1/devicestatus.json?count=1"
    if token <> "" then apiUrl = apiUrl + "&token=" + token

    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.SetUrl(apiUrl)
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.AddHeader("Accept", "application/json")
    http.InitClientCertificates()
    http.SetMessagePort(port)

    if not http.AsyncGetToString() then return
    msg = wait(8000, port)
    if msg = invalid or type(msg) <> "roUrlEvent" then return
    if msg.GetResponseCode() <> 200 then return

    data = ParseJson(msg.GetString())
    if data = invalid or type(data) <> "roArray" or data.Count() = 0 then return

    ' Walk records looking for pump.battery.percent
    pct = -1
    for each rec in data
        pump = rec["pump"]
        if type(pump) = "roAssociativeArray"
            batt = pump["battery"]
            if type(batt) = "roAssociativeArray"
                pv = batt["percent"]
                if pv <> invalid
                    pct = int(val(pv.ToStr()))
                    exit for
                end if
            end if
        end if
    end for

    m.top.batteryPct = pct
end sub


sub doFetchPills()
    ' Makes 5 HTTP requests, one per pill type.
    '   Each has a 30-day lookback date filter. 
    '   HTTP requests are sequential since this is is one task thread, and supports only one HTTP request at a time. 
    ' Includes IAGE CAGE SAGE and BAGE
        ' IAGE = Insulin age
        ' CAGE = Canula age
        ' SAGE = Sensor age (CGM)
        ' BAGE = Battery age
    
    baseUrl = m.top.nsUrl.trim()
    token   = m.top.nsToken.trim()
    if baseUrl = "" then return

    while right(baseUrl, 1) = "/"
        baseUrl = left(baseUrl, len(baseUrl) - 1)
    end while
    if left(baseUrl, 7) = "http://"
        baseUrl = "https://" + mid(baseUrl, 8)
    end if

    ' Fetch most recent treatment of each type. 
    ' Returns pipe-delimited: name,epochSec|name,epochSec|...
    types = [
        "cage:Site+Change",
        "sage:Sensor+Change",
        "sagestart:Sensor+Start",
        "iage:Insulin+Change",
        "bage:Pump+Battery+Change"
    ]

    result = ""
    for each entry in types
        parts = entry.split(":")
        name  = parts[0]
        etype = parts[1]

        ' Use 30-day lookback - sensor/cannula changes could be as long as weeks ago. 
        dtP = CreateObject("roDateTime")
        dtP.Mark()
        lookbackSec = dtP.AsSeconds() - 30 * 86400
        dtP.FromSeconds(lookbackSec)
        yr  = dtP.GetYear().ToStr()
        mo  = zp2(dtP.GetMonth())
        dy  = zp2(dtP.GetDayOfMonth())
        fromDate = yr + "-" + mo + "-" + dy
        apiUrl = baseUrl + "/api/v1/treatments.json?count=1"
        apiUrl = apiUrl + "&find[eventType]=" + etype
        apiUrl = apiUrl + "&find[created_at][$gte]=" + fromDate
        if token <> "" then apiUrl = apiUrl + "&token=" + token

        port = CreateObject("roMessagePort")
        http = CreateObject("roUrlTransfer")
        http.SetUrl(apiUrl)
        http.SetCertificatesFile("common:/certs/ca-bundle.crt")
        http.AddHeader("Accept", "application/json")
        http.InitClientCertificates()
        http.SetMessagePort(port)

        if http.AsyncGetToString()
            msg = wait(8000, port)
            if msg <> invalid and type(msg) = "roUrlEvent" and msg.GetResponseCode() = 200
                data = ParseJson(msg.GetString())
                if type(data) = "roArray" and data.Count() > 0
                    ca = data[0]["created_at"]
                        if ca <> invalid
                        epochSec = isoToSec(ca.ToStr())
                                if epochSec > 0
                            if result <> "" then result = result + "|"
                            result = result + name + "," + epochSec.ToStr()
                        end if
                    end if
                else
                    end if
            else
                if msg = invalid
                    else
                    end if
            end if
        end if
    end for

    ' Append dbsize from status if available (we store it separately). 
    m.top.pills = result
end sub


sub doFetchStatus()    
    ' Gets a list of things: 
        ' Nightscout Site's Display name
        ' List of ENABLED plugins, from the JSON field array, which this loops through and join space-delimited. 
        ' List of SHOWN plugins, from the JSON field array, which this loops through and join space-delimited. 
            ' In the scene, pluginEnabled() will check either concatenated list using instr(). 
        ' Time Format (12h or 24h). 
        ' WARN and URGENT thresholds for IAGE CAGE SAGE and BAGE. 
            ' Avoiding assocarray for thresholds because alwaysNotify for assocarray unreliably triggers observers.
            ' Instead, this encodes them as a 10-value CSV string. 
    baseUrl = m.top.nsUrl.trim()
    token   = m.top.nsToken.trim()
    if baseUrl = "" then return

    while right(baseUrl, 1) = "/"
        baseUrl = left(baseUrl, len(baseUrl) - 1)
    end while
    if left(baseUrl, 7) = "http://"
        baseUrl = "https://" + mid(baseUrl, 8)
    end if

    apiUrl = baseUrl + "/api/v1/status.json"
    if token <> "" then apiUrl = apiUrl + "?token=" + token

    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.SetUrl(apiUrl)
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.AddHeader("Accept", "application/json")
    http.InitClientCertificates()
    http.SetMessagePort(port)

    if not http.AsyncGetToString() then return
    msg = wait(10000, port)
    if msg = invalid or type(msg) <> "roUrlEvent" then return
    if msg.GetResponseCode() <> 200 then return

    data = ParseJson(msg.GetString())
    if data = invalid then return

    customTitle = ""
    enableStr   = ""
    showStr     = ""
    settings = data["settings"]
    if type(settings) = "roAssociativeArray"
        ct = settings["customTitle"]
        if ct <> invalid then customTitle = ct.ToStr()
        ev = settings["enable"]
        if type(ev) = "roArray"
            for each item in ev
                enableStr = enableStr + " " + item.ToStr()
            end for
        else if ev <> invalid
            enableStr = ev.ToStr()
        end if
        sv = settings["showPlugins"]
        if type(sv) = "roArray"
            for each item in sv
                showStr = showStr + " " + item.ToStr()
            end for
        else if sv <> invalid
            showStr = sv.ToStr()
        end if
    end if

    ' Always set field so alwaysNotify fires (field default is __unset__)
    m.top.nsCustomTitle  = customTitle
    m.top.enabledPlugins = enableStr + " " + showStr
    tf = settings["timeFormat"]
    if tf <> invalid then m.top.timeFormat = int(val(tf.ToStr()))

    ' Read scaleY preference from Nightscout settings. 
    ' Values: "log" (default), "linear", "log-dynamic" 
    sv = settings["scaleY"]
    if sv <> invalid
        m.top.scaleY = LCase(sv.ToStr())
    else
        m.top.scaleY = "log"
    end if
    print "TASK WRITING SCALE-Y: " m.top.scaleY
    
    ' New for v0.8.00011-Alpha
    ' Read scaleY preference from Nightscout settings.
    ' Values: "log" (default), "linear", "log-dynamic"
    sv = settings["scaleY"]
    if sv <> invalid
        m.top.scaleY = LCase(sv.ToStr())
    else
        m.top.scaleY = "log"
    end if
    ' New for v0.8.00011-Alpha
    
    ' Extract pill thresholds from extendedSettings...
    ' CAGE_WARN -> extendedSettings.cage.warn, etc...
    ' BAGE_WARN_P -> extendedSettings.bage.warnP (percentage, not hours)
    cageWarn    = 72  : cageUrgent  = 96
    sageWarn    = 144 : sageUrgent  = 164
    iageWarn    = 44  : iageUrgent  = 48
    bageWarn    = 240 : bageUrgent  = 360
    bageWarnP   = -1  : bageUrgentP = -1  ' -1 = not specified
    ext = data["extendedSettings"]
    if type(ext) = "roAssociativeArray"
        cg = ext["cage"]
        if type(cg) = "roAssociativeArray"
            v = cg["warn"]    : if v <> invalid then cageWarn    = int(val(v.ToStr()))
            v = cg["urgent"]  : if v <> invalid then cageUrgent  = int(val(v.ToStr()))
        end if
        sg = ext["sage"]
        if type(sg) = "roAssociativeArray"
            v = sg["warn"]    : if v <> invalid then sageWarn    = int(val(v.ToStr()))
            v = sg["urgent"]  : if v <> invalid then sageUrgent  = int(val(v.ToStr()))
        end if
        ig = ext["iage"]
        if type(ig) = "roAssociativeArray"
            v = ig["warn"]    : if v <> invalid then iageWarn    = int(val(v.ToStr()))
            v = ig["urgent"]  : if v <> invalid then iageUrgent  = int(val(v.ToStr()))
        end if
        bg = ext["bage"]
        if type(bg) = "roAssociativeArray"
            v = bg["warn"]    : if v <> invalid then bageWarn    = int(val(v.ToStr()))
            v = bg["urgent"]  : if v <> invalid then bageUrgent  = int(val(v.ToStr()))
            v = bg["warnP"]   : if v <> invalid then bageWarnP   = int(val(v.ToStr()))
            v = bg["urgentP"] : if v <> invalid then bageUrgentP = int(val(v.ToStr()))
        end if
        
        ' Extract bolus render settings from extendedSettings.bolus. 
        ' renderOver: U threshold separating small from large bolus display. 
        ' renderFormat: label format for large boluses ("default", "concise", "minimal", "hidden"). 
        ' renderFormatSmall: label format for small boluses (same options). 
        bolusRenderOver        = "0.1"    ' default: Show all boluses. 
        bolusRenderFormat      = "default" ' large: "0.5U" style. 
        bolusRenderFormatSmall = "default" ' small: Same by default. 
        bl = ext["bolus"]
        if type(bl) = "roAssociativeArray"
            v = bl["renderOver"]        : if v <> invalid then bolusRenderOver        = v.ToStr()
            v = bl["renderFormat"]      : if v <> invalid then bolusRenderFormat      = LCase(v.ToStr())
            v = bl["renderFormatSmall"] : if v <> invalid then bolusRenderFormatSmall = LCase(v.ToStr())
        end if
        m.top.bolusSettings = bolusRenderOver + "|" + bolusRenderFormat + "|" + bolusRenderFormatSmall
    end if
    ' Emit as CSV: cageWarn,cageUrgent,sageWarn,sageUrgent,iageWarn,iageUrgent,bageWarn,bageUrgent,bageWarnP,bageUrgentP
    tCsv = cageWarn.ToStr() + "," + cageUrgent.ToStr()
    tCsv = tCsv + "," + sageWarn.ToStr() + "," + sageUrgent.ToStr()
    tCsv = tCsv + "," + iageWarn.ToStr() + "," + iageUrgent.ToStr()
    tCsv = tCsv + "," + bageWarn.ToStr() + "," + bageUrgent.ToStr()
    tCsv = tCsv + "," + bageWarnP.ToStr() + "," + bageUrgentP.ToStr()
    m.top.pillThresholds = tCsv
end sub


sub doFetchProfile()
    ' Fetches Nightscout treatment profile (Profile basals) from /api/v1/profile.json 
        ' Profile basals are the pre-programmed basal rates based on time-of-day. 
        ' This will encode them as minOfDay,rateTenth|... CSV/PSV. 
        ' Profile basals will fill gaps in the temp basal plot, and usually provides data until temp basal data is reported. 
    ' Also retrieves bgLow & bgHigh thresholds. 
        ' These thresholds are used to color graph bands and glucose datapoints. 
    ' Extra logic supports many anticipated Nightscout JSON structures, like arrays, objects, and nested under STORE. 
    baseUrl = m.top.nsUrl.trim()
    token   = m.top.nsToken.trim()
    if baseUrl = "" then return

    while right(baseUrl, 1) = "/"
        baseUrl = left(baseUrl, len(baseUrl) - 1)
    end while
    if left(baseUrl, 7) = "http://"
        baseUrl = "https://" + mid(baseUrl, 8)
    end if

    apiUrl = baseUrl + "/api/v1/profile.json"
    if token <> "" then apiUrl = apiUrl + "?token=" + token

    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.SetUrl(apiUrl)
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.AddHeader("Accept", "application/json")
    http.InitClientCertificates()
    http.SetMessagePort(port)

    if not http.AsyncGetToString() then return
    msg = wait(10000, port)
    if msg = invalid or type(msg) <> "roUrlEvent" then return
    if msg.GetResponseCode() <> 200 then return

    data = ParseJson(msg.GetString())
    if data = invalid then return

    ' Profile can be array or single object
    prof = data
    if type(data) = "roArray" and data.Count() > 0 then prof = data[0]
    if prof = invalid then return

    ' Extract bgLow and bgHigh. Nightscout uses "low" and "high" in profile.
    bgLow  = 80
    bgHigh = 180

    ' Try direct fields
    lowVal  = prof["low"]
    highVal = prof["high"]
    if lowVal  <> invalid then bgLow  = int(lowVal)
    if highVal <> invalid then bgHigh = int(highVal)

    ' Also try inside defaultProfile or store
    dp = prof["defaultProfile"]
    if dp = invalid then dp = prof["store"]
    if type(dp) = "roAssociativeArray"
        lv = dp["low"]  : if lv <> invalid then bgLow  = int(lv)
        hv = dp["high"] : if hv <> invalid then bgHigh = int(hv)
    end if

    ' Extract basal schedule from profile store
    basalCSV = ""
    defName  = prof["defaultProfile"]
    if defName = invalid then defName = "Default"
    store = prof["store"]
    if type(store) = "roAssociativeArray"
        profData = store[defName.ToStr()]
        if profData = invalid
            ' Try first key in store
            for each k in store
                profData = store[k]
                exit for
            end for
        end if
        if type(profData) = "roAssociativeArray"
            basalSched = profData["basal"]
            if type(basalSched) = "roArray"
                for each entry in basalSched
                    tStr = entry["time"]
                    vVal = entry["value"]
                    if tStr <> invalid and vVal <> invalid
                        ' Convert HH:MM to minutes since midnight
                        parts = tStr.ToStr().split(":")
                        if parts.Count() >= 2
                            minOfDay = parts[0].ToInt() * 60 + parts[1].ToInt()
                            rateTenths = int(val(vVal.ToStr()) * 10.0 + 0.5)
                            if basalCSV <> "" then basalCSV = basalCSV + "|"
                            basalCSV = basalCSV + minOfDay.ToStr() + "," + rateTenths.ToStr()
                        end if
                    end if
                end for
            end if
        end if
    end if
    m.top.basalSchedule = basalCSV
    
    ' Extract carb ratio schedule from profile store. 
    ' carbratio can be a single number or a time-based array like basal. 
    ' Encoded as minOfDay,rateTenths|... CSV (tenths of g/U for precision). 
    carbCSV = ""
    if type(profData) = "roAssociativeArray"
        carbSched = profData["carbratio"]
        if type(carbSched) = "roArray"
            ' Time-based schedule: [{time:"HH:MM", value:N}, ...]
            for each entry in carbSched
                tStr = entry["time"]
                vVal = entry["value"]
                if tStr <> invalid and vVal <> invalid
                    parts = tStr.ToStr().split(":")
                    if parts.Count() >= 2
                        minOfDay   = parts[0].ToInt() * 60 + parts[1].ToInt()
                        rateTenths = int(val(vVal.ToStr()) * 10.0 + 0.5)
                        if carbCSV <> "" then carbCSV = carbCSV + "|"
                        carbCSV = carbCSV + minOfDay.ToStr() + "," + rateTenths.ToStr()
                    end if
                end if
            end for
        else if carbSched <> invalid
        ' Single value: encode as minOfDay=0 
        rateTenths = int(val(carbSched.ToStr()) * 10.0 + 0.5)
        carbCSV = "0," + rateTenths.ToStr()
        end if
    end if
    m.top.carbRatio = carbCSV

    m.top.profile = {bgLow: bgLow, bgHigh: bgHigh}
end sub


function bgColor(mg as Integer) as String
    ' Default Color Scales for Glucose Datapoints. 
    if mg < 55  then return "0xFF2222FF"
    if mg < 70  then return "0xFF6600FF"
    if mg > 250 then return "0xFF2222FF"
    if mg > 180 then return "0xFFAA00FF"
    return "0x44FF88FF"
end function

function arrow(dir as String) as String
    ' ASCII Text Arrow Generation based on trend description from Nightscout. 
    if dir = "DoubleUp"      then return "^^"
    if dir = "SingleUp"      then return "^"
    if dir = "FortyFiveUp"   then return "/^"
    if dir = "Flat"          then return "-->"
    if dir = "FortyFiveDown" then return "\v"
    if dir = "SingleDown"    then return "v"
    if dir = "DoubleDown"    then return "vv"
    return "?"
end function

function fmtSec(sec as Integer) as String
    ' Formats an epoch second as HH:mm. 
    d = CreateObject("roDateTime")
    d.FromSeconds(sec)
    h  = d.GetHours()
    mn = d.GetMinutes()
    hs  = h.ToStr()  : if h  < 10 then hs  = "0" + hs
    mns = mn.ToStr() : if mn < 10 then mns = "0" + mns
    return hs + ":" + mns
end function

function regRead(key as String) as String
    ' Wrapper for roRegistrySection using nightscout section, to read STRING keys. 
    sec = CreateObject("roRegistrySection", "nightscout")
    if sec.Exists(key) then return sec.Read(key)
    return ""
end function

function regReadInt(key as String, def as Integer) as Integer
    ' Wrapper for roRegistrySection using nightscout section, to read INTEGER keys. 
    v = regRead(key)
    if v = "" then return def
    return v.ToInt()
end function

sub regWrite(key as String, val as String)
    ' Wrapper for roRegistrySection using nightscout section, to write STRING keys. 
    sec = CreateObject("roRegistrySection", "nightscout")
    sec.Write(key, val)
    sec.Flush()
end sub

sub regWriteInt(key as String, val as Integer)
    ' Wrapper for roRegistrySection using nightscout section, to write INTEGER keys. 
    regWrite(key, val.ToStr())
end sub
