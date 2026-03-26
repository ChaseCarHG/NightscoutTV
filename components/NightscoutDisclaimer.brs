' Show splash for 8 seconds, then signal main thread via global node.
' Main thread owns the screen and will close it.

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
