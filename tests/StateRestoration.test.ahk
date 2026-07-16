#Requires AutoHotkey v2.0
#SingleInstance Off
#Include ..\src\WinMover.ahk

try {
    RunTests()
    ExitApp(0)
} catch as err {
    FileAppend('State restoration tests failed: ' err.Message '`n' err.Stack '`n', '*')
    ExitApp(1)
}

RunTests() {
    testGui := Gui('+AlwaysOnTop')
    testGui.Show('x100 y100 w200 h120')
    MouseMove(150, 150)

    mover := TestWinMover()
    dpiBefore := DllCall('GetThreadDpiAwarenessContext', 'ptr')
    AssertThrows(() => mover.Call(testGui.Hwnd, 0, 0, 1, 1, MonitorGetCount() + 1))
    Assert(DllCall('GetThreadDpiAwarenessContext', 'ptr') = dpiBefore, 'Call must restore DPI awareness.')
    AssertThrows(() => mover.Move(0, 0, 1, 1, MonitorGetCount() + 1, testGui.Hwnd))
    Assert(DllCall('GetThreadDpiAwarenessContext', 'ptr') = dpiBefore, 'Move must restore DPI awareness.')

    mover.TerminateMoveCallback := ThrowForced
    CoordMode('Mouse', 'Window')
    AssertThrows(() => mover.DynamicMove())
    Assert(CoordMode('Mouse', 'Window') = 'Window', 'DynamicMove must restore mouse coordinate mode.')
    Assert(DllCall('GetThreadDpiAwarenessContext', 'ptr') = dpiBefore, 'DynamicMove must restore DPI awareness.')

    mover.TerminateSizeCallback := ThrowForced
    MouseMove(150, 150)
    CoordMode('Mouse', 'Window')
    AssertThrows(() => mover.DynamicResize())
    Assert(CoordMode('Mouse', 'Window') = 'Window', 'DynamicResize must restore mouse coordinate mode.')
    Assert(DllCall('GetThreadDpiAwarenessContext', 'ptr') = dpiBefore, 'DynamicResize must restore DPI awareness.')

    AssertThrows(() => mover.DynamicMove_CapsLock())
    Assert(mover.RestoreCalls = 1, 'CapsLock wrappers must restore state after an error.')

    capsLockBefore := GetKeyState('CapsLock', 'T')
    try {
        mover := WinMover()
        mover.__RestoreCapsLockState(capsLockBefore)
        expectedState := GetKeyState('CapsLock', 'P') ? capsLockBefore : !capsLockBefore
        Assert(GetKeyState('CapsLock', 'T') = expectedState, 'CapsLock restoration must preserve toggle behavior.')
    } finally {
        SetCapsLockState(capsLockBefore)
    }

    CoordMode('Mouse', 'Window')
    mover.ShowTooltip('State restoration test')
    Assert(CoordMode('Mouse', 'Window') = 'Window', 'Popup positioning must restore mouse coordinate mode.')

    AssertThrows(() => PopupWindow_ControlFitText.TextExtentPadding({ Hwnd: 0 }, '', -4))
    Assert(DllCall('GetThreadDpiAwarenessContext', 'ptr') = dpiBefore, 'Popup measurement must restore DPI awareness.')

    capsChordMover := ChordTestWinMover()
    capsChordMover.CapsLockState := GetKeyState('CapsLock', 'T')
    PrimeTimer(capsChordMover)
    AssertThrows(() => capsChordMover.Chord_CapsLock(1))
    Assert(capsChordMover.UnsetCalls = 1, 'CapsLock chord must remove temporary hotkeys after an error.')
    Assert(capsChordMover.RestoreCalls = 1, 'CapsLock chord must restore state after an error.')

    timerMover := ChordTestWinMover()
    timerMover.CapsLockState := GetKeyState('CapsLock', 'T')
    timerMover.ThrowOnUnset := true
    AssertThrows(() => WinMover_Timer_CapsLock(timerMover.id))
    Assert(timerMover.RestoreCalls = 1, 'CapsLock timer must restore state when hotkey cleanup fails.')
    testGui.Destroy()
}

ThrowForced(*) {
    throw Error('Forced test error.')
}

PrimeTimer(mover) {
    callback := (*) => 0
    SetTimer(callback, -10000)
    mover.Timer := callback
}

class TestWinMover extends WinMover {
    RestoreCalls := 0

    __RestoreCapsLockState(*) {
        this.RestoreCalls += 1
    }
}

class ChordTestWinMover extends TestWinMover {
    UnsetCalls := 0
    ThrowOnUnset := false

    CallHelper(*) {
        ThrowForced()
    }

    __UnsetChordKeys() {
        this.UnsetCalls += 1
        if this.ThrowOnUnset {
            ThrowForced()
        }
    }
}

AssertThrows(callback) {
    try callback()
    catch {
        return
    }
    throw Error('Expected an error.')
}

Assert(condition, message) {
    if !condition {
        throw Error(message)
    }
}
