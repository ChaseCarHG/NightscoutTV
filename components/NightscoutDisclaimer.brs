' Show splash for 8 seconds, then signal main thread via global node.
' Main thread owns the screen and will close it.

' Here's a copy of the text in the disclaimer image
' IMPORTANT
' As with Nightscout, it is important to understand that this project:
' * is an open-source, community-based project and is not supported by any company
' * is not officially approved or regulated for diabetes therapy and/or treatment in any way
' You must understand that you take full responsibility for building and running this DIY
' system and you agree to do so at your own risk.
'
' SAFETY
' * This project requires a working internet connection and availability of any
'   third-party cloud services used
' * Do not rely only on Nightscout as the only way you have of knowing your blood
'   glucose values and trends
' * Make sure you're ready to cope with an unexpected failure and always have
'   alternative ways to check your blood glucose levels
'
' https://github.com/ChaseCarHG/NightscoutTV/wiki

sub init()
    m.timer          = CreateObject("roSGNode", "Timer")
    m.timer.duration = 8
    m.timer.repeat   = false
    m.timer.observeField("fire", "onTimer")
    m.timer.control  = "start"
    m.top.setFocus(true)
end sub

sub onTimer()
    m.global.disclaimerDone = true
end sub

