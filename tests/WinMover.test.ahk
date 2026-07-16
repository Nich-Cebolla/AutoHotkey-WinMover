#Requires AutoHotkey v2.0
#SingleInstance Off
#Include ..\src\WinMover.ahk

try {
    MonitorGet(1, &left, &top, &right, &bottom)
    Assert(dMon.FromPos(left, top, right, bottom) is dMon, 'FromPos must return a dMon object.')
    Assert(dMon.FromDimensions(left, top, right - left, bottom - top) is dMon, 'FromDimensions must return a dMon object.')
    Assert(dMon.FromDimensionsH(left, top, right - left, bottom - top) != 0, 'FromDimensionsH must return a monitor handle.')

    maxRight := -2147483648
    loop MonitorGetCount() {
        MonitorGet(A_Index, , , &monitorRight)
        maxRight := Max(maxRight, monitorRight)
    }
    Assert(dMon.GetNonvisiblePosition() = maxRight + 1, 'GetNonvisiblePosition must check every monitor.')

    dMon.UseOrderedMonitors := { OriginIs1: false }
    Assert(dMon[1] is dMon, 'Custom ordered-monitor lookup must return a dMon object.')
    ExitApp(0)
} catch as err {
    FileAppend('WinMover tests failed: ' err.Message '`n' err.Stack '`n', '*')
    ExitApp(1)
}

Assert(condition, message) {
    if !condition {
        throw Error(message)
    }
}
