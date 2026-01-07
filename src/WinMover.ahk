/*
    Github: https://github.com/Nich-Cebolla/AutoHotkey-WinMover
    Author: Nich-Cebolla
    License: MIT
*/

class WinMover {
    static __New() {
        this.DeleteProp('__New')
        this.Collection := Map()
        this.Collection.CaseSense := this.Collection.Default := false
        Proto := this.Prototype
        Proto.MonNum := 1
        Proto.Presets := Map(
            1, { X: 0, Y: 0, W: 0.5, H: 1 } ; left-half
          , 2, { X: 0.5, Y: 0, W: 0.5, H: 1 } ; right-half
          , 3, { X: 0, Y: 0, W: 1, H: 1 } ; full-screen
          , 'q', { X: 0, Y: 0, W: 0.5, H: 0.5 } ; top-left quarter
          , 'w', { X: 0.5, Y: 0, W: 0.5, H: 0.5 } ; top-right quarter
          , 'a', { X: 0, Y: 0.5, W: 0.5, H: 0.5 } ; bottom-left quarter
          , 's', { X: 0.5, Y: 0.5, W: 0.5, H: 0.5 } ; bottom-right quarter
        )
        Proto.ChordTimerDuration := 2000
        Proto.TerminateMoveCallback := (*) => !GetKeyState('LButton', 'P')
        Proto.TerminateSizeCallback := (*) => !GetKeyState('RButton', 'P')
        proto.PopupWindowOptions := { BackColor: 0xF9F9C7, Duration: -2000, OffsetX: 15 }
    }
    /**
     * @param {String} [ChordModifier] - If set, the modifier key that is used for key chords.
     * Leave unset to prevent setting the key chord hotkeys. You can call
     * {@link WinMover.Prototype.EnableKeyChords} at any time to enable the hotkeys.
     *
     * @param {Map} [Presets] - You can set `Presets` with a `Map` object to define custom options to
     * use when resizing a window using {@link WinMover.Prototype.Chord}. The map keys correspond to
     * the second key of the key chord. The map values are objects specifying the target position
     * and size of the currently active window.
     *
     * The objects have properties { X, Y, W, H }. Each property value is a number that is multiplied
     * with the monitor's corresponding value.
     *
     * For example, if my object is { X: 0, Y: 0, W: 1, H: 1 }, then the window will be moved to the
     * top-left corner of the monitor and the window will be resized to occupy the monitor's entire
     * work area.
     *
     * If my object is { X: 0.5, Y: 0, W: 0.5, H: 1 }, then the window will be moved to the top-center
     * position of the monitor's work area, and the window will be resized to occupy the right-half
     * of the monitor's work area.
     *
     * The built-in default has the following options:
     * - 1 : { X: 0, Y: 0, W: 0.5, H: 1 } (the window will occupy the left half of the monitor)
     * - 2 : { X: 0.5, Y: 0, W: 0.5, H: 1 } (the window will occupy the right half of the monitor)
     * - 3 : { X: 0, Y: 0, W: 1, H: 1 } (the window will occupy the entire monitor)
     * - q : { X: 0, Y: 0, W: 0.5, H: 0.5 } (the window will occupy the top-left quarter of the monitor)
     * - w : { X: 0.5, Y: 0, W: 0.5, H: 0.5 } (the window will occupy the top-right quarter of the monitor)
     * - a : { X: 0, Y: 0.5, W: 0.5, H: 0.5 } (the window will occupy the bottom-left quarter of the monitor)
     * - s : { X: 0.5, Y: 0.5, W: 0.5, H: 0.5 } (the window will occupy the bottom-right quarter of the monitor)
     *
     * See the README for more details.
     *
     * @param {Integer} [ChordTimerDuration = 2000] - The maximum number of milliseconds permitted
     * to elapse after initiating a key chord before the timer expires.
     *
     * @param {Object} [PopupWindowOptions] - {@link PopupWindow} is used to display a message by
     * the mouse pointer when a hotkey is activated but a valid window is not found beneath the
     * mouse cursor. You can define the options with this parameter.
     */
    __New(ChordModifier?, Presets?, ChordTimerDuration := 2000, PopupWindowOptions?) {
        this.ChordModifier := ChordModifier
        ; Assign a unique id and cache a reference to this object within the
        ; ParseXlsx.Collection map. This allows related objects to obtain a reference
        ; to one another without creating a reference cycle.
        loop 100 {
            id := Random(1, 4294967295)
            if !WinMover.Collection.Has(id) {
                this.id := id
                break
            }
        }
        if !this.HasOwnProp('id') {
            throw Error('Failed to produce a unique id.')
        }
        WinMover.Collection.Set(id, this)
        ObjRelease(ObjPtr(this))
        if IsSet(Presets) {
            this.Presets := Presets
        }
        this.PopupWindow := PopupWindow(, PopupWindowOptions ?? this.PopupWindowOptions)
        this.ChordTimerDuration := -Abs(ChordTimerDuration)
        this.Timer := 0
        if IsSet(ChordModifier) {
            this.EnableKeyChords(ChordModifier)
        }
    }
    Call(Hwnd, X, Y, W, H, MonNum?) {
        mon := dMon[MonNum ?? this.MonNum]
        WinMove(
            mon.LeftW + mon.WidthW * X
          , mon.TopW + mon.HeightW * Y
          , mon.WidthW * W
          , mon.HeightW * H
          , Hwnd
        )
    }
    CallHelper(Hwnd, PresetKey) {
        if this.Presets.Has(PresetKey) {
            preset := this.Presets.Get(PresetKey)
        } else if this.Base.Presets.Has(PresetKey) {
            preset := this.Base.Presets.Get(PresetKey)
        } else {
            throw UnsetItemError('Item not found.', -1, PresetKey)
        }
        this(Hwnd, preset.X, preset.Y, preset.W, preset.H)
    }
    Chord(Value, *) {
        if this.Timer {
            SetTimer(this.Timer, 0)
            this.Timer := 0
            this.CallHelper(WinGetId('A'), Value)
            this.__UnsetChordKeys()
        } else {
            this.MonNum := Value
            this.Timer := WinMover_Timer.Bind(this.id)
            this.__SetChordKeys()
            SetTimer(this.Timer, this.ChordTimerDuration)
        }
    }
    Chord_CapsLock(Value, *) {
        capsLockState := GetKeyState('CapsLock', 'T')
        if this.Timer {
            SetTimer(this.Timer, 0)
            this.Timer := 0
            this.CallHelper(WinGetId('A'), Value)
            ; If caps lock was off when "Chord" was first called
            if this.capsLockState {
                ; If caps lock is currently down
                if GetKeyState('CapsLock', 'P') {
                    SetCapsLockState(1)
                } else {
                    SetCapsLockState(0)
                }
            ; If caps lock was on when "Chord" was first called and if caps lock is currently down
            } else if GetKeyState('CapsLock', 'P') {
                SetCapsLockState(0)
            } else {
                SetCapsLockState(1)
            }
            this.__UnsetChordKeys()
        } else {
            this.MonNum := Value
            this.CapsLockState := capsLockState
            this.Timer := WinMover_Timer_CapsLock.Bind(this.id)
            this.__SetChordKeys()
            SetTimer(this.Timer, this.ChordTimerDuration)
        }
    }
    DynamicMove(*) {
        MouseMode := CoordMode('Mouse', 'Screen')
        DpiAwareness := DllCall('SetThreadDpiAwarenessContext', 'ptr', -4, 'ptr')
        MouseGetPos(&x, &y, &hwnd)
        if !hwnd {
            this.ShowTooltip('No window found')
            return
        }
        if WinGetMinMax(hwnd) {
            WinRestore(hwnd)
            mon := dMon(dMon.FromWin(hwnd))
            WinMove(
                wx := mon.LeftW
              , wy := mon.TopW
              , ww := mon.WidthW
              , wh := mon.HeightW
              , hwnd
            )
        } else {
            WinGetPos(&wx, &wy, &ww, &wh, hwnd)
        }
        cb := this.TerminateMoveCallback
        loop {
            if cb() {
                break
            }
            MouseGetPos(&x2, &y2)
            WinMove(wx + x2 - x, wy + y2 - y, , , hwnd)
            sleep 10
        }
        CoordMode('Mouse', MouseMode)
        DllCall('SetThreadDpiAwarenessContext', 'ptr', DpiAwareness, 'ptr')
    }
    DynamicMove_CapsLock(*) {
        capsLockState := GetKeyState('CapsLock', 'T')
        this.DynamicMove()
        if GetKeyState('CapsLock', 'P') {
            SetCapsLockState(capsLockState)
        } else {
            SetCapsLockState(!capsLockState)
        }
    }
    DynamicMoveControl(*) {
        MouseMode := CoordMode('Mouse', 'Client')
        DpiAwareness := DllCall('SetThreadDpiAwarenessContext', 'ptr', -4, 'ptr')
        MouseGetPos(&x, &y, , &hwnd, 2)
        if !hwnd {
            this.ShowTooltip('No window found')
            return
        }
        ControlGetPos(&wx, &wy, &ww, &wh, hwnd)
        cb := this.TerminateMoveCallback
        loop {
            if cb() {
                break
            }
            MouseGetPos(&x2, &y2)
            ControlMove(wx + x2 - x, wy + y2 - y, , , hwnd)
            sleep 10
        }
        CoordMode('Mouse', MouseMode)
        DllCall('SetThreadDpiAwarenessContext', 'ptr', DpiAwareness, 'ptr')
    }
    DynamicMoveControl_CapsLock(*) {
        capsLockState := GetKeyState('CapsLock', 'T')
        this.DynamicMoveControl()
        if GetKeyState('CapsLock', 'P') {
            SetCapsLockState(capsLockState)
        } else {
            SetCapsLockState(!capsLockState)
        }
    }
    DynamicResize(*) {
        MouseMode := CoordMode('Mouse', 'Screen')
        DpiAwareness := DllCall('SetThreadDpiAwarenessContext', 'ptr', -4, 'ptr')
        MouseGetPos(&x, &y, &hwnd)
        if !hwnd {
            this.ShowTooltip('No window found')
            return
        }
        if WinGetMinMax(hwnd) {
            WinRestore(hwnd)
            mon := dMon(dMon.FromWin(hwnd))
            WinMove(
                wx := mon.LeftW
              , wy := mon.TopW
              , ww := mon.WidthW
              , wh := mon.HeightW
              , hwnd
            )
        } else {
            WinGetPos(&wx, &wy, &ww, &wh, hwnd)
        }
        if x > wx + ww / 2 {
            x_quotient := 1
            GetX := XCallback1
        } else {
            x_quotient := -1
            GetX := XCallback2
        }
        if y > wy + wh / 2 {
            y_quotient := 1
            GetY := YCallback1
        } else {
            y_quotient := -1
            GetY := YCallback2
        }
        cb := this.TerminateSizeCallback
        loop {
            if cb() {
                break
            }
            MouseGetPos(&x2, &y2)
            WinMove(GetX(), GetY(), ww + (x2 - x) * x_quotient, wh + (y2 - y) * y_quotient, hwnd)
            sleep 10
        }

        CoordMode('Mouse', MouseMode)
        DllCall('SetThreadDpiAwarenessContext', 'ptr', DpiAwareness, 'ptr')
        return

        XCallback1() {
            return wx
        }
        XCallback2() {
            return wx + x2 - x
        }
        YCallback1() {
            return wy
        }
        YCallback2() {
            return wy + y2 - y
        }
    }
    DynamicResize_CapsLock(*) {
        capsLockState := GetKeyState('CapsLock', 'T')
        this.DynamicResize()
        if GetKeyState('CapsLock', 'P') {
            SetCapsLockState(capsLockState)
        } else {
            SetCapsLockState(!capsLockState)
        }
    }
    DynamicResizeControl(*) {
        MouseMode := CoordMode('Mouse', 'Client')
        DpiAwareness := DllCall('SetThreadDpiAwarenessContext', 'ptr', -4, 'ptr')
        MouseGetPos(&x, &y, , &hwnd, 2)
        if !hwnd {
            this.ShowTooltip('No window found')
            return
        }
        ControlGetPos(&wx, &wy, &ww, &wh, hwnd)
        if x > wx + ww / 2 {
            x_quotient := 1
            GetX := XCallback1
        } else {
            x_quotient := -1
            GetX := XCallback2
        }
        if y > wy + wh / 2 {
            y_quotient := 1
            GetY := YCallback1
        } else {
            y_quotient := -1
            GetY := YCallback2
        }
        cb := this.TerminateSizeCallback
        loop {
            if cb() {
                break
            }
            MouseGetPos(&x2, &y2)
            ControlMove(GetX(), GetY(), ww + (x2 - x) * x_quotient, wh + (y2 - y) * y_quotient, hwnd)
            sleep 10
        }

        CoordMode('Mouse', MouseMode)
        DllCall('SetThreadDpiAwarenessContext', 'ptr', DpiAwareness, 'ptr')

        return

        XCallback1() {
            return wx
        }
        XCallback2() {
            return wx + x2 - x
        }
        YCallback1() {
            return wy
        }
        YCallback2() {
            return wy + y2 - y
        }
    }
    DynamicResizeControl_CapsLock(*) {
        capsLockState := GetKeyState('CapsLock', 'T')
        this.DynamicResizeControl()
        if GetKeyState('CapsLock', 'P') {
            SetCapsLockState(capsLockState)
        } else {
            SetCapsLockState(!capsLockState)
        }
    }
    /**
     * @param {String} ChordModifier - The modifier key that is used for key chords.
     */
    EnableKeyChords(ChordModifier) {
        this.ChordModifier := ChordModifier
        mon_functions := this.MonitorFunctions := []
        if ChordModifier = 'CapsLock' {
            functions := this.Functions := Map()
            for key in this.Presets {
                functions.Set(key, ObjBindMethod(this, 'Chord_CapsLock', key))
            }
            loop MonitorGetCount() {
                mon_functions.Push(ObjBindMethod(this, 'Chord_CapsLock', A_Index))
                HotKey(ChordModifier ' & ' A_Index, mon_functions[A_Index], 'On')
            }
        } else {
            functions := this.Functions := Map()
            for key in this.Presets {
                functions.Set(key, ObjBindMethod(this, 'Chord', key))
            }
            loop MonitorGetCount() {
                mon_functions.Push(ObjBindMethod(this, 'Chord', A_Index))
                HotKey(ChordModifier ' & ' A_Index, mon_functions[A_Index], 'On')
            }
        }
        this.CallbackOnDeviceChange := WinMover_OnDeviceChange.Bind(this.id)
        OnMessage(0x0219, this.CallbackOnDeviceChange, 1)
    }
    ShowTooltip(Str) {
        this.PopupWindow.SetText(Str)
        this.PopupWindow.ShowByMouse()
    }
    UpdateMonitorCount() {
        if this.MonitorFunctions.Length > MonitorGetCount() {
            ChordModifier := this.ChordModifier
            mon_functions := this.MonitorFunctions
            loop mon_functions.Length - MonitorGetCount() {
                HotKey(ChordModifier ' & ' mon_functions.Length, mon_functions.RemoveAt(-1), 'Off')
            }
        } else if this.MonitorFunctions.Length < MonitorGetCount() {
            ChordModifier := this.ChordModifier
            mon_functions := this.MonitorFunctions
            n := mon_functions.Length
            if ChordModifier = 'CapsLock' {
                loop MonitorGetCount() - n {
                    i := A_Index + n
                    mon_functions.Push(ObjBindMethod(this, 'Chord_CapsLock', i))
                    HotKey(ChordModifier ' & ' i, mon_functions[i], 'On')
                }
            } else {
                loop MonitorGetCount() - n {
                    i := A_Index + n
                    mon_functions.Push(ObjBindMethod(this, 'Chord', i))
                    HotKey(ChordModifier ' & ' i, mon_functions[i], 'On')
                }
            }
        }
    }
    __Delete() {
        ObjPtrAddRef(this)
        if WinMover.Collection.Has(this.id) {
            WinMover.Collection.Delete(this.id)
        }
    }
    __SetChordKeys() {
        modifier := this.ChordModifier
        for key, fn in this.Functions {
            HotKey(modifier ' & ' key, fn, 'On')
        }
    }
    __UnsetChordKeys() {
        modifier := this.ChordModifier
        n := this.MonitorFunctions.Length
        for key, fn in this.Functions {
            if !IsInteger(key) || key = 0 || key > n {
                HotKey(modifier ' & ' key, fn, 'Off')
            }
        }
    }
}

WinMover_Timer(id) {
    if WinMover.Collection.Has(id) {
        _winMover := WinMover.Collection.Get(id)
        _winMover.Timer := 0
        _winMover.__UnsetChordKeys()
    }
}
WinMover_Timer_CapsLock(id) {
    if WinMover.Collection.Has(id) {
        _winMover := WinMover.Collection.Get(id)
        _winMover.Timer := 0
        _winMover.__UnsetChordKeys()
        ; If caps lock was off when "Chord" was first called
        if _winMover.capsLockState {
            ; If caps lock is currently down
            if GetKeyState('CapsLock', 'P') {
                SetCapsLockState(1)
            } else {
                SetCapsLockState(0)
            }
        ; If caps lock was on when "Chord" was first called and if caps lock is currently down
        } else if GetKeyState('CapsLock', 'P') {
            SetCapsLockState(0)
        } else {
            SetCapsLockState(1)
        }
    }
}

WinMover_OnDeviceChange(id, *) {
    if WinMover.Collection.Has(id) {
        WinMover.Collection.Get(id).UpdateMonitorCount()
    }
}

/**
 * @classdesc - `dMon` contains several functions for getting a monitor's handle. The `dMon`
 * instance objects are intended to be disposable objects that retrieve the details from "GetMonitorInfo"
 * and that expose methods and properties that simplify usage of that information.
 */
class dMon {
    static __New() {
        this.DeleteProp('__New')
        dMon_SetConstants()
        this.UseOrderedMonitors := true
    }

    /**
     * @description
     * @param {Integer} Hmon - The monitor handle.
     * @returns {dMon} - The dMon instance object.
     */
    __New(Hmon) {
        this.Buffer := Buffer(40)
        this.Hmon := Hmon
        NumPut('Uint', 40, this.Buffer)
        if !DllCall('user32\GetMonitorInfo', 'ptr', Hmon, 'ptr', this.Buffer, 'int') {
            throw OSError('``GetMonitorInfo`` failed.', -1)
        }
    }

    ;@region FromDim
    /**
     * Gets the monitor handle using the dimensions of a rectangle.
     * @param {Integer} X - The x-coordinate of the Top-Left corner of the rectangle.
     * @param {Integer} Y - The y-coordinate of the Top-Left corner of the rectangle.
     * @param {Integer} W - The Width of the rectangle.
     * @param {Integer} H - The Height of the rectangle.
     * @returns {Integer} - The Hmon of the monitor to which the rectangle has the largest area
     * of intersection.
     */
    static FromDimensions(X, Y, W, H) => dMon.FromPos(X, Y, x+w, y+h)
    ;@endregion



    ;@region FromIndex
    /**
     * Gets the monitor handle using an index value.
     * @param {Integer} Index - This index of the monitor as defined by the system.
     * @returns {Integer} - The Hmon of the monitor.
     */
    static FromIndex(Index) {
        MonitorGet(Index, &L, &T)
        return this.FromPoint(L, T)
    }
    ;@endregion



    ;@region FromMouse
    /**
     * @description - Gets the monitor handle using the position of the mouse pointer.
     * Note that the Dpi_AWARENESS_CONTEXT value impacts the Result of this function. If the mouse
     * is within a monitor that has a different Dpi than the system, the coordinates are adjusted.
     * The AHK `CoordMode` does not influence the value.
     * @param {VarRef} [OutX] - The variable to store the x-coordinate of the mouse pointer
     * @param {VarRef} [OutY] - The variable to store the y-coordinate of the mouse pointer
     * @returns {Integer} - The Hmon of the monitor that contains the mouse pointer.
     */
    static FromMouse(&OutX?, &OutY?) {
        if Result := DllCall('User32.dll\GetCursorPos', 'ptr', Pt := Point(), 'int') {
            OutX := Pt.X
            OutY := Pt.Y
            return DllCall('User32\MonitorFromPoint', 'ptr', Pt.Value, 'uint', 0 , 'ptr')
        }
    }
    ;@endregion



    ;@region FromPoint
    /**
     * @description - Gets monitor handle from a coordinate pair.
     * @param {Integer} X - The x-coordinate of the point.
     * @param {Integer} Y - The y-coordinate of the point.
     * @returns {Integer} - The Hmon of the monitor that contains the point.
     * @see {@link https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfrompoint}
     */
    static FromPoint(X, Y){
        return DllCall('User32\MonitorFromPoint', 'ptr', (X & 0xFFFFFFFF) | (Y << 32), 'uint', 0 , 'ptr')
    }
    ;@endregion



    ;@region FromRect
    /**
     * @description - Gets the monitor handle from a `Rect` object.
     * @param {Rect} RectObj - The `Rect` object.
     * @returns {Integer} - The Hmon of the monitor that contains the rectangle.
     * @see {@link https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfromRect}
     */
    static FromRect(RectObj) {
        return DllCall('User32.dll\MonitorFromRect', 'ptr', RectObj, 'UInt', 0, 'Uptr')
    }
    ;@endregion



    ;@region FromPos
    /**
     * @description - Gets the monitor handle using a bounding rectangle.
     * @param {Integer} L - The Left edge of the rectangle.
     * @param {Integer} T - The Top edge of the rectangle.
     * @param {Integer} R - The Right edge of the rectangle.
     * @param {Integer} B - The Bottom edge of the rectangle.
     * @returns {Integer} - The handle of the monitor that contains the rectangle.
     * @see {@link https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfromRect}
     */
    static FromPos(L, T, R, B) {
        return DllCall('User32.dll\MonitorFromRect', 'ptr', Rect(L, T, R, B), 'UInt', 0, 'Uptr')
    }
    ;@endregion



    ;@region FromWin
    /**
     * @description - Gets the monitor handle using a window handle.
     * @param {Integer} Hwnd - The window handle.
     * @returns {Integer} - The monitor handle.
     * @see {@link https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfromwindow}
     */
    static FromWin(Hwnd) {
        return DllCall('User32.dll\MonitorFromWindow', 'ptr', Hwnd, 'UInt', 0x00000000, 'Uptr')
    }
    ;@endregion



    ;@region Dpi
    /**
     * @class
     * @description - Returns the DPI of the monitor using various input types.
     */
    class Dpi {
        static __New() {
            if this.Prototype.__Class == 'dMon.Dpi' {
                this.DefineProp('__Call', { Call: MetaSetThreadDpiAwareness })
            }
        }
        static Call(Hmon, DpiType := MDT_DEFAULT) {
            if !DllCall('Shcore\GetDpiForMonitor', 'ptr', Hmon, 'UInt', DpiType, 'UInt*', &DpiX := 0, 'UInt*', &DpiY := 0, 'UInt') {
                return DpiX
            }
        }
        static Pos(Left, Top, Right, Bottom, DpiType := MDT_DEFAULT) => dMon.Dpi(dMon.FromPos(Left, Top, Right, Bottom), DpiType)
        static Rect(RectObj, DpiType := MDT_DEFAULT) => dMon.Dpi(dMon.FromRect(RectObj), DpiType)
        static Dimensions(X, Y, W, H, DpiType := MDT_DEFAULT) => dMon.Dpi(dMon.FromDimensions(X, Y, W, H), DpiType)
        static Mouse(DpiType := MDT_DEFAULT) => dMon.Dpi(dMon.FromMouse(), DpiType)
        static Point(X, Y, DpiType := MDT_DEFAULT) => dMon.Dpi(dMon.FromPoint(X, Y), DpiType)
        static Win(Hwnd, DpiType := MDT_DEFAULT) => dMon.Dpi(dMon.FromWin(Hwnd), DpiType)
    }
    ;@endregion


    static GetNonvisiblePosition(Width) {
        right := 0
        for mon in dMon {
            right := Max(right, mon.Right)
        }
        return right + Width + 1
    }



    ;@region GetOrder
    /**
     * @description - Orders the display monitors according to the input values. The main benefit of
     * using this function is that it allows one to reference the monitors using a static index value.
     * Typically, when referring to a monitor using `MonitorGet`, the monitor which is referred to
     * by a given index depends on the display settings of the system, which may change if the
     * user adjusts the settings. When writing functions that depend on coordinates relative to an
     * arbitrary monitor, this behavior may or may not be preferable.
     * - Using the system settings' monitor index - At least on Windows 10+, but I believe on 7+
     * as well, we can choose which monitor is "1", "2", "3", etc from Settings > "Display Settings".
     * This changes what monitor is referenced by a given index when calling functions like
     * `MonitorGet`, irrespective of the monitors' position relative to other monitors. With one set
     * of settings, monitor 2 may be at coordinate (-1000, -1200), and later if the user changes
     * the settings, monitor 2 may be at coordinate (1980, -750).
     * - Using `UseOrderedMonitors` and `dMon[Index]` - `GetOrder` constructs an array of Hmon values,
     * ordering them according to the input parameters. Monitors are ordered as a function of their
     * position relative to one another. Example:
     *   - If the user has a three-monitor setup, where one monitor is physically to the left and
     * above the main display, and the third is physically to the right and above the main display,
     * `UseOrderedMonitors` allows your function to refer to a monitor by index where the index will
     * always refer to the main, top-left, or top-right monitor even if the user changes the system
     * settings (as long as monitors' relative positions do not change). This type of behavior
     * may be preferable for some; for others, the native behavior may be preferable.
     *
     * Here are some examples to clarify what this function does:
     *
     * Say a user has three monitors, the primary monitor is the laptop display at the bottom, and
     * two external monitors adjacent to one another and above the laptop. When calling window
     * functions that move a window to a position relative to a monitor's boundaries, the function
     * needs a way to consistently refer to the monitors, so each monitor gets an index `1, 2, or 3`.
     * The user prefers the primary monitor to be 1, the left monitor to be 2, and the right monitor
     * to be 3. To accomplish this, call the function without parameters; the defaults will follow
     * this order.
     * @example
     *   ;  ____________
     *   ;  |    ||    |
     *   ;  ------------
     *   ;     ______
     *   ;     |    |
     *   ;     ------
     *   MoveWindowToRightHalf(MonitorIndex, Hwnd) {
     *       ; Get a new list every function call in case the user plugs in / removes a monitor.
     *       List := dMon.GetOrder()
     *       ; Get the `dMon` instance.
     *       MonUnit := dMon(List[MonitorIndex])
     *       ; Move, fitting the window in the right-half of the monitor's work area.
     *       WinMove(MonUnit.MidXW, MonUnit.TW, MonUnit.WW / 2, MonUnit.HW, Hwnd)
     *   }
     * @
     * Perhaps the user has three monitors where one is on top, and beneath it two adjacent monitors,
     * and they want the top monitor to be 1, and the right monitor to be 2, and the left monitor to
     * be 3.
     * @example
     *   ;     ______
     *   ;     |    |
     *   ;     ------
     *   ;  ____________
     *   ;  |    ||    |
     *   ;  ------------
     *   List := dMon.GetOrder('X', L2R := false, T2B := true, OriginIs1 := false)
     * @
     * Many people have a laptop but use an external monitor as their "primary", so it might be
     * more intuitive for them to have their "primary" monitor be referenced by index 1, instead of
     * the built-in display.
     * @example
     *   ; Left-most monitor would be 1. If two monitors both share the lowest X coordinate, the
     *   ; monitor with the lowest Y coordinate between the two would be 1.
     *   List := dMon.GetOrder(, , , OriginIs1 := false)
     * @
     * If your script is going to be frequently referring to a monitor using the ordered Hmon index,
     * you can set `dMon.UseOrderedMonitors` to true and get a new `dMon` instance using item notation
     * and the index. This uses the default values.
     * @example
     *   dMon.UseOrderedMonitors := true
     *   MonUnit := dMon[1] ; The primary monitor
     *   MonUnit := dMon[2] ; The top-left monitor
     * @
     * To use item notation with a different ordering schema, set `UseOrderedMonitors` to
     * an object with one or more properties that have the same name as the parameters you want
     * passed to `GetOrder`.
     * @example
     *   dMon.UseOrderedMonitors := { OriginIs1: false }
     *   MonUnit := dMon[1] ; The top-left monitor
     * @
     * @param {String} [Primary='X'] - Determines which axis is primarily considered when ordering
     * the monitors. When comparing two monitors, if their positions along the Primary axis are
     * equal, then the alternate axis is compared and used to break the tie. Otherwise, only the
     * Primary axis is used for comparison.
     * - X: Check horizontal first.
     * - Y: Check vertical first.
     * @param {Boolean} [LeftToRight=true] - If true, the monitors are ordered in ascending order
     * along the X axis when the dimension along the X axis is compared.
     * @param {Boolean} [TopToBottom=true] - If true, the monitors are ordered in ascending order
     * along the Y axis when the dimension along the Y axis is compared.
     */
    static GetOrder(Primary := 'X', LeftToRight := true, TopToBottom := true, OriginIs1 := true) {
        List := []
        Result := []
        loop Result.Capacity := List.Capacity := MonitorGetCount() {
            MonitorGet(A_Index, &L, &T)
            Unit := { L: L, T: T }
            if !L && !T && OriginIs1 {
                Temp := Unit
            } else {
                List.Push(Unit)
            }
        }
        OrderRects(List, Primary, LeftToRight, TopToBottom)
        if IsSet(Temp) {
            Result.Push(dMon.FromPoint(Temp.L, Temp.T))
        }
        for Item in List {
            Result.Push(dMon.FromPoint(Item.L, Item.T))
        }
        return Result
    }
    ;@endregion


    /**
     * @description - Enables the usage of two suffixes. To use a suffix, append to any class method
     * call an underscore followed by one or both of the following characters:
     * S - Calls `SetThreadDpiAwarenessContext` with the default value prior to the method call.
     * The value used is `DPI_AWARENESS_CONTEXT_DEFAULT`, a global variable. You can change it at
     * any time.
     * U - Returns a `dMon` instance using the return value from the method call, instead of returning
     * the `Hmon` value.
     * @example
     *  MonUnit := dMon.FromWin_SU(WinGetId('A'))
     *  MsgBox(MonUnit.LW) ; Left side of monitor's work area.
     *  MsgBox(MonUnit.Dpi) ; Dpi of monitor.
     * @
     */
    static __Call(Name, Params) {
        Split := StrSplit(Name, '_')
        if this.HasMethod(Split[1]) {
            if InStr(Split[2], 'S') {
                Result := DllCall('SetThreadDpiAwarenessContext', 'ptr', -4, 'ptr')
            }
            if InStr(Split[2], 'U') {
                if Params.Length {
                    return this(this.%Split[1]%(Params*))
                } else {
                    return this(this.%Split[1]%())
                }
            } else {
                if Params.Length {
                    return this(this.%Split[1]%(Params*))
                } else {
                    return this(this.%Split[1]%())
                }
            }
        } else {
            throw PropertyError('Property not found.', -1, Name)
        }
    }

    static __Enum(*) {
        i := 0
        return _Enum

        _Enum(&Mon) {
            if ++i > MonitorGetCount() {
                return 0
            }
            Mon := dMon[i]
            return 1
        }
    }

    static __Item[N := 1] {
        Get => this(this.FromIndex(N))
    }

    static UseOrderedMonitors {
        Get => this.__UseOrderedMonitors
        Set {
            this.__UseOrderedMonitors := Value
            if Value {
                if IsObject(Value) {
                    this.DefineProp('__Item', { Get: this.__Item_Get_Ordered_Params })
                } else {
                    this.DefineProp('__Item', { Get: this.__Item_Get_Ordered_Default })
                }
            } else {
                this.DefineProp('__Item', { Get: this.__Item_Get_NotOrdered })
            }
        }
    }


    GetPos(&X?, &Y?, &W?, &H?) {
        X := this.L
        Y := this.T
        W := this.W
        H := this.H
    }
    SplitW(Divisor) => Rect.Split(this.L, this.W, Divisor)
    SplitH(Divisor) => Rect.Split(this.T, this.H, Divisor)

    GetPosW(&X?, &Y?, &W?, &H?) {
        X := this.LW
        Y := this.TW
        W := this.WW
        H := this.HW
    }
    SplitWW(Divisor) => Rect.Split(this.LW, this.WW, Divisor)
    SplitHW(Divisor) => Rect.Split(this.TW, this.HW, Divisor)

    TL => Point(this.L, this.T)
    Topleft => Point(this.L, this.T)
    BR => Point(this.R, this.B)
    BottomRight => Point(this.R, this.B)
    L => NumGet(this, 4, 'Int')
    Left => NumGet(this, 4, 'Int')
    X => NumGet(this, 4, 'Int')
    T => NumGet(this, 8, 'Int')
    Top => NumGet(this, 8, 'Int')
    Y => NumGet(this, 8, 'Int')
    R => NumGet(this, 12, 'Int')
    Right => NumGet(this, 12, 'Int')
    B => NumGet(this, 16, 'Int')
    Bottom => NumGet(this, 16, 'Int')
    W => this.R - this.L
    Width => this.R - this.L
    H => this.B - this.T
    Height => this.B - this.T
    MidX => (this.R - this.L) / 2
    MidY => (this.B - this.T) / 2
    Primary => NumGet(this, 36, 'Uint')
    TLW => Point(this.LW, this.TW)
    TopLeftW => Point(this.LW, this.TW)
    BRW => Point(this.RW, this.BW)
    BottomRightW => Point(this.RW, this.BW)
    LW => NumGet(this, 20, 'int')
    LeftW => NumGet(this, 20, 'int')
    XW => NumGet(this, 20, 'Int')
    TW => NumGet(this, 24, 'int')
    TopW => NumGet(this, 24, 'int')
    YW => NumGet(this, 24, 'Int')
    RW => NumGet(this, 28, 'int')
    RightW => NumGet(this, 28, 'int')
    BW => NumGet(this, 32, 'int')
    BottomW => NumGet(this, 32, 'int')
    WW => this.RW - this.LW
    WidthW => this.RW - this.LW
    HW => this.BW - this.TW
    HeightW => this.BW - this.TW
    MidXW => (this.RW - this.LW) / 2
    MidYW => (this.BW - this.TW) / 2
    Dpi => dMon.Dpi(this.Hmon)
    Dpi_Raw => dMon.Dpi(this.Hmon, MDT_RAW_DPI)
    Dpi_Angular => dMon.Dpi(this.Hmon, MDT_ANGULAR_DPI)

    Ptr => this.Buffer.Ptr
    Size => this.Buffer.Size


    static __Item_Get_NotOrdered(N, params*) {
        return this(this.FromIndex(N))
    }

    static __Item_Get_Ordered_Default(N, params*) {
        return this(this.GetOrder()[N])
    }

    static __Item_Get_Ordered_Params(N, params*) {
        Params := this.__UseOrderedMonitors
        return this(this.GetOrder(
            HasProp(Params, 'Primary') ? Params.Primary : unset
          , HasProp(Params, 'LeftToRight') ? Params.LeftToRight : unset
          , HasProp(Params, 'TopToBottom') ? Params.TopToBottom : unset
          , HasProp(Params, 'OriginIs1') ? Params.OriginIs1 : unset
        )[N])
    }
}

dMon_SetConstants(force := false) {
    global
    if IsSet(dMon_constants_set) && !force {
        return
    }

    MDT_EFFECTIVE_DPI := 0
    MDT_ANGULAR_DPI := 1
    MDT_RAW_DPI := 2
    MDT_DEFAULT := MDT_EFFECTIVE_DPI

    dMon_constants_set := true
}

/*
    Github: https://github.com/Nich-Cebolla/AutoHotkey-LibV2/blob/main/structs/Rect.ahk
    Author: Nich-Cebolla
    License: MIT
*/

;@region Intro

/*
    As of 8/11/25: Most methods are now tested and working.
*/

/**

        Introduction

    This library provides AHK functions and methods that call common User32.dll functions related to
    RECTs, POINTs, and windows.

        Using a buffer

    This library is designed to allow RECT members of any struct at an arbitrary, static offset
    to make use of the functions. For example, consider the WINDOWINFO struct. There are two
    members that are RECTs: rcWindow at offset 4, and rcClient at offset 20. To avoid repetitive
    code and unnecessary work, the `Window32` class initializes instances like this:
    @example
        MakeWinRectObjects() {
            if this.Hwnd {
                this()
            }
            this.Rect := WinRect(this.Hwnd, false, this.Buffer, this.Offset + 4)
            this.ClientRect := WinRect(this.Hwnd, true, this.Buffer, this.Offset + 20)
        }
    @

    Though separate AHK objects, the objects set to `this.Rect` and `this.ClientRect` both make use
    of the same buffer. Whenever the values of the WINDOWINFO struct are changed, the changes are
    reflected by the AHK objects as well.

        Thread dpi awareness

    This "__Call" method exposes a way to call `SetThreadDpiAwarenessContext` before any other method
    by adding "_S" to the end of the method. By default, the thread dpi awareness context is set to
    -4. To use another value, define a property "DpiAwarenessContext" on an individual object or
    on a prototype object with the desired value. Typically you'll want to use -4 if your application
    is dpi aware. See {@link https://www.autohotkey.com/docs/v2/misc/DPIScaling.htm}.
    @example
        ; The default is already -4; this is for example.
        WinRect.Prototype.DpiAwarenessContext := -4
        hwnd := WinExist('A')
        if !hwnd {
            throw Error('Window not found.', -1)
        }
        wrc := WinRect(hwnd)
        ; This sets the dpi awareness context to -4 prior to performing the action
        wrc.GetPos_S(&x, &y, &w, &h)
    @

    If you are not familiar with meta functions, you will want to read
    {@link https://www.autohotkey.com/docs/v2/Objects.htm#Meta_Functions}.

        Dll function addresses

    To improve performance, the first time a dll function is called from this library, the address
    is cached on `RectBase.Addresses`. The module handles are cached on `RectBase.Modules`. To
    release the handles and free the memory, call `RectBase.UnloadAll`.
*/

;@endregion


;@region Window32 cls

/**
 * Calls `GetWindowRect`. The object has a number of properties to make using it easier.
 * - cbSize - 0:4 - The size of this structure.
 * - rcWindow - 4:16 - The coordinates of the window.
 * - rcClient - 20:16 - THe coordinates of the client area.
 * - dwStyle - 36:4 - The window styles.
 * {@link https://learn.microsoft.com/en-us/windows/desktop/winmsg/window-styles}
 * - dwExStyle - 40:4 - The extende window styles.
 * {@link https://learn.microsoft.com/en-us/windows/desktop/winmsg/extended-window-styles}
 * - dwWindowStatus - 44:4 - The window status. Returns `1` if the window is active. Else, `0`.
 * - cxWindowBorders - 48:4 - The width of the window borders in pixels.
 * - cyWindowBorders - 52:4 - The height of the window border in pixels.
 * - atomWindowType - 56:2 - The window class atom.
 * {@link https://learn.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-registerclassa}.
 * - wCreatorVersion - 58:2 - The Windows version of the application that created the window.
 */
class Window32 {
    static __New() {
        this.DeleteProp('__New')
        this.WindowStyles := Map()
        this.WindowExStyles := Map()
        this.WindowStyles.CaseSense := this.WindowExStyles.CaseSense := false
        this.WindowStyles.Set(
            'WS_OVERLAPPED', 0x00000000
          , 'WS_POPUP', 0x80000000
          , 'WS_CHILD', 0x40000000
          , 'WS_MINIMIZE', 0x20000000
          , 'WS_VISIBLE', 0x10000000
          , 'WS_DISABLED', 0x08000000
          , 'WS_CLIPSIBLINGS', 0x04000000
          , 'WS_CLIPCHILDREN', 0x02000000
          , 'WS_MAXIMIZE', 0x01000000
          , 'WS_CAPTION', 0x00C00000
          , 'WS_BORDER', 0x00800000
          , 'WS_DLGFRAME', 0x00400000
          , 'WS_VSCROLL', 0x00200000
          , 'WS_HSCROLL', 0x00100000
          , 'WS_SYSMENU', 0x00080000
          , 'WS_THICKFRAME', 0x00040000
          , 'WS_GROUP', 0x00020000
          , 'WS_TABSTOP', 0x00010000
          , 'WS_MINIMIZEBOX', 0x00020000
          , 'WS_MAXIMIZEBOX', 0x00010000
        )
        this.WindowExStyles.Set(
            'WS_EX_DLGMODALFRAME', 0x00000001
          , 'WS_EX_NOPARENTNOTIFY', 0x00000004
          , 'WS_EX_TOPMOST', 0x00000008
          , 'WS_EX_ACCEPTFILES', 0x00000010
          , 'WS_EX_TRANSPARENT', 0x00000020
          , 'WS_EX_MDICHILD', 0x00000040
          , 'WS_EX_TOOLWINDOW', 0x00000080
          , 'WS_EX_WINDOWEDGE', 0x00000100
          , 'WS_EX_CLIENTEDGE', 0x00000200
          , 'WS_EX_CONTEXTHELP', 0x00000400
          , 'WS_EX_RIGHT', 0x00001000
          , 'WS_EX_LEFT', 0x00000000
          , 'WS_EX_RTLREADING', 0x00002000
          , 'WS_EX_LTRREADING', 0x00000000
          , 'WS_EX_LEFTSCROLLBAR', 0x00004000
          , 'WS_EX_RIGHTSCROLLBAR', 0x00000000
          , 'WS_EX_CONTROLPARENT', 0x00010000
          , 'WS_EX_STATICEDGE', 0x00020000
          , 'WS_EX_APPWINDOW', 0x00040000
        )
        this.Prototype.cbSize := 60
        this.Make(this)
    }
    static FromDesktop(Buf?, Offset := 0) => this(DllCall(RectBase.GetDesktopWindow, 'ptr'), Buf ?? unset, Offset)
    static FromForeground(Buf?, Offset := 0) => this(DllCall(RectBase.GetForegroundWindow, 'ptr'), Buf ?? unset, Offset)
    /**
     * @param Cmd -
     * - 2 : Returns a handle to the window below the given window.
     * - 3 : Returns a handle to the window above the given window.
     */
    static FromCursor(Buf?, Offset := 0) {
        pt := Point()
        if !DllCall(RectBase.GetCursorPos, 'ptr', pt, 'int') {
            throw OSError()
        }
        return this(DllCall(RectBase.WindowFromPoint, 'int', pt.Value, 'ptr'), Buf ?? unset, Offset)
    }
    static FromNext(Hwnd, Cmd, Buf?, Offset := 0) => this(DllCall(RectBase.GetNextWindow, 'ptr', IsObject(Hwnd) ? Hwnd.Hwnd : Hwnd, 'uint', Cmd, 'ptr'), Buf ?? unset, Offset)
    static FromParent(Hwnd, Buf?, Offset := 0) => this(DllCall(RectBase.GetParent, 'ptr', IsObject(Hwnd) ? Hwnd.Hwnd : Hwnd, 'ptr'), Buf ?? unset, Offset)
    static FromPoint(X, Y, Buf?, Offset := 0) => this(DllCall(RectBase.WindowFromPoint, 'int', (X & 0xFFFFFFFF) | (Y << 32), 'ptr'), Buf ?? unset, Offset)
    static FromShell(Buf?, Offset := 0) => this(DllCall(RectBase.GetShellWindow, 'ptr'), Buf ?? unset, Offset)
    static FromTop(Hwnd := 0, Buf?, Offset := 0) => this(DllCall(RectBase.GetTopWindow, 'ptr', IsObject(Hwnd) ? Hwnd.Hwnd : Hwnd, 'ptr'), Buf ?? unset, Offset)
    /**
     * @param Cmd -
     * - GW_CHILD - 5 - The retrieved handle identifies the child window at the top of the Z order,
     *  if the specified window is a parent window; otherwise, the retrieved handle is NULL. The
     *  function examines only child windows of the specified window. It does not examine descendant
     *  windows.
     *
     * - GW_ENABLEDPOPUP - 6 - The retrieved handle identifies the enabled popup window owned by the
     *  specified window (the search uses the first such window found using GW_HwndNEXT); otherwise,
     *  if there are no enabled popup windows, the retrieved handle is that of the specified window.
     *
     * - GW_HwndFIRST - 0 - The retrieved handle identifies the window of the same type that is highest
     *  in the Z order. If the specified window is a topmost window, the handle identifies a topmost
     *  window. If the specified window is a top-level window, the handle identifies a top-level
     *  window. If the specified window is a child window, the handle identifies a sibling window.
     *
     * - GW_HwndLAST - 1 - The retrieved handle identifies the window of the same type that is lowest
     *  in the Z order. If the specified window is a topmost window, the handle identifies a topmost
     *  window. If the specified window is a top-level window, the handle identifies a top-level window.
     *  If the specified window is a child window, the handle identifies a sibling window.
     *
     * - GW_HwndNEXT - 2 - The retrieved handle identifies the window below the specified window in
     *  the Z order. If the specified window is a topmost window, the handle identifies a topmost
     *  window. If the specified window is a top-level window, the handle identifies a top-level
     *  window. If the specified window is a child window, the handle identifies a sibling window.
     *
     * - GW_HwndPREV - 3 - The retrieved handle identifies the window above the specified window in
     *  the Z order. If the specified window is a topmost window, the handle identifies a topmost
     *  window. If the specified window is a top-level window, the handle identifies a top-level
     *  window. If the specified window is a child window, the handle identifies a sibling window.
     *
     * - GW_OWNER - 4 - The retrieved handle identifies the specified window's owner window, if any.
     *  For more information, see Owned Windows.
     */
    static Get(Hwnd, Cmd, Buf?, Offset := 0) => this(DllCall(RectBase.GetWindow, 'ptr', IsObject(Hwnd) ? Hwnd.Hwnd : Hwnd, 'uint', Cmd, 'ptr'), Buf ?? unset, Offset)
    static Make(Cls, Prefix := '', Suffix := '') {
        Proto := Cls.Prototype
        if !HasMethod(Cls, '__Call') {
            Cls.DefineProp('__Call', { Call: RectSetThreadDpiAwareness__Call })
        }
        if !HasMethod(Proto, '__Call') {
            Proto.DefineProp('__Call', { Call: RectSetThreadDpiAwareness__Call })
        }
        Proto.DefineProp(Prefix 'AdjustRectEx' Suffix, { Call: Window32AdjustRectEx })
        Proto.DefineProp(Prefix 'BringToTop' Suffix, { Call: Window32BringToTop })
        Proto.DefineProp(Prefix 'ChildFromCursor' Suffix, { Call: Window32ChildFromCursor })
        Proto.DefineProp(Prefix 'ChildFromCursorEx' Suffix, { Call: Window32ChildFromCursorEx })
        Proto.DefineProp(Prefix 'ChildFromPoint' Suffix, { Call: Window32ChildFromPoint })
        Proto.DefineProp(Prefix 'ChildFromPointEx' Suffix, { Call: Window32ChildFromPointEx })
        Proto.DefineProp(Prefix 'Dispose' Suffix, { Call: Window32Dispose })
        Proto.DefineProp(Prefix 'Dpi' Suffix, { Get: Window32GetDpi })
        Proto.DefineProp(Prefix 'EnumChildWindows' Suffix, { Call: Window32EnumChildWindows })
        Proto.DefineProp(Prefix 'GetChildBoundingRect' Suffix, { Call: Window32GetChildBoundingRect })
        Proto.DefineProp(Prefix 'GetClientRect' Suffix, { Call: Window32GetClientRect })
        Proto.DefineProp(Prefix 'GetExStyle' Suffix, { Call: Window32GetExStyle })
        Proto.DefineProp(Prefix 'Monitor' Suffix, { Get: Window32GetMonitor })
        Proto.DefineProp(Prefix 'GetStyle' Suffix, { Call: Window32GetStyle })
        Proto.DefineProp(Prefix 'HasExStyle' Suffix, { Call: Window32HasExStyle })
        Proto.DefineProp(Prefix 'HasStyle' Suffix, { Call: Window32HasStyle })
        Proto.DefineProp(Prefix 'IsChild' Suffix, { Call: Window32IsChild })
        Proto.DefineProp(Prefix 'IsParent' Suffix, { Call: Window32IsParent })
        Proto.DefineProp(Prefix 'MoveClient' Suffix, { Call: Window32MoveClient })
        Proto.DefineProp(Prefix 'RealChildFromPoint' Suffix, { Call: Window32RealChildFromPoint })
        Proto.DefineProp(Prefix 'SetActive' Suffix, { Call: Window32SetActive })
        Proto.DefineProp(Prefix 'SetForeground' Suffix, { Call: Window32SetForeground })
        Proto.DefineProp(Prefix 'SetParent' Suffix, { Call: Window32SetParent })
        Proto.DefineProp(Prefix 'SetPosKeepAspectRatio' Suffix, { Call: Window32SetPosKeepAspectRatio })
        Proto.DefineProp(Prefix 'Show' Suffix, { Call: Window32Show })
        Proto.DefineProp(Prefix 'Visible' Suffix, { Get: Window32IsVisible })
        Proto.DefineProp('Ptr', { Get: RectGetPtrFromBuffer })
        Proto.DefineProp('Size', { Get: RectGetSizeFromBuffer })
    }
    __New(Hwnd := 0, Buf?, Offset := 0) {
        this.Hwnd := Hwnd
        if IsSet(Buf) {
            if Buf.Size < this.cbSize + Offset {
                throw Error('The buffer`'s size is insufficient. The size must be 60 + offset or greater.', -1)
            }
            this.Buffer := Buf
        } else {
            this.Buffer := Buffer(this.cbSize + Offset)
        }
        this.Offset := Offset
        NumPut('uint', this.cbSize, this.Buffer, this.Offset)
        this.MakeWinRectObjects()
    }
    Call(*) {
        if !DllCall(RectBase.GetWindowInfo, 'ptr', this.Hwnd, 'ptr', this, 'int') {
            throw OSError()
        }
    }
    /**
     * @description - Sets a callback that updates the object's property "Hwnd" when
     * `Window32.Prototype.Call` is called. By default, `Window32.Prototype.Call` does not
     * update the "Hwnd" property, and instead calls `GetWindowRect` with the current "Hwnd". When
     * `Window32.Prototype.SetCallback` is called, a new method "Call" is defined that calls
     * the callback function and uses the return value to update the property "Hwnd", then calls
     * `GetWindowRect` using that new handle. To remove the callback and return the "Call" method
     * to its original functionality, pass zero or an empty string to `Callback`.
     *
     * This library includes a number of functions that are useful for this, each beginning with
     * "Window32Callback". However, your code will likely benefit from knowing when no window handle
     * is returned by one of the functions, so your code can respond in some type of way. To write your
     * own function that makes use of any of the built-in functions, you can define it this way:
     *
     * If your code does not need the `Window32` object, exclude it using the "*" operator:
     * @example
     *  MyHelperFunc(*) {
     *      hwnd := Window32CallbackFromForeground()
     *      if hwnd {
     *          return hwnd
     *      } else {
     *          ; do something
     *      }
     *  }
     *
     *  win := Window32()
     *  win.SetCallback(MyHelperFunc)
     *  win()
     * @
     *
     * If your code does need the `Window32` object, it will be the first and only parameter.
     * @example
     *  MyHelperFunc(win) {
     *      hwnd := Window32CallbackFromParent(win)
     *      if hwnd {
     *          return hwnd
     *      } else {
     *          ; do something
     *      }
     *  }
     *
     *  hwnd := WinExist('A')
     *  if !hwnd {
     *      throw Error('Window not found.', -1)
     *  }
     *  win := Window32(hwnd)
     *  win.SetCallback(MyHelperFunc)
     *  win()
     *  MsgBox(win.Hwnd == hwnd) ; 0 or 1 depending if a parent window exists
     * @
     *
     * Here's how to use a `Point` object to return the window underneath the Cursor. To avoid relying
     * on global variables, we're going to make a function object that retains a `Point` object as
     * a property.
     * @example
     *  MyFuncObj := { Point: Point() }
     *  MyFuncObj.Point.SetCallAction(2)
     *  MyFuncObj.DefineProp('Call', { Call: MyFunc })
     *  win := Window32()
     *  win.SetCallback(MyFuncObj)
     *  MyFuncObj := unset ; to demonstrate no global variables are needed (other than the function)
     *  win()
     *  MsgBox(win.Hwnd)
     *
     *  MyFunc(Self, *) {
     *      hwnd := Self.Point.Call()
     *      if hwnd {
     *          return hwnd
     *      } else {
     *          ; do something
     *      }
     *  }
     * @
     *
     * @param {*} Callback - A `Func` or callable object that accepts the `Window32` object as its
     * only parameter, and that returns a new "Hwnd" value. If the callback returns zero or an empty
     * string, the property "Hwnd" will not be updated and `GetWindowRect` will not be called.
     * If the callback returns an integer, the property "Hwnd" is updated and `GetWindowRect` is
     * called. If the callback returns another type of value, a TypeError is thrown.
     */
    SetCallback(Callback) {
        if Callback {
            this.DefineProp('Callback', { Call: Callback })
            this.DefineProp('Call', Window32.Prototype.GetOwnPropDesc('__CallWithCallback'))
        } else {
            this.DeleteProp('Callback')
            this.DefineProp('Call', Window32.Prototype.GetOwnPropDesc('Call'))
        }
    }
    __CallWithCallback() {
        if hwnd := this.Callback() {
            if IsInteger(hwnd) {
                this.Hwnd := hwnd
            } else {
                throw TypeError('Invalid ``Hwnd`` returned.', -1, Type(hwnd))
            }
            if !DllCall(RectBase.GetWindowInfo, 'ptr', this.Hwnd, 'ptr', this, 'int') {
                throw OSError()
            }
            return hwnd
        }
    }
    Activate() => WinActivate(this.Hwnd)
    Close() => WinClose(this.Hwnd)
    GetControls() => WinGetControls(this.Hwnd)
    GetControlsHwnd() => WinGetControlsHwnd(this.Hwnd)
    Hide() => WinHide(this.Hwnd)
    Kill() => WinKill(this.Hwnd)
    /**
     * @description - Defines a property "Point" with a value of an instance of `Point`.
     * @param {Integer} [Action = 1] - A value to pass to {@link Point#SetCallAction}.
     */
    MakePoint(Action := 1) {
        this.DefineProp('Point', { Value: Point() })
        this.Point.SetCallAction(Action)
    }
    MakeWinRectObjects() {
        if this.Hwnd {
            this()
        }
        this.Rect := WinRect(this.Hwnd, 0, this.Buffer, this.Offset + 4)
        this.ClientRect := WinRect(this.Hwnd, 1, this.Buffer, this.Offset + 20)
    }
    Maximize() => WinMaximize(this.Hwnd)
    Minimize() => WinMinimize(this.Hwnd)
    MoveBottom() => WinMoveBottom(this.Hwnd)
    MoveTop() => WinMoveTop(this.Hwnd)
    Redraw() => WinRedraw(this.Hwnd)
    Restore() => WinRestore(this.Hwnd)
    SetAlwaysOnTop() => WinSetAlwaysOnTop(this.Hwnd)
    SetEnabled(NewSetting) => WinSetEnabled(NewSetting, this.Hwnd)
    SetRegion(Options?) => WinSetRegion(Options ?? unset, this.Hwnd)
    SetStyle(Value) => WinSetStyle(Value, this.Hwnd)
    SetExStyle(Value) => WinSetExStyle(Value, this.Hwnd)
    SetTransparent(N) => WinSetTransparent(N, this.Hwnd)
    WaitActive(Timeout?) => WinWaitActive(this.Hwnd, , Timeout ?? Unset)
    WaitNotActive(Timeout?) => WinWaitNotActive(this.Hwnd, , Timeout ?? unset)
    WaitClose(Timeout?) => WinWaitClose(this.Hwnd, , Timeout ?? unset)
    Active {
        Get => WinActive(this.Hwnd)
        Set {
            if Value {
                WinActivate(this.Hwnd)
            } else {
                WinMinimize(this.Hwnd)
            }
        }
    }
    Atom => NumGet(this, 56, 'short')
    BorderHeight => NumGet(this, 52, 'int')
    BorderWidth => NumGet(this, 48, 'int')
    Class => WinGetClass(this.Hwnd)
    CreatorVersion => NumGet(this, 58, 'short')
    Exist => WinExist(this.Hwnd)
    ExStyle => NumGet(this, 40, 'uint')
    Maximized => WinGetMinMax(this.Hwnd) == 1
    Minimized => WinGetMinMax(this.Hwnd) == -1
    PID => WinGetPid(this.Hwnd)
    ProcessName => WinGetProcessName(this.Hwnd)
    ProcessPath => WinGetProcessPath(this.Hwnd)
    Status => NumGet(this, 44, 'int')
    Style => NumGet(this, 36, 'uint')
    Text => WinGetText(this.Hwnd)
    Title {
        Get => WinGetTitle(this.Hwnd)
        Set => WinSetTitle(Value, this.Hwnd)
    }
    TransColor {
        Get => WinGetTransColor(this.Hwnd)
        Set => WinSetTransColor(Value, this.Hwnd)
    }
}

;@endregion


;@region WinRect cls

class WinRect extends Rect {
    static __New() {
        this.DeleteProp('__New')
        this.Make(this)
    }
    static Make(Cls, Prefix := '', Suffix := '') {
        Proto := Cls.Prototype
        if !HasMethod(Cls, '__Call') {
            Cls.DefineProp('__Call', { Call: RectSetThreadDpiAwareness__Call })
        }
        if !HasMethod(Proto, '__Call') {
            Proto.DefineProp('__Call', { Call: RectSetThreadDpiAwareness__Call })
        }
        Proto.DefineProp(Prefix 'Apply' Suffix, { Call: WinRectApply })
        Proto.DefineProp(Prefix 'Dispose' Suffix, { Call: RectDispose })
        Proto.DefineProp(Prefix 'GetPos' Suffix, { Call: WinRectGetPos })
        Proto.DefineProp(Prefix 'MapPoints' Suffix, { Call: WinRectMapPoints })
        Proto.DefineProp(Prefix 'Move' Suffix, { Call: WinRectMove })
        Proto.DefineProp(Prefix 'Update' Suffix, { Call: WinRectUpdate })
        Proto.DefineProp('Ptr', { Get: RectGetPtrFromBuffer })
        Proto.DefineProp('Size', { Get: RectGetSizeFromBuffer })
    }
    /**
     * @param {Integer} [Hwnd = 0] - The window handle.
     * @param {Integer} [Flag = 0] - A flag that determines what function is called when the
     * buffer's values are updated using `WinRectGetPos` or `WinRectUpdate`.
     * - 0 : `GetWindowRect`
     * - 1 : `GetClientRect`
     * - 2 : `DwmGetWindowAttribute` passing DWMWA_EXTENDED_FRAME_BOUNDS to dwAttribute.
     *
     * Some controls / windows will cause `DwmGetWindowAttribute` to throw an error.
     *
     * For more information see {@link https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowrect}.
     */
    __New(Hwnd := 0, Flag := 0, Buf?, Offset := 0) {
        this.Hwnd := Hwnd
        if IsSet(Buf) {
            if Buf.Size < 16 + Offset {
                throw Error('The buffer`'s size is insufficient. The size must be 16 + offset or greater.', -1)
            }
            this.Buffer := Buf
        } else {
            this.Buffer := Buffer(16 + Offset)
        }
        this.Offset := Offset
        this.Flag := Flag
        if Hwnd {
            this()
        }
    }
    Call(*) {
        switch this.Flag, 0 {
            case 0:
                DllCall(RectBase.GetWindowRect, 'ptr', this.Hwnd, 'ptr', this, 'int')
            case 1:
                DllCall(RectBase.GetClientRect, 'ptr', this.Hwnd, 'ptr', this, 'int')
            case 2:
                if HRESULT := DllCall(RectBase.Dwmapi_DwmGetWindowAttribute, 'ptr', this.Hwnd, 'uint', 9, 'ptr', this.Buffer.Ptr, 'uint', 16, 'uint') {
                    throw oserror('``DwmGetWindowAttribute`` failed.', -1, 'HRESULT: ' Format('{:X}', HRESULT))
                }
        }
    }
}

;@endregion


;@region Rect cls

class Rect extends RectBase {
    static FromDimensions(X, Y, W, H, Buf?, Offset := 0) => this(X, Y, X + W, Y + H, Buf ?? unset, Offset)
    static FromCursor() {
        rc := this()
        DllCall(RectBase.GetCursorPos, 'ptr', rc, 'int')
        rc.R := rc.L
        rc.B := rc.T
        return rc
    }
    __New(L := 0, T := 0, R := 0, B := 0, Buf?, Offset := 0) {
        if IsSet(Buf) {
            if Buf.Size < 16 + Offset {
                throw Error('The buffer`'s size is insufficient. The size must be 16 + offset or greater.', -1)
            }
            this.Buffer := Buf
        } else {
            this.Buffer := Buffer(16 + Offset)
        }
        this.Offset := Offset
        NumPut('int', L, 'int', T, 'int', R, 'int', B, this.Buffer, Offset)
    }
}

;@endregion


;@region RectBase

class RectBase {
    static __New() {
        this.DeleteProp('__New')
        this.Modules := Map()
        this.Addresses := Map()
        this.Modules.CaseSense := this.Addresses.CaseSense := false
        this.ResidentModules := [ 'User32', 'Kernel32', 'ComCtl32', 'Gdi32' ]
        for dllName in this.ResidentModules {
            this.Modules.Set(dllName, DllCall('GetModuleHandle', 'str', dllName, 'ptr'))
        }
        this.Make(this)
    }
    static __Get(Name, Params) {
        if this.Addresses.Has(Name) {
            return this.Addresses.Get(Name)
        }
        if InStr(Name, '_') {
            modName := StrReplace(SubStr(Name, 1, InStr(Name, '_', , , -1) - 1), '_', '\')
            if this.Modules.Has(modName) {
                hModule := this.Modules.Get(modName)
            } else {
                hModule := DllCall('LoadLibrary', 'str', SubStr(Name, 1, InStr(Name, '_', , , -1) - 1) '.dll', 'ptr')
                if hModule {
                    this.Modules.Set(modName, hModule)
                } else {
                    throw Error('Unable to locate module.', -1, modName)
                }
            }
            _name := SubStr(Name, InStr(Name, '_', , , -1) + 1)
            for modName, hModule in this.Modules {
                if address := DllCall('GetProcAddress', 'ptr', hModule, 'Astr', _name, 'ptr') {
                    this.Addresses.Set(Name, address)
                    return address
                }
            }
            for dllName in this.ResidentModules {
                if address := DllCall('GetProcAddress', 'ptr', this.Modules.Get(dllName), 'Astr', _name, 'ptr') {
                    this.Addresses.Set(Name, address)
                    return address
                }
            }
            throw Error('Unable to locate the function.', -1, Name)
        } else {
            for dllName in this.ResidentModules {
                if address := DllCall('GetProcAddress', 'ptr', this.Modules.Get(dllName), 'Astr', Name, 'ptr') {
                    this.Addresses.Set(Name, address)
                    return address
                }
            }
            return Name
        }
    }
    static UnloadAll(*) {
        for modName, hModule in this.Modules {
            DllCall('FreeLibrary', 'ptr', hModule)
        }
        this.Modules.Clear()
        this.Addresses.Clear()
    }
    static Make(Cls, Prefix := '', Suffix := '') {
        Proto := Cls.Prototype
        if !HasMethod(Cls, '__Call') {
            Cls.DefineProp('__Call', { Call: RectSetThreadDpiAwareness__Call })
        }
        if !HasMethod(Proto, '__Call') {
            Proto.DefineProp('__Call', { Call: RectSetThreadDpiAwareness__Call })
        }
        Proto.DefineProp(Prefix 'B' Suffix, { Get: RectGetCoordinate.Bind(12), Set: RectSetCoordinate.Bind(12) })
        Proto.DefineProp(Prefix 'BL' Suffix, { Get: RectGetPoint.Bind(0, 12) })
        Proto.DefineProp(Prefix 'BR' Suffix, { Get: RectGetPoint.Bind(8, 12) })
        Proto.DefineProp(Prefix 'Clone' Suffix, { Call: RectClone })
        Proto.DefineProp(Prefix 'Dispose' Suffix, { Call: RectDispose })
        Proto.DefineProp(Prefix 'Dpi' Suffix, { Get: RectGetDpi })
        Proto.DefineProp(Prefix 'Equal' Suffix, { Call: RectEqual })
        Proto.DefineProp(Prefix 'GetHeightSegment' Suffix, { Call: RectGetHeightSegment })
        Proto.DefineProp(Prefix 'GetWidthSegment' Suffix, { Call: RectGetWidthSegment })
        Proto.DefineProp(Prefix 'H' Suffix, { Get: RectGetLength.Bind(4), Set: RectSetLength.Bind(4) })
        Proto.DefineProp(Prefix 'Inflate' Suffix, { Call: RectInflate })
        Proto.DefineProp(Prefix 'Intersect' Suffix, { Call: RectIntersect })
        Proto.DefineProp(Prefix 'IsEmpty' Suffix, { Call: RectIsEmpty })
        Proto.DefineProp(Prefix 'L' Suffix, { Get: RectGetCoordinate.Bind(0), Set: RectSetCoordinate.Bind(0) })
        Proto.DefineProp(Prefix 'MidX' Suffix, { Get: (Self) => RectGetWidthSegment(Self, 2) })
        Proto.DefineProp(Prefix 'MidY' Suffix, { Get: (Self) => RectGetHeightSegment(Self, 2) })
        Proto.DefineProp(Prefix 'Monitor' Suffix, { Get: RectGetMonitor })
        Proto.DefineProp(Prefix 'MoveAdjacent' Suffix, { Call: RectMoveAdjacent })
        Proto.DefineProp(Prefix 'OffsetRect' Suffix, { Call: RectOffset })
        Proto.DefineProp(Prefix 'PtIn' Suffix, { Call: RectPtIn })
        Proto.DefineProp(Prefix 'R' Suffix, { Get: RectGetCoordinate.Bind(8), Set: RectSetCoordinate.Bind(8) })
        Proto.DefineProp(Prefix 'Set' Suffix, { Call: RectSet })
        Proto.DefineProp(Prefix 'Subtract' Suffix, { Call: RectSubtract })
        Proto.DefineProp(Prefix 'T' Suffix, { Get: RectGetCoordinate.Bind(4), Set: RectSetCoordinate.Bind(4) })
        Proto.DefineProp(Prefix 'TL' Suffix, { Get: RectGetPoint.Bind(0, 4) })
        Proto.DefineProp(Prefix 'ToClient' Suffix, { Call: RectToClient })
        Proto.DefineProp(Prefix 'ToScreen' Suffix, { Call: RectToScreen })
        Proto.DefineProp(Prefix 'ToString' Suffix, { Call: RectToString })
        Proto.DefineProp(Prefix 'ToStringDeconstructed' Suffix, { Call: RectToStringDeconstructed })
        Proto.DefineProp(Prefix 'TR' Suffix, { Get: RectGetPoint.Bind(8, 4) })
        Proto.DefineProp(Prefix 'Union' Suffix, { Call: RectUnion })
        Proto.DefineProp(Prefix 'Union' Suffix, { Call: RectUnion })
        Proto.DefineProp(Prefix 'W' Suffix, { Get: RectGetLength.Bind(0), Set: RectSetLength.Bind(0) })
        Proto.DefineProp('Ptr', { Get: RectGetPtrFromBuffer })
        Proto.DefineProp('Size', { Get: RectGetSizeFromBuffer })
    }
}

;@endregion


;@region Point cls

class Point {
    static __New() {
        this.DeleteProp('__New')
        this.Make(this)
    }
    static FromCaret() {
        pt := Point()
        DllCall(RectBase.GetCaretPos, 'ptr', pt, 'int')
        return pt
    }
    static FromCursor() {
        pt := Point()
        DllCall(RectBase.GetCursorPos, 'ptr', pt, 'int')
        return pt
    }
    static Make(Cls, Prefix := '', Suffix := '') {
        Proto := Cls.Prototype
        if !HasMethod(Cls, '__Call') {
            Cls.DefineProp('__Call', { Call: RectSetThreadDpiAwareness__Call })
        }
        if !HasMethod(Proto, '__Call') {
            Proto.DefineProp('__Call', { Call: RectSetThreadDpiAwareness__Call })
        }
        Proto.DefineProp(Prefix 'Clone' Suffix, { Call: PtClone })
        Proto.DefineProp(Prefix 'CursorPosToString' Suffix, { Call: PtCursorPosToString })
        Proto.DefineProp(Prefix 'Dispose' Suffix, { Call: RectDispose })
        Proto.DefineProp(Prefix 'Dpi' Suffix, { Get: PtGetDpi })
        Proto.DefineProp(Prefix 'GetCursorPos' Suffix, { Call: PtGetCursorPos })
        Proto.DefineProp(Prefix 'LogicalToPhysical' Suffix, { Call: PtLogicalToPhysical })
        Proto.DefineProp(Prefix 'LogicalToPhysicalForPerMonitorDPI' Suffix, { Call: PtLogicalToPhysicalForPerMonitorDPI })
        Proto.DefineProp(Prefix 'Monitor' Suffix, { Get: PtGetMonitor })
        Proto.DefineProp(Prefix 'PhysicalToLogical' Suffix, { Call: PtPhysicalToLogical })
        Proto.DefineProp(Prefix 'PhysicalToLogicalForPerMonitorDPI' Suffix, { Call: PtPhysicalToLogicalForPerMonitorDPI })
        Proto.DefineProp(Prefix 'SetCaretPos' Suffix, { Call: PtSetCaretPos })
        Proto.DefineProp(Prefix 'ToClient' Suffix, { Call: PtToClient })
        Proto.DefineProp(Prefix 'ToScreen' Suffix, { Call: PtToScreen })
        Proto.DefineProp(Prefix 'Value' Suffix, { Get: PtGetValue })
        Proto.DefineProp(Prefix 'X' Suffix, { Get: RectGetCoordinate.Bind(0), Set: RectSetCoordinate.Bind(0) })
        Proto.DefineProp(Prefix 'Y' Suffix, { Get: RectGetCoordinate.Bind(4), Set: RectSetCoordinate.Bind(4) })
        Proto.DefineProp('Ptr', { Get: RectGetPtrFromBuffer })
        Proto.DefineProp('Size', { Get: RectGetSizeFromBuffer })
    }
    __New(X := 0, Y := 0, Buf?, Offset := 0) {
        if IsSet(Buf) {
            if Buf.Size < 8 + Offset {
                throw Error('The buffer`'s size is insufficient. The size must be 8 + offset or greater.', -1)
            }
            this.Buffer := Buf
        } else {
            this.Buffer := Buffer(8 + Offset)
        }
        this.Offset := Offset
        NumPut('int', X, 'int', Y, this.Buffer, Offset)
    }
    Call(*) {
        if !DllCall(RectBase.GetCursorPos, 'ptr', this, 'int') {
            throw OSError()
        }
    }
    Click(Options := '') => Click(this.X ' ' this.Y ' ' Options)
    ClickDrag(WhichButton, X?, Y?, Speed?, Relative?) => MouseClickDrag(WhichButton, this.X, this.Y, X ?? this.X, Y ?? this.Y, Speed ?? unset, Relative ?? Unset)
    MouseMove(Speed?, Relative?) => MouseMove(this.X, this.Y, Speed ?? Unset, Relative ?? unset)
    GetPixelColor(Mode?) {
        if IsSet(Mode) {
            return PixelGetColor(this.X, this.Y, Mode)
        } else {
            Modes := [ '', 'Alt', 'Slow' ]
            loop {
                if color := PixelGetColor(this.X, this.Y, Modes[A_Index]) || A_Index >= 3 {
                    return color
                }
            }
        }
    }
    /**
     * @param {Integer} Id -
     * - 1 : The default, which updates the object's X and Y values to the cursor's current position.
     * - 2 : Updates the object's X and Y values to the cursor's current position, and calls
     * `WindowFromPoint`, returning the window handle if one is obtained, else returning `0`.
     * - 3 : Updates the object's X and Y values to the cursor's current position, and calls
     * `PixelGetColor`. Note that the X and Y values will always be relative to the screen, and that
     * the default mode for `PixelGetColor` is "Client". Your code must set `CoordMode("Pixel", "Screen")`
     * for this to return the expected result.
     */
    SetCallAction(Id := 1) {
        switch Id, 0 {
            case 1: this.DefineProp('Call', Point.Prototype.GetOwnPropDesc('Call'))
            case 2: this.DefineProp('Call', Point.Prototype.GetOwnPropDesc('__CallGetWindowUnderCursor'))
            case 3: this.DefineProp('Call', Point.Prototype.GetOwnPropDesc('__CallGetPixelUnderCursor'))
        }
    }
    /**
     * @description - `Point.Prototype.SetCallback` changes the method "Call" to do the following:
     * 1. Update's the `Point` object's X and Y values to the cursor's current position relative to
     *    the screen.
     * 2. Calls the callback function, passing the `Point` object to the function.
     * 3. Returns the value from the callback.
     *
     * To disable the callback and return "Call" to the built-in default, pass zero or an empty
     * string to `Callback`.
     */
    SetCallback(Callback) {
        if Callback {
            this.DefineProp('Callback', { Call: Callback })
            this.DefineProp('Call', Point.Prototype.GetOwnPropDesc('__CallWithCallback'))
        } else {
            this.DeleteProp('Callback')
            this.DefineProp('Call', Point.Prototype.GetOwnPropDesc('Call'))
        }
    }
    __CallGetWindowUnderCursor(*) {
        if !DllCall(RectBase.GetCursorPos, 'ptr', this, 'int') {
            throw OSError()
        }
        return DllCall(RectBase.WindowFromPoint, 'int', this.Value, 'ptr')
    }
    __CallGetPixelUnderCursor(*) {
        if !DllCall(RectBase.GetCursorPos, 'ptr', this, 'int') {
            throw OSError()
        }
        return PixelGetColor(this.X, this.Y)
    }
    __CallWithCallback() {
        if !DllCall(RectBase.GetCursorPos, 'ptr', this, 'int') {
            throw OSError()
        }
        return this.Callback()
    }
    PixelColor => this.GetPixelColor()
}

;@endregion


;@region Point funcs

PtClone(pt) => Point(pt.X, pt.Y)
PtCursorPosToString(Pt) {
    DllCall(RectBase.GetCursorPos, 'ptr', pt, 'int')
    return '( ' Pt.X ', ' Pt.Y ' )'
}
PtGetCursorPos(pt) => DllCall(RectBase.GetCursorPos, 'ptr', pt, 'int')
PtGetDpi(pt) {
    if DllCall(RectBase.Shcore_GetDpiForMonitor, 'ptr'
        , DllCall(RectBase.MonitorFromPoint, 'int', pt.Value, 'uint', 0, 'ptr')
    , 'uint', 0, 'uint*', &DpiX := 0, 'uint*', &DpiY := 0, 'int') {
        throw OSError('MonitorFomPoint received an invalid parameter.', -1)
    } else {
        return DpiX
    }
}
PtGetMonitor(pt) {
    return DllCall(RectBase.MonitorFromPoint, 'int', pt.Value, 'uint', 0, 'ptr')
}
PtGetValue(Pt) => (pt.X & 0xFFFFFFFF) | (pt.Y << 32)
PtLogicalToPhysical(pt, Hwnd) {
    DllCall(RectBase.LogicalToPhysical, 'ptr', Hwnd, 'ptr', pt)
}
PtLogicalToPhysicalForPerMonitorDPI(pt, Hwnd) {
    return DllCall(RectBase.LogicalToPhysicalPointForPerMonitorDPI, 'ptr', Hwnd, 'ptr', pt, 'int')
}
PtPhysicalToLogical(pt, Hwnd) {
    DllCall(RectBase.PhysicalToLogical, 'ptr', Hwnd, 'ptr', pt)
}
PtPhysicalToLogicalForPerMonitorDPI(pt, Hwnd) {
    return DllCall(RectBase.PhysicalToLogicalPointForPerMonitorDPI, 'ptr', Hwnd, 'ptr', pt, 'int')
}
PtSetCaretPos(pt) {
    return DllCall(RectBase.SetCaretPos, 'int', pt.X, 'int', pt.Y, 'int')
}
/**
 * @description - Use this to convert screen coordinates (which should already be contained by
 * this `Point` object), to client coordinates.
 * {@link https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-screentoclient}
 * @param {Point} pt - The point.
 * @param {Integer} Hwnd - The handle to the window whose client area will be used for the conversion.
 * @param {Boolean} [InPlace = false] - If true, the function modifies the object's properties.
 * If false, the function creates a new object.
 * @returns {Point}
 */
PtToClient(pt, Hwnd, InPlace := false) {
    if !InPlace {
        pt := Point(pt.X, pt.Y)
    }
    if !DllCall(RectBase.ScreenToClient, 'ptr', Hwnd, 'ptr', pt, 'int') {
        throw OSError()
    }
    return pt
}
/**
 * @description - Use this to convert client coordinates (which should already be contained by
 * this `Point` object), to screen coordinates.
 * {@link https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-clienttoscreen}
 * @param {Point} pt - The point.
 * @param {Integer} Hwnd - The handle to the window whose client area will be used for the conversion.
 * @param {Boolean} [InPlace = false] - If true, the function modifies the object's properties.
 * If false, the function creates a new object.
 * @returns {Point}
 */
PtToScreen(Pt, Hwnd, InPlace := false) {
    if !InPlace {
        pt := Point(pt.X, pt.Y)
    }
    if !DllCall(RectBase.ClientToScreen, 'ptr', Hwnd, 'ptr', pt, 'int') {
        throw OSError()
    }
    return pt
}
PtToString(Pt) {
    return '( ' Pt.X ', ' Pt.Y ' )'
}

;@endregion


;@region Rect funcs

RectClone(rc) => Rect(rc.L, rc.T, rc.R, rc.B)
RectEqual(rc1, rc2) => DllCall(RectBase.EqualRect, 'ptr', rc1, 'ptr', rc2, 'int')
RectGetCoordinate(Offset, rc) => NumGet(rc, Offset, 'int')
RectGetDpi(rc) {
    if DllCall(RectBase.Shcore_GetDpiForMonitor, 'ptr'
        , DllCall(RectBase.Shcore_MonitorFromRect, 'ptr', rc, 'uint', 0, 'ptr')
    , 'uint', 0, 'uint*', &DpiX := 0, 'uint*', &DpiY := 0, 'int') {
        throw OSError('``MonitorFomPoint`` received an invalid parameter.', -1)
    } else {
        return DpiX
    }
}
RectGetHeightSegment(rc, Divisor, DecimalPlaces := 0) => Round(rc.H / Divisor, DecimalPlaces)
RectGetLength(Offset, rc) => NumGet(rc, 8 + Offset, 'int') - NumGet(rc, Offset, 'int')
RectGetMonitor(rc) => DllCall(RectBase.MonitorFromRect, 'ptr', rc, 'UInt', 0, 'Uptr')
RectGetPoint(Offset1, Offset2, rc) => Point(NumGet(rc, Offset1, 'int'), NumGet(rc, Offset2, 'int'))
RectGetPtrFromBuffer(rc) => rc.Buffer.Ptr + rc.Offset
RectGetSizeFromBuffer(rc) => rc.Buffer.Size
RectGetWidthSegment(rc, Divisor, DecimalPlaces := 0) => Round(rc.W / Divisor, DecimalPlaces)
RectInflate(rc, dx, dy) => DllCall(RectBase.InflateRect, 'ptr', rc, 'int', dx, 'int', dy, 'int')
/**
 * @returns {Rect} - If the rectangles intersect, a new `Rect` object is returned. If the rectangles
 * do not intersect, returns an empty string.
 */
RectIntersect(rc1, rc2, Offset := 0) {
    rc := Rect()
    if DllCall(RectBase.IntersectRect, 'ptr', rc, 'ptr', rc1, 'ptr', rc2, 'int') {
        return rc
    }
}
RectIsEmpty(rc) => DllCall(RectBase.IsRectEmpty, 'ptr', rc, 'int')
RectDispose(Obj) {
    if Obj.HasOwnProp('Ptr') {
        ObjRelease(Obj.Ptr)
        Obj.DeleteProp('Ptr')
    }
    if Obj.HasOwnProp('Buffer') {
        Obj.DeleteProp('Buffer')
    }
    Obj.DefineProp('Size', { Value: 0 })
    Obj.DefineProp('Ptr', { Value: 0 })
}
/**
 * @description - Calculates the optimal position to move one rectangle adjacent to another while
 * ensuring that the `Subject` rectangle stays within the monitor's work area. The properties
 * { L, T, R, B } of `Subject` are updated with the new values.
 *
 * @example
 * ; Assume I have Edge and VLC open
 * rcSub := WinRect(WinGetId("ahk_exe msedge.exe"))
 * rcTar := WinRect(WinGetId("ahk_exe vlc.exe"))
 * rcSub.MoveAdjacent(rcTar)
 * rcSub.Apply()
 * @
 *
 * @param {*} Subject - The object representing the rectangle that will be moved. This can be an
 * instance of `Rect` or any class that inherits from `Rect`, or any object with properties
 * { L, T, R, B }. Those four property values will be updated with the result of this function call.
 *
 * @param {*} [Target] - The object representing the rectangle that will be used as reference. This
 * can be an instance of `Rect` or any class that inherits from `Rect`, or any object with properties
 * { L, T, R, B }. If unset, the mouse's current position relative to the screen is used. To use
 * a point instead of a rectangle, set the properties "L" and "R" equivalent to one another, and
 * "T" and "B" equivalent to one another.
 *
 * @param {*} [ContainerRect] - If set, `ContainerRect` defines the boundaries which restrict
 * the area that the window is permitted to be moved within. The object must have poperties
 * { L, T, R, B } to be valid. If unset, the work area of the monitor with the greatest area of
 * intersection with `Target` is used.
 *
 * @param {String} [Dimension = "X"] - Either "X" or "Y", specifying if the window is to be moved
 * adjacent to `Target` on either the X or Y axis. If "X", `Subject` is moved to the left or right
 * of `Target`, and `Subject`'s vertical center is aligned with `Target`'s vertical center. If "Y",
 * `Subject` is moved to the top or bottom of `Target`, and `Subject`'s horizontal center is aligned
 * with `Target`'s horizontal center.
 *
 * @param {String} [Prefer = ""] - A character indicating a preferred side. If `Prefer` is an
 * empty string, the function will move the window to the side the has the greatest amount of
 * space between the monitor's border and `Target`. If `Prefer` is any of the following values,
 * the window will be moved to that side unless doing so would cause the the window to extend
 * outside of the monitor's work area.
 * - "L" - Prefers the left side.
 * - "T" - Prefers the top side.
 * - "R" - Prefers the right side.
 * - "B" - Prefes the bottom.
 *
 * @param {Number} [Padding = 0] - The amount of padding to leave between `Subject` and `Target`.
 *
 * @param {Integer} [InsufficientSpaceAction = 0] - Determines the action taken if there is
 * insufficient space to move the window adjacent to `Target` while also keeping the window
 * entirely within the monitor's work area. The function will always sacrifice some of the padding
 * if it will allow the window to stay within the monitor's work area. If the space is still
 * insufficient, the action can be one of the following:
 * - 0 : The function will not move the window.
 * - 1 : The function will move the window, allowing the window's area to extend into a non-visible
 *   region of the monitor.
 * - 2 : The function will move the window, keeping the window's area within the monitor's work
 *   area by allowing the window to overlap with `Target`.
 *
 * @returns {Integer} - If the insufficient space action was invoked, returns 1. Else, returns 0.
 */
RectMoveAdjacent(Subject, Target?, ContainerRect?, Dimension := 'X', Prefer := '', Padding := 0, InsufficientSpaceAction := 0) {
    Result := 0
    if IsSet(Target) {
        tarL := Target.L
        tarT := Target.T
        tarR := Target.R
        tarB := Target.B
    } else {
        mode := CoordMode('Mouse', 'Screen')
        MouseGetPos(&tarL, &tarT)
        tarR := tarL
        tarB := tarT
        CoordMode('Mouse', mode)
    }
    tarW := tarR - tarL
    tarH := tarB - tarT
    if IsSet(ContainerRect) {
        monL := ContainerRect.L
        monT := ContainerRect.T
        monR := ContainerRect.R
        monB := ContainerRect.B
        monW := monR - monL
        monH := monB - monT
    } else {
        buf := Buffer(16)
        NumPut('int', tarL, 'int', tarT, 'int', tarR, 'int', tarB, buf)
        Hmon := DllCall('MonitorFromRect', 'ptr', buf, 'uint', 0x00000002, 'ptr')
        mon := Buffer(40)
        NumPut('int', 40, mon)
        if !DllCall('GetMonitorInfo', 'ptr', Hmon, 'ptr', mon, 'int') {
            throw OSError()
        }
        monL := NumGet(mon, 20, 'int')
        monT := NumGet(mon, 24, 'int')
        monR := NumGet(mon, 28, 'int')
        monB := NumGet(mon, 32, 'int')
        monW := monR - monL
        monH := monB - monT
    }
    subL := Subject.L
    subT := Subject.T
    subR := Subject.R
    subB := Subject.B
    subW := subR - subL
    subH := subB - subT
    if Dimension = 'X' {
        if Prefer = 'L' {
            if tarL - subW - Padding >= monL {
                X := tarL - subW - Padding
            } else if tarL - subW >= monL {
                X := monL
            }
        } else if Prefer = 'R' {
            if tarR + subW + Padding <= monR {
                X := tarR + Padding
            } else if tarR + subW <= monR {
                X := monR - subW
            }
        } else if Prefer {
            throw _ValueError('Prefer', Prefer)
        }
        if !IsSet(X) {
            flag_nomove := false
            X := _Proc(subW, subL, subR, tarW, tarL, tarR, monW, monL, monR, Prefer = 'L' ? 1 : Prefer = 'R' ? -1 : 0)
            if flag_nomove {
                return Result
            }
        }
        Y := tarT + tarH / 2 - subH / 2
        if Y + subH > monB {
            Y := monB - subH
        } else if Y < monT {
            Y := monT
        }
    } else if Dimension = 'Y' {
        if Prefer = 'T' {
            if tarT - subH - Padding >= monT {
                Y := tarT - subH - Padding
            } else if tarT - subH >= monT {
                Y := monT
            }
        } else if Prefer = 'B' {
            if tarB + subH + Padding <= monB {
                Y := tarB + Padding
            } else if tarB + subH <= monB {
                Y := monB - subH
            }
        } else if Prefer {
            throw _ValueError('Prefer', Prefer)
        }
        if !IsSet(Y) {
            flag_nomove := false
            Y := _Proc(subH, subT, subB, tarH, tarT, tarB, monH, monT, monB, Prefer = 'T' ? 1 : Prefer = 'B' ? -1 : 0)
            if flag_nomove {
                return Result
            }
        }
        X := tarL + tarW / 2 - subW / 2
        if X + subW > monR {
            X := monR - subW
        } else if X < monL {
            X := monL
        }
    } else {
        throw _ValueError('Dimension', Dimension)
    }
    Subject.L := X
    Subject.T := Y
    Subject.R := X + subW
    Subject.B := Y + subH

    return Result

    _Proc(SubLen, SubMainSide, SubAltSide, TarLen, TarMainSide, TarAltSide, MonLen, MonMainSide, MonAltSide, Prefer) {
        if TarMainSide - MonMainSide > MonAltSide - TarAltSide {
            if TarMainSide - SubLen - Padding >= MonMainSide {
                return TarMainSide - SubLen - Padding
            } else if TarMainSide - SubLen >= MonMainSide {
                return MonMainSide + TarMainSide - SubLen
            } else {
                Result := 1
                switch InsufficientSpaceAction, 0 {
                    case 0: flag_nomove := true
                    case 1: return TarMainSide - SubLen
                    case 2: return MonMainSide
                    default: throw _ValueError('InsufficientSpaceAction', InsufficientSpaceAction)
                }
            }
        } else if TarAltSide + SubLen + Padding <= MonAltSide {
            return TarAltSide + Padding
        } else if TarAltSide + SubLen <= MonAltSide {
            return MonAltSide - TarAltSide + SubLen
        } else {
            Result := 1
            switch InsufficientSpaceAction, 0 {
                case 0: flag_nomove := true
                case 1: return TarAltSide
                case 2: return MonAltSide - SubLen
                default: throw _ValueError('InsufficientSpaceAction', InsufficientSpaceAction)
            }
        }
    }
    _ValueError(name, Value) {
        if IsObject(Value) {
            return TypeError('Invalid type passed to ``' name '``.', -2)
        } else {
            return ValueError('Unexpected value passed to ``' name '``.', -2, Value)
        }
    }
}
RectOffset(rc, dx, dy) => DllCall(RectBase.OffsetRect, 'ptr', rc, 'int', dx, 'int', dy, 'int')
RectPtIn(rc, pt) => DllCall(RectBase.PtInRect, 'ptr', rc, 'ptr', pt, 'int')
RectSet(rc, X?, Y?, W?, H?) {
    if IsSet(X) {
        rc.L := X
    }
    if IsSet(Y) {
        rc.T := Y
    }
    if IsSet(W) {
        rc.R := rc.L + W
    }
    if IsSet(H) {
        rc.B := rc.T + H
    }
}
RectSetCoordinate(Offset, rc, Value) => NumPut('int', Value, rc.Ptr, Offset)
RectSetLength(Offset, rc, Value) => NumPut('int', NumGet(rc, Offset, 'int') + Value, rc, 8 + Offset)
RectSetThreadDpiAwareness__Call(Obj, Name, Params) {
    Split := StrSplit(Name, '_')
    if Obj.HasMethod(Split[1]) && Split[2] = 'S' {
        DllCall(RectBase.SetThreadDpiAwarenessContext, 'ptr', HasProp(Obj, 'DpiAwarenessContext') ? Obj.DpiAwarenessContext : DPI_AWARENESS_CONTEXT_DEFAULT ?? -4, 'ptr')
        if Params.Length {
            return Obj.%Split[1]%(Params*)
        } else {
            return Obj.%Split[1]%()
        }
    } else {
        throw PropertyError('Property not found.', -1, Name)
    }
}
RectSubtract(rc1, rc2) {
    rc := Rect()
    DllCall(RectBase.SubtractRect, 'ptr', rc, 'ptr', rc1, 'ptr', rc2, 'int')
    return rc
}
/**
 * Calls `ScreenToClient` for the the rectangle.
 * @param {Integer} Hwnd - The handle to the window to which the rectangle's dimensions
 * will be made relative.
 * @param {Boolean} [InPlace = false] - If true, the function modifies the object's properties.
 * If false, the function creates a new object.
 * @returns {Rect}
 */
RectToClient(rc, Hwnd, InPlace := false) {
    if !InPlace {
        rc := rc.Clone()
    }
    if !DllCall(RectBase.ScreenToClient, 'ptr', Hwnd, 'ptr', rc, 'int') {
        throw OSError()
    }
    if !DllCall(RectBase.ScreenToClient, 'ptr', Hwnd, 'ptr', rc.Ptr + 8, 'int') {
        throw OSError()
    }
    return rc
}
/**
 * Calls `ClientToScreen` for the the rectangle.
 * @param {Integer} Hwnd - The handle to the window to which the rectangle's dimensions
 * are currently relative.
 * @param {Boolean} [InPlace = false] - If true, the function modifies the object's properties.
 * If false, the function creates a new object.
 * @returns {Rect}
 */
RectToScreen(rc, Hwnd, InPlace := false) {
    if !InPlace {
        rc := rc.Clone()
    }
    if !DllCall(RectBase.ClientToScreen, 'ptr', Hwnd, 'ptr', rc.ptr, 'int') {
        throw OSError()
    }
    if !DllCall(RectBase.ClientToScreen, 'ptr', Hwnd, 'ptr', rc.ptr + 8, 'int') {
        throw OSError()
    }
    return rc
}
RectToString(rc, DimensionLen := '-6') {
    return (
        'TL: ' Format('( {}, {} )', rc.L, rc.T)
        '`r`nBR: ' Format('( {}, {} )', rc.R, rc.B)
        '`r`nW: ' Format('{:' DimensionLen '}', rc.W) '  H: ' Format('{:' DimensionLen '}', rc.H)
    )
}
RectToStringDeconstructed(rc, DimensionLen := '-6') {
    return {
        TL: Format('( {}, {} )', rc.L, rc.T)
      , BR: Format('( {}, {} )', rc.R, rc.B)
      , W: Format('{:' DimensionLen '}', rc.W)
      , H: Format('{:' DimensionLen '}', rc.H)
    }
}
/**
 * @returns {Rect} - If the specified structure contains a nonempty rectangle, a new `Rect` is created
 * and retured. If the specified structure does not contain a nonempty rectangle, returns an empty
 * string.
 */
RectUnion(rc1, rc2) {
    rc := Rect()
    if DllCall(RectBase.UnionRect, 'ptr', rc, 'ptr', rc1, 'ptr', rc2, 'int') {
        return rc
    }
}
SetCaretPos(X, Y) {
    return DllCall(RectBase.SetCaretPos, 'int', X, 'int', Y, 'int')
}

;@endregion


;@region Window32 funcs

/**
 * @description - Input the desired client area and `AdjustWindowRectEx` will update the object
 * on the property `Rect` to the position and size that will accommodate the client area. This
 * does not update the window's display; call `Window32Obj.Rect.Apply()`
 */
Window32AdjustRectEx(win, X?, Y?, W?, H?, HasMenuBar := false) {
    rc := win.Rect
    if IsSet(X) {
        rc.X := X
    }
    if IsSet(Y) {
        rc.Y := Y
    }
    if IsSet(W) {
        rc.R := rc.X + W
    }
    if IsSet(H) {
        rc.B := rc.T + H
    }
    if !DllCall(RectBase.AdjustWindowRectEx, 'ptr', rc, 'uint', win.Style, 'int', HasMenuBar, 'uint', win.ExStyle, 'int') {
        throw OSError()
    }
}

Window32BringToTop(win) {
    return DllCall(RectBase.BringWindowToTop, 'ptr', IsObject(win) ? win.Hwnd : win, 'int')
}

Window32CallbackFromDesktop(*) {
    if hwnd := DllCall(RectBase.GetDesktopWindow, 'ptr') {
        return hwnd
    }
}

Window32CallbackFromForeground(*) {
    return DllCall(RectBase.GetForegroundWindow, 'ptr')
}

/**
 * @description - To use this as a callback with `Window32.Prototype.SetCallback`, you must
 * define it as a `BoundFunc` defining the "Cmd" value.
 * @example
 *  hwnd := DllCall(RectBase.GetDesktopWindow, 'ptr')
 *  win := Window32(hwnd)
 *  win.SetCallback(Window32CallbackFromNext.Bind(3))
 *  win()
 * @
 */
Window32CallbackFromNext(Cmd, win) {
    if hwnd := DllCall(RectBase.GetNextWindow, 'ptr', win.Hwnd, 'uint', Cmd, 'ptr') {
        return hwnd
    }
}

Window32CallbackFromParent(win) {
    if hwnd := DllCall(RectBase.GetParent, 'ptr', win.Hwnd, 'ptr') {
        return hwnd
    }
}

Window32CallbackFromShell(*) {
    return DllCall(RectBase.GetShellWindow, 'ptr')
}

Window32CallbackFromTop(win) {
    return DllCall(RectBase.GetTopWindow, 'ptr', win.Hwnd, 'ptr')
}

/**
 * @description - `Window32ChildFromCursor` returns the child window underneath the cursor. To use
 * this function, you must first call the method "MakePoint".
 * @example
 *  win := Window32()
 *  win.MakePoint(2)
 *  ; Now we can get the child window under the cursor like this:
 *  childHwnd := win.ChildFromCursor()
 * @
 *
 * Note that calling the method "ChildFromCursor" also updates the property "Hwnd" with the handle to
 * the window under the cursor.
 */
Window32ChildFromCursor(win) {
    win.Point.Call()
    win.Hwnd := DllCall(RectBase.WindowFromPoint, 'int', win.Point.Value, 'ptr')
    return DllCall(RectBase.ChildWindowFromPoint, 'ptr', win.Hwnd, 'int', win.Point.Value, 'ptr')
}

/**
 * @description - Similar to {@link Window32ChildFromCursor}, except in this case we can also pass
 * a value to the parameter `Flag`, described here: {@link Window32ChildFromPointEx}.
 */
Window32ChildFromCursorEx(win, Flag := 0) {
    win.Point.Call()
    win.Hwnd := DllCall(RectBase.WindowFromPoint, 'int', win.Point.Value, 'ptr')
    return DllCall(RectBase.ChildWindowFromPointEx, 'ptr', win.Hwnd, 'int', win.Point.Value, 'int', Flag, 'ptr')
}

Window32ChildFromPoint(win, X, Y) {
    return DllCall(RectBase.ChildWindowFromPoint, 'ptr', IsObject(win) ? win.Hwnd : win, 'int', (X & 0xFFFFFFFF) | (Y << 32), 'ptr')
}

/**
 * @param {Integer} [flag = 0] -
 * - CWP_ALL - 0x0000 : Does not skip any child windows
 * - CWP_SKIPDISABLED - 0x0002 : Skips disabled child windows
 * - CWP_SKIPINVISIBLE - 0x0001 : Skips invisible child windows
 * - CWP_SKIPTRANSPARENT - 0x0004 : Skips transparent child windows
 */
Window32ChildFromPointEx(win, X, Y, Flag := 0) {
    return DllCall(RectBase.ChildWindowFromPointEx, 'ptr', IsObject(win) ? win.Hwnd : win, 'int', (X & 0xFFFFFFFF) | (Y << 32), 'int', Flag, 'ptr')
}

Window32Dispose(win) {
    for prop in ['Rect', 'ClientRect'] {
        if win.HasOwnProp(prop) {
            if win.%prop%.HasMethod('Dispose') {
                win.%prop%.Dispose()
            }
            win.DeleteProp(prop)
        }
    }
    RectDispose(win)
}

Window32EnumChildWindows(win, Callback, lParam := 0) {
    cb := CallbackCreate(Callback)
    result := DllCall(RectBase.EnumChildWindows, 'ptr', IsObject(win) ? win.Hwnd : win, 'ptr', cb, 'uint', lParam, 'int')
    CallbackFree(cb)
    return result
}

/**
 * @description - Gets the bounding rectangle of all child windows of a given window.
 * @param {Integer} Hwnd - The handle to the parent window.
 * @returns {Rect} - The bounding rectangle of all child windows, specifically the smallest
 * rectangle that contains all child windows.
 */
Window32GetChildBoundingRect(win) {
    rects := [Rect(), Rect(), Rect()]
    DllCall(RectBase.EnumChildWindows, 'ptr', IsObject(win) ? win.Hwnd : win, 'ptr', cb := CallbackCreate(_EnumChildWindowsProc, 'fast',  1), 'int', 0, 'int')
    CallbackFree(cb)
    return rects[1]

    _EnumChildWindowsProc(hwnd) {
        DllCall(RectBase.GetWindowRect, 'ptr', Hwnd, 'ptr', rects[3], 'int')
        DllCall(RectBase.UnionRect, 'ptr', rects[2], 'ptr', rects[3], 'ptr', rects[1], 'int')
        rects.Push(rects.RemoveAt(1))
        return 1
    }
}

Window32GetClientRect(win) {
    return WinRect(IsObject(win) ? win.Hwnd : win, true)
}

Window32GetDpi(win) {
    return DllCall(RectBase.GetDpiForWindow, 'ptr', IsObject(win) ? win.Hwnd : win, 'int')
}

Window32GetExStyle(win) {
    style := win.ExStyle
    result := []
    result.Capacity := Window32.WindowExStyles.Count
    for k, v in Window32.WindowExStyles {
        if style & v {
            result.Push(k)
        }
    }
    result.Capacity := result.Length
    return result
}

Window32GetMonitor(win) {
    return DllCall(RectBase.MonitorFromWindow, 'ptr', IsObject(win) ? win.Hwnd : win, 'int', 0, 'ptr')
}

Window32GetStyle(win) {
    style := win.Style
    result := []
    result.Capacity := Window32.WindowStyles.Count
    for k, v in Window32.WindowStyles {
        if style & v {
            result.Push(k)
        }
    }
    result.Capacity := result.Length
    return result
}

/**
 * @param {String|Integer} Id - Either the symbol as string (e.g. "WS_EX_WINDOWEDGE") or the integer
 * value (e.g. "0x00000100").
 */
Window32HasExStyle(win, Id) {
    return win.ExStyle & (IsNumber(Id) ? Id : Window32.WindowExStyles.Get(Id))
}

/**
 * @param {String|Integer} Id - Either the symbol as string (e.g. "WS_CAPTION") or the integer value
 * (e.g. "0x00C00000").
 */
Window32HasStyle(win, Id) {
    return win.Style & (IsNumber(Id) ? Id : Window32.WindowStyles.Get(Id))
}

Window32IsChild(win, HwndChild) {
    return DllCall(RectBase.IsChild, 'ptr', IsObject(win) ? win.Hwnd : win, 'ptr', IsObject(HwndChild) ? HwndChild.Hwnd : HwndChild, 'int')
}

Window32IsParent(win, HwndParent) {
    return DllCall(RectBase.IsChild, 'ptr', HwndParent, 'ptr', IsObject(win) ? win.Hwnd : win, 'int')
}

Window32IsVisible(wrc) {
    return DllCall(RectBase.IsWindowVisible, 'ptr', IsObject(wrc) ? wrc.Hwnd : wrc, 'int')
}

/**
 * Input the dimensions of the desired client area, and the window is moved to accommodate that
 * area.
 */
Window32MoveClient(win, X := 0, Y := 0, W := 0, H := 0, InsertAfter := 0, Flags := 0) {
    win := win.Rect
    win.X := X
    win.Y := Y
    win.W := W
    win.H := H
    if !DllCall(RectBase.AdjustWindowRectEx, 'ptr', win, 'uint', win.Style, 'int', win.MenuBar ? 1 : 0, 'uint', win.ExStyle, 'int') {
        throw OSError()
    }
    if !DllCall(RectBase.SetWindowPos, 'ptr', win.Hwnd, 'ptr', InsertAfter, 'int', X, 'int', Y, 'int', W, 'int', H, 'uint', Flags, 'int') {
        throw OSError()
    }
    ; Update the AHK Rect object's property values.
    if !DllCall(RectBase.GetWindowRect, 'ptr', win.Hwnd, 'ptr', win, 'int') {
        throw OSError()
    }
}

Window32RealChildFromPoint(win, X, Y) {
    return DllCall(RectBase.RealChildWindowFromPoint, 'ptr', IsObject(win) ? win.Hwnd : win, 'int', (X & 0xFFFFFFFF) | (Y << 32), 'ptr')
}

/**
 * @description - See {@link Window32ChildFromCursor}.
 */
Window32RealChildFromCursor(win) {
    win.Point.Call()
    win.Hwnd := DllCall(RectBase.WindowFromPoint, 'int', win.Point.Value, 'ptr')
    return DllCall(RectBase.RealChildWindowFromPoint, 'ptr', IsObject(win) ? win.Hwnd : win, 'int', win.Point.Value, 'ptr')
}

Window32SetActive(win) {
    return DllCall(RectBase.SetActiveWindow, 'ptr', IsObject(win) ? win.Hwnd : win, 'int')
}

Window32SetForeground(win) {
    return DllCall(RectBase.SetForegroundWindow, 'ptr', IsObject(win) ? win.Hwnd : win, 'int')
}

Window32SetParent(win, HwndNewParent := 0) {
    return DllCall(RectBase.SetParent, 'ptr', IsObject(win) ? win.Hwnd : win, 'ptr', IsObject(HwndNewParent) ? HwndNewParent.Hwnd : HwndNewParent, 'ptr')
}

Window32SetPosKeepAspectRatio(win, Width, Height, AspectRatio?) {
    if !IsSet(AspectRatio) {
        AspectRatio := win.W / win.H
    }
    WidthFromHeight := Height / AspectRatio
    HeightFromWidth := Width * AspectRatio
    if WidthFromHeight > Width {
        win.H := HeightFromWidth
        win.W := Width
    } else {
        win.W := WidthFromHeight
        win.H := Height
    }
}

/**
 * @description - Shows the window.
 * @param {Integer} [Flag = 0] - One of the following.
 * - SW_HIDE - 0 - Hides the window and activates another window.
 * - SW_SHOWNORMAL / SW_NORMAL - 1 - Activates and displays a window. If the window is
 *   minimized, maximized, or arranged, the system restores it to its original size and position.
 *   An application should specify this flag when displaying the window for the first time.
 * - SW_SHOWMINIMIZED - 2 - Activates the window and displays it as a minimized window.
 * - SW_SHOWMAXIMIZED / SW_MAXIMIZE - 3 - Activates the window and displays it as a maximized
 *   window.
 * - SW_SHOWNOACTIVATE - 4 - Displays a window in its most recent size and position. This value
 *   is similar to SW_SHOWNORMAL, except that the window is not activated.
 * - SW_SHOW - 5 - Activates the window and displays it in its current size and position.
 * - SW_MINIMIZE - 6 - Minimizes the specified window and activates the next top-level window in
 *   the Z order.
 * - SW_SHOWMINNOACTIVE - 7 - Displays the window as a minimized window. This value is similar
 *   to SW_SHOWMINIMIZED, except the window is not activated.
 * - SW_SHOWNA - 8 - Displays the window in its current size and position. This value is similar
 *   to SW_SHOW, except that the window is not activated.
 * - SW_RESTORE - 9 - Activates and displays the window. If the window is minimized, maximized,
 *   or arranged, the system restores it to its original size and position. An application should
 *   specify this flag when restoring a minimized window.
 * - SW_SHOWDEFAULT - 10 - Sets the show state based on the SW_ value specified
 *   in the structure passed to the function by the program that started the application.
 * - SW_FORCEMINIMIZE - 11 - Minimizes a window, even if the thread that owns the window is not
 *   responding. This flag should only be used when minimizing windows from a different thread.
 * @returns {Boolean} - If the window was previously visible, the return value is nonzero. If
 * the window was previously hidden, the return value is zero.
 */
Window32Show(win, Flag := 0) {
    return DllCall(RectBase.ShowWindow, 'ptr', IsObject(win) ? win.Hwnd : win, 'uint', Flag, 'int')
}

;@endregion


;@region WinFrom funcs

WinFromDesktop() {
    return DllCall(RectBase.GetDesktopWindow, 'ptr')
}

WinFromForeground() {
    return DllCall(RectBase.GetForegroundWindow, 'ptr')
}

WinFromCursor() {
    pt := Point()
    if !DllCall(RectBase.GetCursorPos, 'ptr', pt, 'int') {
        throw OSError()
    }
    return DllCall(RectBase.WindowFromPoint, 'int', pt.Value, 'ptr')
}

WinFromParent(Hwnd) {
    return DllCall(RectBase.GetParent, 'ptr', IsObject(Hwnd) ? Hwnd.Hwnd : Hwnd, 'ptr')
}

WinFromPoint(X, Y) {
    return DllCall(RectBase.WindowFromPoint, 'int', (X & 0xFFFFFFFF) | (Y << 32), 'ptr')
}

WinFromShell() {
    return DllCall(RectBase.GetShellWindow, 'ptr')
}

WinFromTop(Hwnd := 0) {
    return DllCall(RectBase.GetTopWindow, 'ptr', IsObject(Hwnd) ? Hwnd.Hwnd : Hwnd, 'ptr')
}

/**
 * @param Cmd -
 * - GW_CHILD - 5 - The retrieved handle identifies the child window at the top of the Z order,
 *  if the specified window is a parent window; otherwise, the retrieved handle is NULL. The
 *  function examines only child windows of the specified window. It does not examine descendant
 *  windows.
 *
 * - GW_ENABLEDPOPUP - 6 - The retrieved handle identifies the enabled popup window owned by the
 *  specified window (the search uses the first such window found using GW_HwndNEXT); otherwise,
 *  if there are no enabled popup windows, the retrieved handle is that of the specified window.
 *
 * - GW_HwndFIRST - 0 - The retrieved handle identifies the window of the same type that is highest
 *  in the Z order. If the specified window is a topmost window, the handle identifies a topmost
 *  window. If the specified window is a top-level window, the handle identifies a top-level
 *  window. If the specified window is a child window, the handle identifies a sibling window.
 *
 * - GW_HwndLAST - 1 - The retrieved handle identifies the window of the same type that is lowest
 *  in the Z order. If the specified window is a topmost window, the handle identifies a topmost
 *  window. If the specified window is a top-level window, the handle identifies a top-level window.
 *  If the specified window is a child window, the handle identifies a sibling window.
 *
 * - GW_HwndNEXT - 2 - The retrieved handle identifies the window below the specified window in
 *  the Z order. If the specified window is a topmost window, the handle identifies a topmost
 *  window. If the specified window is a top-level window, the handle identifies a top-level
 *  window. If the specified window is a child window, the handle identifies a sibling window.
 *
 * - GW_HwndPREV - 3 - The retrieved handle identifies the window above the specified window in
 *  the Z order. If the specified window is a topmost window, the handle identifies a topmost
 *  window. If the specified window is a top-level window, the handle identifies a top-level
 *  window. If the specified window is a child window, the handle identifies a sibling window.
 *
 * - GW_OWNER - 4 - The retrieved handle identifies the specified window's owner window, if any.
 *  For more information, see Owned Windows.
 */
WinGet(Hwnd, Cmd) {
    return DllCall(RectBase.GetWindow, 'ptr', IsObject(Hwnd) ? Hwnd.Hwnd : Hwnd, 'uint', Cmd, 'ptr')
}

;@endregion


;@region WinRect funcs

WinRectApply(wrc, InsertAfter := 0, Flags := 0) {
    return DllCall(WinRect.SetWindowPos, 'ptr', wrc.Hwnd, 'ptr', InsertAfter, 'int', wrc.L, 'int', wrc.T, 'int', wrc.W, 'int', wrc.H, 'uint', Flags, 'int')
}

WinRectGetPos(wrc, &X?, &Y?, &W?, &H?) {
    WinRectUpdate(wrc)
    X := wrc.L
    Y := wrc.T
    W := wrc.R - wrc.L
    H := wrc.B - wrc.T
}

WinRectMapPoints(wrc1, wrc2, points) {
    buf := Buffer(points.Length * 4)
    for coord in points {
        NumPut('int', coord, buf, A_Index * 4 - 4)
    }
    result := DllCall(RectBase.MapWindowPoints, 'ptr', IsObject(wrc1) ? wrc1.Hwnd : wrc1, 'ptr', IsObject(wrc2) ? wrc2.Hwnd : wrc2, 'ptr', buf, 'uint', points.Length / 2)
    loop points.Length {
        points[A_Index] := NumGet(buf, A_Index * 4 - 4, 'int')
    }
    return result
}

/**
 * @param {Integer} [X] - The new x-coordinate of the window.
 * @param {Integer} [Y] - The new y-coordinate of the window.
 * @param {Integer} [W] - The new Width of the window.
 * @param {Integer} [H] - The new Height of the window.
 * @param {Integer} [InsertAfter = 0] - Either the handle of another window to insert this
 * window after, or one of the following:
 * - HWND_BOTTOM - (HWND)1 : Places the window at the bottom of the Z order. If the <i>hWnd</i>
 *   parameter identifies a topmost window, the window loses its topmost status and is placed at
 *   the bottom of all other windows.
 * - HWND_NOTOPMOST - (HWND)-2 : Places the window above all non-topmost windows (that is, behind
 *   all topmost windows). This flag has no effect if the window is already a non-topmost window.
 * - HWND_TOP - (HWND)0 : Places the window at the top of the Z order.
 * - HWND_TOPMOST - (HWND)-1 : Places the window above all non-topmost windows. The window
 *   maintains its topmost position even when it is deactivated.
 * @param {Integer} [Flags = 0] - A combination of the following. Use "|" to combine, e.g.
 * `Flags := 0x4000 | 0x0020 | 0x0010`.
 * - SWP_ASYNCWINDOWPOS - 0x4000 : If the calling thread and the thread that owns the window are
 *   attached to different input queues, the system posts the request to the thread that owns the
 *   window. This prevents the calling thread from blocking its execution while other threads
 *   process the request.
 * - SWP_DEFERERASE - 0x2000 : Prevents generation of the WM_SYNCPAINT message.
 * - SWP_DRAWFRAME - 0x0020 : Draws a frame (defined in the window's class description) around the
 *   window.
 * - SWP_FRAMECHANGED - 0x0020 : Applies new frame styles set using the SetWindowLong
 *   function. Sends a WM_NCCALCSIZE message to the window, even if the window's size is not being
 *   changed. If this flag is not specified, <b>WM_NCCALCSIZE</b> is sent only when the window's
 *   size is being changed.
 * - SWP_HIDEWINDOW - 0x0080 : Hides the window.
 * - SWP_NOACTIVATE - 0x0010 : Does not activate the window. If this flag is not set, the window
 *   is activated and moved to the top of either the topmost or non-topmost group (depending on the
 *   setting of the <i>hWndInsertAfter</i> parameter).
 * - SWP_NOCOPYBITS - 0x0100 : Discards the entire contents of the client area. If this flag is
 *   not specified, the valid contents of the client area are saved and copied back into the client
 *   area after the window is sized or repositioned.
 * - SWP_NOMOVE - 0x0002 : Retains the current position (ignores <i>X</i> and <i>Y</i>
 *   parameters).
 * - SWP_NOOWNERZORDER - 0x0200 : Does not change the owner window's position in the Z order.
 * - SWP_NOREDRAW - 0x0008 : Does not redraw changes. If this flag is set, no repainting of any
 *   kind occurs. This applies to the client area, the nonclient area (including the title bar and
 *   scroll bars), and any part of the parent window uncovered as a result of the window being
 *   moved. When this flag is set, the application must explicitly invalidate or redraw any parts
 *   of the window and parent window that need redrawing.
 * - SWP_NOREPOSITION - 0x0200 : Same as the <b>SWP_NOOWNERZORDER</b> flag.
 * - SWP_NOSENDCHANGING - 0x0400 : Prevents the window from receiving the WM_WINDOWPOSCHANGING
 *   message.
 * - SWP_NOSIZE - 0x0001 : Retains the current size (ignores the <i>cx</i> and <i>cy</i>
 *   parameters).
 * - SWP_NOZORDER - 0x0004 : Retains the current Z order (ignores the <i>hWndInsertAfter</i>
 *   parameter).
 * - SWP_SHOWWINDOW - 0x0040 : Displays the window.
 */
WinRectMove(wrc, X := 0, Y := 0, W := 0, H := 0, InsertAfter := 0, Flags := 0) {
    if !DllCall(WinRect.SetWindowPos, 'ptr', wrc.Hwnd, 'ptr', InsertAfter, 'int', X, 'int', Y, 'int', W, 'int', H, 'uint', Flags, 'int') {
        throw OSError()
    }
    ; Update the AHK Rect object's property values.
    if !DllCall(WinRect.GetWindowRect, 'ptr', wrc.Hwnd, 'ptr', wrc, 'int') {
        throw OSError()
    }
}

WinRectUpdate(wrc) {
    if IsObject(wrc) && HasProp(wrc, 'Flag') {
        switch wrc.Flag, 0 {
            case 0:
                DllCall(RectBase.GetWindowRect, 'ptr', wrc.Hwnd, 'ptr', wrc, 'int')
            case 1:
                DllCall(RectBase.GetClientRect, 'ptr', wrc.Hwnd, 'ptr', wrc, 'int')
            case 2:
                if hresult := DllCall(RectBase.Dwmapi_DwmGetWindowAttribute, 'ptr', wrc.Hwnd, 'uint', 9, 'ptr', wrc, 'uint', 16, 'uint') {
                    throw oserror('DwmGetWindowAttribute failed.', -1, hresult)
                }
        }
    } else {
        DllCall(RectBase.GetWindowRect, 'ptr', wrc.Hwnd, 'ptr', wrc, 'int')
    }
}

;@endregion


;@region Misc


/**
 * @description - Reorders the objects in an array according to the input options.
 * @example
 *  List := [
 *      { L: 100, T: 100, Name: 1 }
 *    , { L: 100, T: 150, Name: 2 }
 *    , { L: 200, T: 100, Name: 3 }
 *    , { L: 200, T: 150, Name: 4 }
 *  ]
 *  Rect.Order(List, L2R := true, T2B := true, 'H')
 *  OutputDebug(_GetOrder()) ; 1 2 3 4
 *  Rect.Order(List, L2R := true, T2B := true, 'V')
 *  OutputDebug(_GetOrder()) ; 1 3 2 4
 *  Rect.Order(List, L2R := false, T2B := true, 'H')
 *  OutputDebug(_GetOrder()) ; 3 4 1 2
 *  Rect.Order(List, L2R := false, T2B := false, 'H')
 *  OutputDebug(_GetOrder()) ; 4 3 2 1
 *
 *  _GetOrder() {
 *      for item in List {
 *          Str .= item.Name ' '
 *      }
 *      return Trim(Str, ' ')
 *  }
 * @
 * @param {Array} List - The array containing the objects to be ordered.
 * @param {String} [Primary='X'] - Determines which axis is primarily considered when ordering
 * the objects. When comparing two objects, if their positions along the Primary axis are
 * equal, then the alternate axis is compared and used to break the tie. Otherwise, the alternate
 * axis is ignored for that pair.
 * - X: Check horizontal first.
 * - Y: Check vertical first.
 * @param {Boolean} [LeftToRight=true] - If true, the objects are ordered in ascending order
 * along the X axis when the X axis is compared.
 * @param {Boolean} [TopToBottom=true] - If true, the objects are ordered in ascending order
 * along the Y axis when the Y axis is compared.
 */
OrderRects(List, Primary := 'X', LeftToRight := true, TopToBottom := true) {
    ConditionH := LeftToRight ? (a, b) => a.L < b.L : (a, b) => a.L > b.L
    ConditionV := TopToBottom ? (a, b) => a.T < b.T : (a, b) => a.T > b.T
    if Primary = 'X' {
        _InsertionSort(List, _ConditionFnH)
    } else if Primary = 'Y' {
        _InsertionSort(List, _ConditionFnV)
    } else {
        throw ValueError('Unexpected ``Primary`` value.', -1, Primary)
    }

    return

    _InsertionSort(Arr, CompareFn) {
        i := 1
        loop Arr.Length - 1 {
            Current := Arr[++i]
            j := i - 1
            loop j {
                if CompareFn(Arr[j], Current) < 0
                    break
                Arr[j + 1] := Arr[j--]
            }
            Arr[j + 1] := Current
        }
    }
    _ConditionFnH(a, b) {
        if a.L == b.L {
            if ConditionV(a, b) {
                return -1
            }
        } else if ConditionH(a, b) {
            return -1
        }
        return 1
    }
    _ConditionFnV(a, b) {
        if a.T == b.T {
            if ConditionH(a, b) {
                return -1
            }
        } else if ConditionV(a, b) {
            return -1
        }
        return 1
    }
}

;@endregion


MetaSetThreadDpiAwareness(Obj, Name, Params) {
    Split := StrSplit(Name, '_')
    if Split.Length == 2 && Obj.HasMethod(Split[1]) && SubStr(Split[2], 1, 1) = 'S' {
        if StrLen(Split[2]) == 2 {
            DllCall('SetThreadDpiAwarenessContext', 'ptr', -SubStr(Split[2], 2, 1), 'ptr')
        } else {
            DllCall('SetThreadDpiAwarenessContext', 'ptr', HasProp(Obj, 'DpiAwarenessContext') ? Obj.DpiAwarenessContext : DPI_AWARENESS_CONTEXT_DEFAULT ?? -4, 'ptr')
        }
        if Params.Length {
            return Obj.%Split[1]%(Params*)
        } else {
            return Obj.%Split[1]%()
        }
    } else {
        throw PropertyError('Property not found.', -1, Name)
    }
}

class PopupWindow extends Gui {
    static __New() {
        this.DeleteProp('__New')
        proto := this.Prototype
        proto.__Duration :=
        proto.Padding :=
        proto.OffsetX :=
        proto.OffsetY :=
        proto.Priority := 0
        proto.__MarginL :=
        proto.__MarginT :=
        proto.__MarginR :=
        proto.__MarginB := 3
        proto.HwndCtrl :=
        proto.ContainerRect :=
        proto.Dimension :=
        proto.Prefer :=
        proto.WrapTextOptions :=
        proto.__Width := ''
        proto.InsufficientSpaceAction := 2
    }
    /**
     * @description - {@link PopupWindow} is an alternative to the native
     * {@link https://www.autohotkey.com/docs/v2/lib/ToolTip.htm ToolTip}. ToolTip uses the Win32
     * {@link https://learn.microsoft.com/en-us/windows/win32/controls/tooltip-control-reference tooltip API};
     * {@link PopupWindow} is just a gui with a text control.
     *
     * {@link PopupWindow} is designed for the following conveniences:
     * - {@link PopupWindow} has built-in text wrapping functionality. If you set `Options.Width` (or
     *   set {@link PopupWindow#Width}), that becomes the maximum width of the window. The text will
     *   be processed through {@link PopupWindow_WrapText}, which, by default, breaks the lines at a
     *   whitespace character or a hyphen. You can modify this behavior by setting
     *   `Options.WrapTextOptions` or {@link PopupWindow#WrapTextOptions}.
     * - {@link PopupWindow} automatically adjusts the text control's dimensions and the window's
     *   dimensions to fit the text content. Use the "Margin" options to control the margins.
     * - Method {@link PopupWindow.Prototype.ShowByMouse} automatically calculates the optimal position
     *   to display the window by the mouse pointer. By default, ShowByMouse will ensure that the window
     *   is within the monitor's work area. You can customize the behavior with the following. See
     *   {@link PopupWindow_MoveAdjacent} for details.
     *   - `Options.ContainerRect` / {@link PopupWindow#ContainerRect}
     *   - `Options.Dimension` / {@link PopupWindow#Dimension}
     *   - `Options.Prefer` / {@link PopupWindow#Prefer}
     *   - `Options.Padding` / {@link PopupWindow#Padding}
     *   - `Options.InsufficientSpaceAction` / {@link PopupWindow#InsufficientSpaceAction}
     * - {@link PopupWindow} has a built-in display timer. Set `Options.Duration` or
     *   {@link PopupWindow#Duration}, and the next tim your code calls
     *   {@link PopupWindow.Prototype.Show} or {@link PopupWindow.Prototype.ShowByMouse}, the timer will
     *   be invoked and the window will auto-hide after the duration.
     * @class
     *
     * @param {String} [Text] - The initial text to display in the window. This can be changed by
     * calling {@link PopupWindow.Prototype.SetText}.
     *
     * @param {Object} [Options] - An object with zero or more options as property : value pairs.
     *
     * @param {Integer|String} [Options.BackColor] - The
     * {@link https://www.autohotkey.com/docs/v2/lib/Gui.htm#BackColor background color}.
     *
     * @param {Buffer|Object} [Options.ContainerRect] - See {@link PopupWindow_MoveAdjacent~ContainerRect}.
     *
     * @param {Boolean} [Options.DeferShow = false] - If set and true, the window is not immediately
     * shown. Your code must call either {@link PopupWindow.Prototype.Show} or
     * {@link PopupWindow.Prototype.ShowByMouse}.
     *
     * @param {String} [Options.Dimension] - See {@link PopupWindow_MoveAdjacent~ContainerRect}.
     *
     * @param {Integer} [Options.Duration = 0] - The duration, in milliseconds, that the window will
     * be displayed when calling {@link PopupWindow.Prototype.Show} and {@link PopupWindow.Prototype.ShowByMouse}.
     * If `0`, the window is displayed indefinitely.
     *
     * @param {*} [Options.EventHandler] - The value to pass to the `EventObj` parameter of
     * {@link https://www.autohotkey.com/docs/v2/lib/Gui.htm#Call Gui.Call}.
     *
     * @param {String} [Options.FaceName = "Segoe Ui"] - `Options.FaceName` is passed to the `FontName`
     * parameter of {@link https://www.autohotkey.com/docs/v2/lib/Gui.htm#SetFont Gui.Prototype.SetFont}.
     *
     * @param {String} [Options.FontOpt = "s11 q5"] - `Options.FontOpt` is passed to the `Options`
     * parameter of {@link https://www.autohotkey.com/docs/v2/lib/Gui.htm#SetFont Gui.Prototype.SetFont}.
     *
     * @param {Integer} [Options.InsufficientSpaceAction = 2] - See
     * {@link PopupWindow_MoveAdjacent~InsufficientSpaceAction}.
     *
     * @param {Integer} [Options.MarginB = 3] - The margin, in pixels, between the text and the bottom
     * of the window.
     *
     * @param {Integer} [Options.MarginL = 3] - The margin, in pixels, between the text and the left
     * side of the window.
     *
     * @param {Integer} [Options.MarginR = 3] - The margin, in pixels, between the text and the right
     * side of the window.
     *
     * @param {Integer} [Options.MarginT = 3] - The margin, in pixels, between the text and the top
     * of the window.
     *
     * @param {Integer} [Options.OffsetX = 0] - An offset that is applied to the x-coordinate when
     * the window is repositioned during the execution of {@link PopupWindow.Prototype.ShowByMouse}.
     *
     * @param {Integer} [Options.OffsetY = 0 ] - An offset that is applied to the y-coordinate when
     * the window is repositioned during the execution of {@link PopupWindow.Prototype.ShowByMouse}.
     *
     * @param {String} [Options.Opt = "+Owner -SysMenu -Caption +AlwaysOnTop"] - The value to pass to
     * the `Options` parameter of {@link https://www.autohotkey.com/docs/v2/lib/Gui.htm#Call Gui.Call}.
     * If you set this, you should include "+Owner -SysMenu -Caption +AlwaysOnTop".
     *
     * @param {Integer} [Options.Padding = 0] - See {@link PopupWindow_MoveAdjacent~Padding}.
     *
     * @param {String} [Options.Prefer] - See {@link PopupWindow_MoveAdjacent~Prefer}.
     *
     * @param {Integer} [Options.Priority = 0] - The value passed to the `Priority` parameter
     * of {@link https://www.autohotkey.com/docs/v2/lib/SetTimer.htm SetTimer} when setting the timer
     * to hide the window.
     *
     * @param {String} [Options.TextOpt] - The value passed to the `Options` parameter of
     * {@link https://www.autohotkey.com/docs/v2/lib/Gui.htm#Add Gui.Prototype.Add} when adding
     * the text control.
     *
     * @param {String} [Options.Title] - The value to pass to the `Title` parameter of
     * {@link https://www.autohotkey.com/docs/v2/lib/Gui.htm#Call Gui.Call}.
     *
     * @param {Integer} [Options.Width] - Set `Options.Width` to restrict the width of the window
     * to a maximum size in pixels. The text wrapping is faciliated by {@link PopupWindow_WrapText}.
     * Also see `Options.WrapTextOptions`.
     *
     * @param {Object} [Options.WrapTextOptions] - When `Options.Width` is set,
     * {@link PopupWindow_WrapText} is used to handle wrapping the text. You can customize the behavior
     * by setting `Options.WrapTextOptions` with an options object.
     */
    __New(Text?, Options?) {
        if IsSet(Options) {
            super.__New(
                HasProp(Options, 'Opt') ? Options.Opt : '+Owner -SysMenu -Caption +AlwaysOnTop',
                HasProp(Options, 'Title') ? Options.Title : unset,
                HasProp(Options, 'EventHandler') ? Options.EventHandler : unset
            )
            if HasProp(Options, 'BackColor') {
                this.BackColor := Options.BackColor
            }
            if HasProp(Options, 'WrapTextOptions') {
                this.WrapTextOptions := Options.WrapTextOptions
            }
            if HasProp(Options, 'Priority') {
                this.Priority := Options.Priority
            }
            if HasProp(Options, 'Duration') {
                this.Duration := Options.Duration
            }
            if HasProp(Options, 'ContainerRect') {
                this.ContainerRect := Options.ContainerRect
            }
            if HasProp(Options, 'Dimension') {
                this.Dimension := Options.Dimension
            }
            if HasProp(Options, 'Prefer') {
                this.Prefer := Options.Prefer
            }
            if HasProp(Options, 'Padding') {
                this.Padding := Options.Padding
            }
            if HasProp(Options, 'InsufficientSpaceAction') {
                this.InsufficientSpaceAction := Options.InsufficientSpaceAction
            }
            if HasProp(Options, 'OffsetX') {
                this.OffsetX := Options.OffsetX
            }
            if HasProp(Options, 'OffsetY') {
                this.OffsetY := Options.OffsetY
            }
            super.SetFont(
                HasProp(Options, 'FontOpt') ? Options.FontOpt : 's11 q5',
                HasProp(Options, 'FaceName') ? Options.FaceName : 'Segoe Ui'
            )
            for prop in [ 'Width', 'MarginL', 'MarginT', 'MarginR', 'MarginB' ] {
                if HasProp(Options, prop) {
                    this.__%prop% := Options.%prop%
                }
            }
            this.HwndCtrl := this.Add('Text', (HasProp(Options, 'TextOpt') ? Options.TextOpt : '')).Hwnd
            super.Show('x' _GetRBound())
            if IsSet(Text) {
                this.SetText(Text)
                if !HasProp(Options, 'DeferShow') || !Options.DeferShow {
                    if HasProp(Options, 'X') || HasProp(Options, 'Y') {
                        this.Show(
                            HasProp(Options, 'X') ? Options.X : unset,
                            HasProp(Options, 'Y') ? Options.Y : unset
                        )
                    } else {
                        this.ShowByMouse()
                    }
                    return
                }
            }
        } else {
            super.__New('+Owner -SysMenu -Caption')
            super.SetFont('s11 q5', 'Segoe Ui')
            this.HwndCtrl := this.Add('Text').Hwnd
            super.Show('x' _GetRBound())
            if IsSet(Text) {
                this.SetText(Text)
                this.ShowByMouse()
                return
            }
        }
        this.Hide()
        this.Move(0, 0)

        return

        _GetRBound() {
            x := -4294967295
            loop MonitorGetCount() {
                MonitorGet(A_Index, , , &r)
                x := Max(x, r)
            }
            return x + 1
        }
    }
    Call(Text?, X?, Y?) {
        if IsSet(Text) {
            this.SetText(Text)
        }
        if IsSet(X) || IsSet(Y) {
            this.Show(X ?? unset, Y ?? unset)
        } else {
            this.ShowByMouse()
        }
    }
    SetFont(FontOpt?, FaceName?) {
        this.Ctrl.SetFont(FontOpt ?? unset, FaceName ?? unset)
        this.UpdateTextRect()
    }
    SetMargin(L?, T?, R?, B?) {
        if IsSet(L) {
            this.__MarginL := L
        }
        if IsSet(T) {
            this.__MarginT := T
        }
        if IsSet(R) {
            this.__MarginR := R
        }
        if IsSet(B) {
            this.__MarginB := B
        }
        this.Ctrl.Move(this.__MarginL, this.__MarginT)
        if DllCall('IsWindowVisible', 'ptr', this.Hwnd, 'int') {
            this.Ctrl.GetPos(, , &w, &h)
            super.Show('w' (this.__MarginL + this.__MarginR + w) ' h' (this.__MarginT + this.__MarginB + h))
        }
    }
    SetText(Text) {
        this.Ctrl.Text := RegExReplace(Text, '\R', '`r`n')
        this.UpdateTextRect()
    }
    Show(X?, Y?, Options := 'NoActivate') {
        this.Ctrl.GetPos(, , &w, &h)
        super.Show(
            (IsSet(X) ? 'x' X : '')
            (IsSet(Y) ? ' y' Y : '')
            ' w' (this.__MarginL + this.__MarginR + w)
            ' h' (this.__MarginT + this.__MarginB + h)
            ' ' Options
        )
        if this.__Duration {
            SetTimer(PopupWindow_Hide.Bind(this.Hwnd), this.__Duration, this.Priority)
        }
    }
    ShowByMouse(Options := 'NoActivate') {
        PopupWindow_MoveByMouse(
            this.Hwnd,
            this.ContainerRect || unset,
            this.Dimension || unset,
            this.Prefer || unset,
            this.Padding,
            this.InsufficientSpaceAction,
            &rc
        )
        this.Ctrl.GetPos(, , &w, &h)
        super.Show(
            'x' rc.L ' y' rc.T
            ' w' (this.__MarginL + this.__MarginR + w)
            ' h' (this.__MarginT + this.__MarginB + h)
            ' ' Options
        )
        if this.__Duration {
            SetTimer(PopupWindow_Hide.Bind(this.Hwnd), this.__Duration, this.Priority)
        }
    }
    UpdateTextRect() {
        ctrl := this.Ctrl
        if this.__Width {
            options := {
                AdjustObject: true,
                MaxExtent: this.__Width,
                MeasureLines: true,
                EndOfLine: '`r`n'
            }
            if this.WrapTextOptions {
                ObjSetBase(options, this.WrapTextOptions)
            }
            PopupWindow_WrapText(ctrl, &str, options, &w, &h)
        } else {
            PopupWindow_ControlFitText(ctrl, , , false, , &w, &h)
        }
        ctrl.Move(this.__MarginL, this.__MarginT)
        if DllCall('IsWindowVisible', 'ptr', this.Hwnd, 'int') {
            super.Show('w' (this.__MarginL + this.__MarginR + w) ' h' (this.__MarginT + this.__MarginB + h))
        }
    }

    Ctrl => GuiCtrlFromHwnd(this.HwndCtrl)
    Duration {
        Get => this.__Duration
        Set => this.__Duration := -Abs(Value)
    }
    MarginL {
        Get => this.__MarginL
        Set => this.SetMargin(Value)
    }
    MarginT {
        Get => this.__MarginT
        Set => this.SetMargin(, Value)
    }
    MarginR {
        Get => this.__MarginR
        Set => this.SetMargin(, , Value)
    }
    MarginB {
        Get => this.__MarginB
        Set => this.SetMargin(, , , Value)
    }
    Width {
        Get => this.__Width
        Set {
            this.__Width := Value
            this.UpdateTextRect()
        }
    }
    Text {
        Get => this.Ctrl.Text
        Set => this.SetText(Value)
    }
}

PopupWindow_Hide(Hwnd) {
    if WinExist(Hwnd) {
        WinHide(Hwnd)
    }
}

/**
 * @classdesc - Use this as a safe way to access a window's font object. This handles accessing and
 * releasing the device context and font object.
 */
class PopupWindow_SelectFontIntoDc {

    __New(hWnd) {
        this.hWnd := hWnd
        if !(this.hdc := DllCall('GetDC', 'Ptr', hWnd, 'ptr')) {
            throw OSError()
        }
        OnError(this.Callback := ObjBindMethod(this, '__ReleaseOnError'), 1)
        if !(this.hFont := SendMessage(0x0031, 0, 0, , hWnd)) { ; WM_GETFONT
            throw OSError()
        }
        if !(this.oldFont := DllCall('SelectObject', 'ptr', this.hdc, 'ptr', this.hFont, 'ptr')) {
            throw OSError()
        }
    }

    /**
     * @description - Selects the old font back into the device context, then releases the
     * device context.
     */
    Call() {
        if err := this.__Release() {
            throw err
        }
    }

    __ReleaseOnError(thrown, mode) {
        if err := this.__Release() {
            thrown.Message .= '; ' err.Message
        }
        throw thrown
    }

    __Release() {
        if this.oldFont {
            if !DllCall('SelectObject', 'ptr', this.hdc, 'ptr', this.oldFont, 'int') {
                err := OSError()
            }
            this.DeleteProp('oldFont')
        }
        if this.hdc {
            if !DllCall('ReleaseDC', 'ptr', this.hWnd, 'ptr', this.hdc, 'int') {
                if IsSet(err) {
                    err.Message .= '; Another error occurred: ' OSError().Message
                }
            }
            this.DeleteProp('hdc')
        }
        OnError(this.Callback, 0)
        this.DeleteProp('Callback')
        return err ?? ''
    }

    static __New() {
        this.DeleteProp('__New')
        proto := this.Prototype
        proto.DefineProp('hdc', { Value: '' })
        proto.DefineProp('hFont', { Value: '' })
        proto.DefineProp('oldFont', { Value: '' })
    }
}

class PopupWindow_IntegerArray extends Buffer {
    /**
     * @description - A buffer object that can be used with Dll calls or other actions that require a
     * pointer to a buffer to be filled with integers.
     *
     * This class is intended to simplify the handling of any series of integers contained in a buffer;
     * the objects can be enumerated by calling it in a `for` loop, and the items can be accessed by index,
     * which is a slight convenience to using multiples of the byte size with `NumGet`. Negative indices
     * are treated as right-to-left.
     *
     * Note: To adhere to AHK's convention, the value at byte offset 0 is considered index 1.
     *
     * @example
     * ia := PopupWindow_IntegerArray(
     *     Capacity := 4,
     *     IntType := "int",
     *     IntSize := 4,
     *     ; Note I have only added 3 values.
     *     10, 23, 1991
     * )
     * MsgBox(ia[1]) ; 10
     * MsgBox(ia[-2]) ; 1991
     * ia[4] := 18
     * MsgBox(ia[-1]) ; 18
     * ; enumerate the values
     * s := ""
     * for n in ia {
     *     str .= n ", "
     * }
     * MsgBox(SubStr(str, 1, -2)) ; 10, 23, 1991, 18
     *
     * ; If I need to add more, I must increase the capacity.
     * ia.Capacity := 5
     * ia[5] := 30
     * MsgBox(ia[-1]) ; 30
     *
     * ; To use in a `DllCall`, just pass the object directly
     * DllCall('FunctionName', 'ptr', ia)
     * @
     *
     * The object does not track which indices are set; accessing an unset index will still return
     * a value but the value will be meaningless. Consequently, when enumerating the object in a
     * `for` loop, it will iterate the entire buffer even if you never added an integer to any index.
     *
     * You can call {@link PopupWindow_IntegerArray.Prototype.Enum} to restrict the range of indices which get
     * enumerated.
     *
     * @example
     * ia := PopupWindow_IntegerArray(
     *     Capacity := 6,
     *     IntType := "int",
     *     IntSize := 4,
     *     ; Note I have only added 3 values.
     *     10, 9, 10
     * )
     * iaEnumerator := ia.Enum(
     *     VarCount := 1,
     *     StartIndex := 1,
     *     StopIndex := 3
     * )
     * for n in iaEnumerator {
     *     ; work
     * }
     *
     * ; or call the enumerator inline
     * for n in ia.Enum(1, 1, 3) {
     *     ; work
     * }
     *
     * ; or call the enumerator in 2-param mode
     * s := ""
     * for i, n in ia.Enum(VarCount := 2, 1, 3) {
     *     s .= i ": " n ", "
     * }
     * MsgBox(SubStr(s, 1, -2)) ; 1: 10, 2: 9, 3: 10
     * @
     *
     * Regarding the {@link PopupWindow_IntegerArray.Prototype.__Item} property, -1 will always be the last position
     * according to the `Size` property, even if you never added a value there.
     *
     * @class
     *
     * @param {Integer} [Capacity = 0] - The maximum item count in number of items. This value is used
     * to set the {@link https://www.autohotkey.com/docs/v2/lib/Buffer.htm#Size Size} property of
     * the buffer object.
     *
     * @param {String} [IntType = "int"] - The type of integer. This gets used as the `Type` param
     * of {@link https://www.autohotkey.com/docs/v2/lib/NumGet.htm NumGet} and
     * {@link https://www.autohotkey.com/docs/v2/lib/NumPut.htm NumPut}. Also see
     * {@link https://www.autohotkey.com/docs/v2/lib/DllCall.htm#types}.
     *
     * @param {Integer} [IntSize = 4] - The size of the integer in bytes.
     *
     * @param {...Integer} [Values] - Any number of values to be added to the buffer.
     */
    __New(Capacity?, IntType := 'int', IntSize := 4, Values*) {
        this.IntSize := IntSize
        this.IntType := IntType
        if IsSet(Capacity) {
            this.Capacity := Capacity
            if Values.Length > Capacity {
                throw ValueError('The number of values exceeds the capacity.')
            }
        } else {
            this.Capacity := Values.Length
        }
        for Value in Values {
            if IsSet(Value) {
                NumPut(IntType, Value, this, (A_Index - 1) * this.IntSize)
            }
        }
    }

    Enum(VarCount := 1, StartIndex := 1, StopIndex := this.Capacity) {
        i := StartIndex - 1
        intSize := this.IntSize
        intType := this.IntType

        return _Enum%VarCount%

        _Enum1(&Value) {
            if ++i > StopIndex {
                return 0
            }
            Value := NumGet(this, (i - 1) * intSize, intType)
            return 1
        }
        _Enum2(&Index, &Value) {
            if ++i > StopIndex {
                return 0
            }
            Value := NumGet(this, (i - 1) * intSize, intType)
            Index := i
            return 1
        }
    }

    Capacity {
        Get => this.Size / this.IntSize
        Set => this.Size := Value * this.IntSize
    }

    __Enum(VarCount := 1) => this.Enum(VarCount)

    __Item[Index] {
        Get {
            if !Index {
                throw IndexError('Invalid index.', , Index)
            }
            if Abs(Index) > this.Capacity {
                throw IndexError('Index out of range.', , Index)
            }
            return NumGet(this, Index > 0 ? (Index - 1) * this.IntSize : this.Size + Index * this.IntSize, this.IntType)

        }
        Set {
            if !Index {
                throw IndexError('Invalid index.', , Index)
            }
            if Abs(Index) > this.Capacity {
                throw IndexError('Index out of range.', , Index)
            }
            If !IsInteger(Value) {
                throw TypeError('The value must be an integer.', , IsObject(Value) ? '' : Value)
            }
            NumPut(this.IntType, Value, this, Index > 0 ? (Index - 1) * this.IntSize : this.Size + Index * this.IntSize)
        }
    }
}

class PopupWindow_Size extends Buffer {
    /**
     * @description - A buffer representing a
     * {@link https://learn.microsoft.com/en-us/windows/win32/api/windef/ns-windef-size SIZE structure}.
     * @class
     * @param {Integer} [W] - The width.
     * @param {Integer} [H] - The height.
     */
    __New(W?, H?) {
        this.Size := 8
        if IsSet(W) {
            this.W := W
        }
        if IsSet(H) {
            this.H := H
        }
    }
    W {
        Get => NumGet(this, 0, 'int')
        Set => NumPut('int', Value, this)
    }
    H {
        Get => NumGet(this, 4, 'int')
        Set => NumPut('int', Value, this, 4)
    }
}

/**
 * @description - Gets the dimensions of a string within a window's device context. Carriage return
 * and line feed characters are ignored, the returned height is always that of a one-line string.
 *
 * See {@link https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-gettextextentpoint32w}.
 *
 * @param {Integer} hdc - A handle to the device context you want used to measure the string.
 * @param {String} Str - The string to measure.
 * @returns {PopupWindow_Size}
 */
PopupWindow_GetTextExtentPoint32(hdc, Str) {
    ; Measure the text
    if DllCall('Gdi32.dll\GetTextExtentPoint32'
        , 'Ptr', hdc
        , 'Ptr', StrPtr(Str)
        , 'Int', StrLen(Str)
        , 'Ptr', sz := PopupWindow_Size()
        , 'Int'
    ) {
        return sz
    } else {
        throw OSError()
    }
}

/**
 * @description - {@link PopupWindow_GetTextExtentExPoint} measures a string's dimensions and the width (extent
 * point) in pixels of each character's position in the string.
 *
 * See {@link https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-gettextextentexpointw}.
 *
 * @param {Integer} hdc - The handle to the device context to use when measuring the string.
 * @param {String} Str - The string to measure.
 * @param {Integer} [MaxExtent = 0] - The maximum width of the string in pixels. When nonzero,
 * `OutCharacterFit` is set to the number of characters that fit within the `MaxExtent` pixels, and
 * `OutExtentPoints` will only contain extent points up to `OutCharacterFit` number of characters.
 * If 0, `MaxExtent` is ignored, `OutCharacterFit` is assigned 0, and `OutExtentPoints` will contain
 * the extent point for every character in the string.
 * @param {VarRef} [OutCharacterFit] - A variable that will receive the number of characters
 * that fit within the given width. If `MaxExtent` is 0, this will be set to 0.
 * @param {VarRef} [OutExtentPoints] - A variable that will receive an {@link PopupWindow_IntegerArray},
 * a buffer object containing the partial string extent points (the cumulative width of the string at
 * each character from left to right measured from the beginning of the string to the right-side of
 * the character). If `MaxExtent` is nonzero, the number of extent points contained by
 * `OutExtentPoints` will equal `OutCharacterFit`. If `MaxExtent` is zero, `OutExtentPoints` will
 * contain the extent point for every character in the string. See {@link PopupWindow_IntegerArray}
 * for more information.
 * @returns {PopupWindow_Size}
 */
PopupWindow_GetTextExtentExPoint(hdc, Str, MaxExtent := 0, &OutCharacterFit?, &OutExtentPoints?) {
    if MaxExtent {
        if DllCall('Gdi32.dll\GetTextExtentExPoint'
            , 'ptr', hdc
            , 'ptr', StrPtr(Str)                                    ; String to measure
            , 'int', StrLen(Str)                                    ; String length in WORDs
            , 'int', MaxExtent                                      ; Maximum width
            , 'ptr', lpnFit := Buffer(4)                            ; To receive number of characters that can fit
            , 'ptr', OutExtentPoints := PopupWindow_IntegerArray(StrLen(Str))   ; An array to receives partial string extents.
            , 'ptr', sz := PopupWindow_Size()                                   ; To receive the dimensions of the string.
            , 'ptr'
        ) {
            OutCharacterFit := NumGet(lpnFit, 0, 'int')
            return sz
        } else {
            throw OSError()
        }
    } else {
        if DllCall('Gdi32.dll\GetTextExtentExPoint'
            , 'ptr', hdc
            , 'ptr', StrPtr(Str)                                    ; String to measure
            , 'int', StrLen(Str)                                    ; String length in WORDs
            , 'int', 0
            , 'ptr', 0
            , 'ptr', OutExtentPoints := PopupWindow_IntegerArray(StrLen(Str))   ; An array to receives partial string extents.
            , 'ptr', sz := PopupWindow_Size()                                   ; To receive the dimensions of the string.
            , 'ptr'
        ) {
            OutCharacterFit := 0
            return sz
        } else {
            throw OSError()
        }
    }
}

class PopupWindow_WrapText {

    /**
     * @description - Wraps text to a maximum width in pixels.
     *
     * {@link PopupWindow_WrapText} measures the input text
     *
     * If one or more characters between `Options.MinExtent` and `Options.MaxExtent` are break
     * characters, then:
     * - If the break character closest to `Options.MaxExtent` is a whitespace character, then the
     *   line wraps before the whitespace character. Any extra whitespace characters are trimmed from
     *   each line.
     * - If the break character closest to `Options.MaxExtent` is not a whitespace character, then
     *   the line wraps after the character.
     *
     * If there are no break characters, then the line is wrapped after the character closest to
     * `Options.MaxExtent`. A hyphen may be added depending on the character and the input options.
     * {@link PopupWindow_WrapText} ensures that adding a hyphen does not cause the line to exceed `Options.MaxExtent`.
     *
     * Additional details:
     * - When `Options.MeasureLines` is false, and if {@link PopupWindow_WrapText} is directed to use hyphens where
     *   appropriate, there is a small chance that some measurements may be off by one or two pixels. This
     *   is caused by the way {@link PopupWindow_WrapText} handles hyphens. If `Options.MeasureLines` is false, any
     *   measurement that involves a hyphen is produced by adding the width of a hyphen to the width of
     *   a line. This does not account for kerning and other system-dependent conditions, and may produce
     *   an incorrect value. If your application requires precise adherence to `Options.MaxExtent`, set this
     *   to a nonzero value. When false, the possible incorrect values produced by {@link PopupWindow_WrapText} are:
     *   - The width of any line that is hyphenated can potentially be one or two pixels over
     *     `Options.MaxExtent` or one or two pixels under `Options.MinExtent`.
     *   - The value received by `OutWidth` may be one or two pixels off in either direction from the
     *     actual width.
     * - All consecutive end of line characters are converted to a single space character prior to processing.
     * - When making the decision to add additional characters to `Options.BreakChars`, keep in mind that,
     *   if a break character will always be followed by a whitespace character, then adding it to
     *   `Options.BreakChars` will only change the amount of time it takes {@link PopupWindow_WrapText} to process the input.
     *   It will not change the output string. If there is a possibility that the character is followed by
     *   a non-whitespace character, and it is a character that you believe is a natural break character for
     *   your project, then you should add it to the list.
     * - There's no harm if the input string ultimately does not contain one or more of the characters
     *   from `Options.BreakChars`; the string is checked to see if it contains at least one of each
     *   character. If any character is absent, it is purged from the list of possible break characters to
     *   save processing time.
     * - If there are only spaces (and no tabs) in the input string, {@link PopupWindow_WrapText} only checks for spaces
     *   when searching for whitespace, and vise-versa.
     * - A hyphen is never added after a break character, even if the break character is alphanumeric and
     *   the related option is true.
     * - If the difference between `Options.MaxExtent` and `Options.MinExtent` is relatively small,
     *   there is a possibility that no valid wrap position is available within a substring. If this occurs,
     *   {@link PopupWindow_WrapText} will always choose to wrap at an extent less than `Options.MaxExtent`, resulting in a
     *   line shorter than `Options.MinExtent`.
     * - Similar to the above point, if {@link PopupWindow_WrapText} trims whitespace characters from the end of a line,
     *   this can cause the line to be shorter than `Options.MinExtent`.
     *
     * @param {Gui.Control|Integer|Object} Context - Either a handle to the device context to use to
     * measure the text, a `Gui.Control` object, or an object with an `hWnd` property.
     *
     * @param {VarRef} [Str] - The input string, and/or a variable that will receive the result string.
     * - `Str` is required when `Context` is a handle to a device context.
     * - If you set `Str` with a string value, {@link PopupWindow_WrapText} always processes that value, and sets the
     *   variable with the resulting string before {@link PopupWindow_WrapText} returns.
     * - If `Context` is an object, then `Str` is optional. If you leave it unset, or pass it as an unset
     *   VarRef / empty string VarRef, then {@link PopupWindow_WrapText} processes the contents of `Context.Text`. If the
     *   object does not have a `Text` property, AHK will throw an error.
     *
     * @param {Object|PopupWindow_WrapText.Options} [Options] - If `Options` is an
     * {@link PopupWindow_WrapText.Options} object, it does not get passed to
     * {@link PopupWindow_WrapText.Options.Prototype.__New}, saving a bit of processing time.
     * Otherwise, it is an object containing zero or more options as property : value pairs.
     *
     * @param {Boolean} [Options.AdjustObject = false] - If `Options.AdjustObject == true`, then `WrapText`
     * expects `Context` to be an object with a `Text` property and a `Move` method, such as a `Gui.Control`
     * object. Before `WrapText` exits, `WrapText` removes any soft hyphens from the result string, then
     * sets the `Context.Text` property with the result string, then calls `Context.Move`. The width
     * used is the greatest width of each line in the string (same value that `OutWidth` receives).
     * The height used depends on the value of `Options.MeasureLines`. If `Options.MeasureLines` is
     * nonzero, then `OutHeight` is set with the cumulative height of the string, and its value gets
     * used. If `Options.MeasureLines` is false, the height is set to `sz.H * LineCount` where `sz`
     * is the  {@link Display_Size} object produced from the last `GetTextExtentExPoint` function
     * call. In general this will be pretty close to the true height of the string, but should
     * be expected to be slightly off.
     *
     * @param {String} [Options.BreakChars = "-"] - `BreakChars` is a list of characters that defines what
     * characters are valid breakpoints for splitting a line other than a space or tab. Do not include
     * any separators between the characters. Do not escape any characters. See the function description
     * for a description of {@link PopupWindow_WrapText}'s process.
     *
     * @param {Boolean} [Options.HyphenateLetters = true] - When true, {@link PopupWindow_WrapText} hyphenates the line if
     * the last character in the line causes `IsAlpha(char)` to return true. This option is only invoked
     * if a line does not contain any break characters between `Options.MinExtent` and `Options.MaxExtent`.
     *
     * @param {Boolean} [Options.HyphenateNumbers = false] - When true, {@link PopupWindow_WrapText} hyphenates the line if
     * the last character in the line causes `IsNumber(char)` to return true. This option is only invoked
     * if a line does not contain any break characters between `Options.MinExtent` and `Options.MaxExtent`.
     *
     * @param {Integer} [Options.MaxExtent] - The maximum width of a line in pixels. This is optional when
     * `Context` is an object with a `GetPos` method, such as a `Gui.Control` object. If `Options.MaxExtent`
     * is unset, `Context.GetPos(, , &MaxExtent)` is called. The maximum width must be at least three times
     * the width of a "W" character in the device context.
     *
     * @param {Boolean|Array} [Options.MeasureLines] - When a nonzero value, {@link PopupWindow_WrapText} will measure
     * each line during processing. This allows {@link PopupWindow_WrapText} to set `OutHeight` with the correct height
     * of the string, and `OutWidth` with an accurate width of the string (see the note about this
     * in the function description). If `Options.MeasureLines` is an array object, {@link PopupWindow_WrapText} will also
     * add each `Size` object that is produced from the measurement to that array. For large strings
     * or many consecutive function calls, you should set the capacity of the array to what you expect
     * it will need prior to calling {@link PopupWindow_WrapText}. If {@link PopupWindow_WrapText} is false, no additional measurements occur.
     *
     * @param {Number} [Options.MinExtent] - Sets the minimum width of a line, directing {@link PopupWindow_WrapText}
     * to require each line to be at least the minimum before inserting a line break.
     *
     * If `Options.MinExtent` is between 0 and 1, the minimum width of a line is
     * `Ceil(Options.MinExtent * Options.MaxExtent)`. Use this to specify a minimum width as a proportion
     * of the maximum. If `Options.MinExtent` is greater than 1, `Options.MinExtent` is used as the
     * minimum width of a line, in pixels.
     *
     * `Options.MinExtent` directs {@link PopupWindow_WrapText} to break each line at an extent point no less than the minimum.
     * This is useful in most situations, but particularly in situations where the input string contains
     * words/substrings that are generally pretty long relative to `Options.MaxExtent`. {@link PopupWindow_WrapText}'s default
     * behavior might cause a line to be very short, in a way that would be aesthetically unnatural or
     * displeasing. When `Options.MinExtent` is set, if a substring does not contain a valid break character
     * between `Options.MinExtent` and `Options.MaxExtent`, then it will wrap the line at or around
     * `Options.MaxExtent` (depending on the values of the other options) as if there were no break
     * characters in the entire line. The example below depicts the default behavior without
     * `Options.MinExtent`.
     *
     * @example
     * Ctrl := (G := Gui()).AddText()
     * Ctrl.Text := 'She sang supercalifradulisticexpialidocious then went on her merry way.'
     * hdc := DllCall('GetDC', 'Ptr', Ctrl.hWnd, 'Ptr')
     * sz := GetTextExtentPoint32(hdc, 'She sang supercalifradulisticexpialidoc')
     * LineCount := PopupWindow_WrapText(Ctrl, &Str, { MaxExtent: sz.W, AdjustObject: true })
     * Split := StrSplit(Ctrl.Text, '`r`n')
     * MsgBox(Split[1]) ; She sang
     * MsgBox(Split[2]) ; supercalifradulisticexpialidocious then
     * MsgBox(Split[3]) ; went on her merry way.
     * @
     *
     * @param {String} [Options.EndOfLine = "`r`n"] - The end of line character(s) to use.
     *
     * @param {Boolean} [Options.ZeroWidthSpace = true] - When true, if the input text contains Zero Width
     * Space characters (code point U+200B), they will be treated as soft hyphens and will be used as
     * a break character. When a line breaks at a Zero Width Space character, a visible hyphen is placed
     * after the Zero Width Space character and the line wraps after the hyphen. When false, Zero Width
     * Space characters are ignored and when a hard break is necessary, {@link PopupWindow_WrapText} breaks the line at the
     * greatest extent which satisfies the other options. When false and if hyphens are used, a substring
     * may be hyphenated at any position in the word. Generally this should be left true; if no U+200B
     * characters are present in the input string, {@link PopupWindow_WrapText} adjusts its process to avoid using resources
     * searching for them.
     *
     * @param {VarRef} [OutWidth] - A variable that will receive the width of the line with the greatest
     * width in the result string.
     *
     * @param {VarRef} [OutHeight] - A variable that will receive the cumulative height of each line.
     * This only receives a value if `Options.MeasureLines` is nonzero.
     *
     * @returns {Integer} - The number of lines the text was split into.
     */
    static Call(Context, &Str?, Options?, &OutWidth?, &OutHeight?) {
        local Pos
        if IsSet(Options) && Options.__Class != 'PopupWindow_WrapText.Options' {
            Options := PopupWindow_WrapText.Options(Options ?? unset)
        }
        if IsObject(Context) {
            if HasProp(Context, 'hWnd') {
                ; If MaxExtent is unset, use the width of the control.
                if Options.MaxExtent {
                    MaxExtent := Options.MaxExtent
                } else {
                    Context.GetPos(, , &MaxExtent)
                }
                if IsSet(Str) {
                    Text := RegExReplace(Str, '\R+', ' ')
                } else if IsObject(Context.Text) {
                    throw TypeError('``Context.Text`` returned an object.',
                    , 'Type(Context.Text) == ' Type(Context.Text))
                } else {
                    Text := RegExReplace(Context.Text, '\R+', ' ')
                }
                font_context := PopupWindow_SelectFontIntoDc(Context.hWnd)
                hdc := font_context.hdc
            } else {
                _Throw(1, A_LineNumber, A_ThisFunc)
            }
        } else if IsNumber(Context) {
            if !IsSet(Str) || !Options.MaxExtent {
                _Throw(2, A_LineNumber, A_ThisFunc)
            }
            MaxExtent := Options.MaxExtent
            hdc := Context
            Text := RegExReplace(Str, '\R+', ' ')
        } else {
            _Throw(1, A_LineNumber, A_ThisFunc)
        }

        ; Set MinExtent
        if IsNumber(Options.MinExtent) {
            if Options.MinExtent < 1 {
                MinExtent := Ceil(MaxExtent * Options.MinExtent)
            } else {
                MinExtent := Options.MinExtent
            }
        } else {
            MinExtent := 0
        }

        ; Initialize the buffers
        fitBuf := Buffer(4)
        Extent := PopupWindow_IntegerArray(StrLen(Text))
        sz := PopupWindow_Size()

        ; Measure the width of a hyphen
        hyphen := '-'
        if !DllCall('Gdi32.dll\GetTextExtentPoint32', 'Ptr'
            , hdc, 'Ptr', StrPtr(hyphen), 'Int', 1, 'Ptr', sz, 'Int') {
            throw OSError()
        }
        hyphen := sz.W

        ; `MaxExtent` must at least be large enough such that the loops can iterate once or twice
        ; before reaching the beginning of the substring.
        if !DllCall('Gdi32.dll\GetTextExtentPoint32', 'Ptr'
            , hdc, 'Ptr', StrPtr('W'), 'Int', 1, 'Ptr', sz, 'Int') {
            throw OSError()
        }
        if MaxExtent < sz.W * 3 {
            throw ValueError('``Options.MaxExtent`` must be at least three times the width of "W" in the device'
            ' context.', -1, '``Options.MaxExtent``: ' MaxExtent '; Function minimum: ' (sz.W * 3))
        }

        ; Set the condition determining whether a hyphen is used.
        if Options.HyphenateLetters {
            Hyphenate := Options.HyphenateNumbers
            ? () => IsAlnum(SubStr(Text, Pos, 1))
            : () => IsAlpha(SubStr(Text, Pos, 1))
            _Proc_0 := _Proc_0_1
        } else if Options.HyphenateNumbers {
            Hyphenate := () => IsNumber(SubStr(Text, Pos, 1))
            _Proc_0 := _Proc_0_1
        } else {
            _Proc_0 := _Proc_0_0
        }

        ; Check the string for the presence of break characters
        BreakChars := ''
        z := InStr(Text, '`t') ? 1 : 0
        if Options.BreakChars {
            _BreakChars := ''
            for ch in StrSplit(Options.BreakChars) {
                if InStr(Text, ch) {
                    _BreakChars .= ch
                }
            }
            if Options.RespectSoftHyphen && InStr(Text, Chr(0x200B)) {
                _BreakChars .= Chr(0x200B)
                _Proc_B := _Proc_B_1
            } else {
                _Proc_B := _Proc_B_0
            }
            if _BreakChars {
                _BreakChars := RegExReplace(StrReplace(_BreakChars, '\', '\\'), '(\]|-)', '\$1')
                BreakChars := '([' _BreakChars '])[^' _BreakChars ']*$'
                z += 2
            }
        } else if Options.RespectSoftHyphen && InStr(Text, Chr(0x200B)) {
            BreakChars := '([' Chr(0x200B) '])[^' Chr(0x200B) ']*$'
            z += 2
            _Proc_B := _Proc_B_1
        } else {
            _Proc_B := _Proc_B_0
        }
        if InStr(Text, '`s') {
            z += 4
        }
        switch z {
            case 0: Proc := _Proc_0
            case 1: Proc := _Proc_1.Bind('`t')      ; Tabs
            case 2: Proc := _Proc_2                 ; Break chars
            case 3: Proc := _Proc_3.Bind('`t')      ; Tabs + break chars
            case 4: Proc := _Proc_1.Bind('`s')      ; Spaces
            case 5: Proc := _Proc_4                 ; Spaces + tabs
            case 6: Proc := _Proc_3.Bind('`s')      ; Spaces + break chars
            case 7: Proc := _Proc_5                 ; Spaces + tabs + break chars
        }

        if Options.MeasureLines {
            OutHeight := 0
            ; I half the hyphen's width here to limit the number of instances when a line gets measured
            ; and its width exceed `Options.MaxExtent`, causing some steps to be repeated. When preemptively
            ; testing the width of a line, if I add the entire width of a hyphen to the line's width, this
            ; can occasionally cause `PopupWindow_WrapText` to skip a breakpoint that should have been used due to the
            ; imprecise measurement. If I don't test the lines, or test the lines by adding a width that
            ; is too small, there is a greater likelihood that some steps must be repeated. I don't
            ; expect any fonts are designed in a way that more than half of the hyphen's width is tucked
            ; into the previous font's space, and so I figure this is an acceptable approach.
            hyphen *= 0.5
            if Options.MeasureLines is Array {
                Measurements := Options.MeasureLines
                Set := _Set_1
            } else {
                Set := _Set_2
            }
        } else {
            Set := _Set_3
        }

        eol := Options.EndOfLine
        LineCount := 0
        OutWidth := 0
        Str := ''
        VarSetStrCapacity(&Str, StrLen(Text))

        ; Core loop
        loop {
            Len := StrLen(Text)
            ptr := StrPtr(Text)
            if !DllCall('Gdi32.dll\GetTextExtentExPoint'
                , 'ptr', hdc                ; Device context
                , 'ptr', ptr                ; String to measure
                , 'int', Len                ; String length in WORDs
                , 'int', MaxExtent          ; Maximum width
                , 'ptr', fitBuf             ; To receive number of characters that can fit
                , 'ptr', Extent             ; A buffer to receives partial string extents.
                , 'ptr', sz                 ; To receive the dimensions of the string.
                , 'ptr'
            ) {
                throw OSError()
            }
            if (fit := NumGet(fitBuf, 0, 'uint')) >= Len {
                break
            }
            LineCount++
            if Proc() {
                break
            }
        }

        ; Add last piece to the string
        if Text {
            Set(StrLen(Text))
            Str := Trim(Str, '`r`n`s`t')
            LineCount++
        }

        ; Release dc, disable error handler
        if IsObject(Context) {
            if Options.AdjustObject {
                Context.Text := Str
                if Options.MeasureLines {
                    Context.Move(, , OutWidth, OutHeight)
                } else {
                    Context.Move(, , OutWidth, sz.H * LineCount)
                }
            }
            font_context()
        }

        return LineCount

        ; No break characters or whitespace
        ; With hyphens
        _Proc_0_1() {
            Pos := NumGet(fitBuf, 0, 'uint')
            ; The loop checks if a hyphen should be added given the last character, and if so,
            ; checks if adding the hyphen will possibly cause the line to exceed `MaxExtent`.
            loop Pos - 1 {
                if Hyphenate() {
                    if Extent[Pos] + hyphen <= MaxExtent {
                        if Set(Pos, '-') {
                            Pos--
                        } else {
                            return _TrimRight()
                        }
                    } else {
                        Pos--
                    }
                } else {
                    Set(Pos)
                    return _TrimRight()
                }
            }
        }
        ; No break characters or whitespace
        ; Without hyphens
        _Proc_0_0() {
            Set(NumGet(fitBuf, 0, 'uint'))
            return _TrimRight()
        }
        ; Has spaces or tabs
        _Proc_1(ch) {
            if (Pos := InStr(SubStr(Text, 1, fit), ch, , , -1)) && Extent[Pos] >= MinExtent {
                return _Proc_W()
            } else {
                return _Proc_0()
            }
        }
        ; Has break characters
        _Proc_2() {
            if (Pos := RegExMatch(SubStr(Text, 1, fit), BreakChars)) && Extent[Pos] >= MinExtent {
                return _Proc_B()
            } else {
                return _Proc_0()
            }
        }
        ; Has either spaces / tabs, and break characters
        _Proc_3(ch) {
            Part := SubStr(Text, 1, fit)
            Pos := Max(Pos_B := RegExMatch(Part, BreakChars), Pos_W := InStr(Part, ch, , , -1))
            if !Pos || Extent[Pos] < MinExtent {
                return _Proc_0()
            } else if Pos_W > Pos_B {
                return _Proc_W()
            } else {
                return _Proc_B()
            }
        }
        ; Has spaces and tabs
        _Proc_4() {
            Part := SubStr(Text, 1, fit)
            Pos := Max(InStr(Part, '`t', , , -1), InStr(Part, '`s', , , -1))
            if Pos && Extent[Pos] >= MinExtent {
                return _Proc_W()
            } else {
                return _Proc_0()
            }
        }
        ; Has spaces, tabs, and break characters
        _Proc_5() {
            Part := SubStr(Text, 1, fit)
            Pos := Max(
                Pos_B := RegExMatch(Part, BreakChars)
              , Pos_W := Max(
                    InStr(Part, '`t', , , -1)
                  , InStr(Part, '`s', , , -1)
                )
            )
            if !Pos || Extent[Pos] < MinExtent {
                return _Proc_0()
            } else if Pos_W > Pos_B {
                return _Proc_W()
            } else {
                return _Proc_B()
            }
        }
        ; Breaking at a break character
        ; With soft hyphen
        _Proc_B_1() {
            if NumGet(ptr, (Pos - 1) * 2, 'str') == 0x200B {
                ; If adding the hyphen does not cause the width to exceed the max
                if Extent[Pos] + hyphen <= MaxExtent {
                    if Set(Pos, '-') {
                        ; Adjust `fit` to just before the ZWS, then re-check the string
                        fit := Pos - 1
                        return Proc()
                    }
                } else {
                    fit := Pos - 1
                    return Proc()
                }
            } else {
                Set(Pos)
            }
            return _TrimRight()
        }
        ; Breaking at a break character
        ; Without soft hyphen
        _Proc_B_0() {
            Set(Pos)
            return _TrimRight()
        }
        ; Breaking at a whitespace character
        _Proc_W() {
            _TrimLeft()
            ; If after trimming the whitespace, the length of the line is too short
            if Extent[Pos - 1] < MinExtent {
                return _Proc_0()
            } else {
                Set(Pos - 1)
                return _TrimRight()
            }
        }
        _ReleaseDC(Thrown, *) {
            DllCall('ReleaseDC', 'Ptr', Context.hWnd, 'Ptr', hdc, 'Int')
            OnError(_ReleaseDC, 0)
            throw Thrown
        }
        ; Measure string, add size object to array
        _Set_1(SetPos, AddHyphen := '') {
            Part := SubStr(Text, 1, SetPos) AddHyphen
            if DllCall('Gdi32.dll\GetTextExtentPoint32'
                , 'Ptr', hdc
                , 'Ptr', StrPtr(Part)
                , 'Int', StrLen(Part)
                , 'Ptr', measure_sz := PopupWindow_Size()
                , 'Int'
            ) {
                if measure_sz.W > MaxExtent {
                    return 1
                }
                Measurements.Push(measure_sz)
                OutWidth := Max(OutWidth, measure_sz.W)
                OutHeight += sz.H
                Str .= Part eol
            } else {
                throw OSError()
            }
        }
        ; Measure string, no array
        _Set_2(SetPos, AddHyphen := '') {
            Part := SubStr(Text, 1, SetPos) AddHyphen
            if DllCall('Gdi32.dll\GetTextExtentPoint32'
                , 'Ptr', hdc
                , 'Ptr', StrPtr(Part)
                , 'Int', StrLen(Part)
                , 'Ptr', sz
                , 'Int'
            ) {
                if sz.W > MaxExtent {
                    return 1
                }
                OutWidth := Max(OutWidth, sz.W)
                OutHeight += sz.H
                Str .= Part eol
            } else {
                throw OSError()
            }
        }
        ; Don't measure string
        _Set_3(SetPos, AddHyphen := false) {
            if AddHyphen {
                if Extent[SetPos] + hyphen > MaxExtent {
                    return 1
                }
                Part := SubStr(Text, 1, SetPos) '-'
                OutWidth := Max(OutWidth, Extent[SetPos] + hyphen)
                Str .= Part eol
            } else {
                Part := SubStr(Text, 1, SetPos)
                OutWidth := Max(OutWidth, Extent[SetPos])
                Str .= Part eol
            }
        }
        _Throw(Id, Line, Fn) {
            switch Id {
                case 1: err := TypeError('``Context`` must be either a number representing a handle to'
                    ' a device context, or an object with an ``hWnd`` property.', -2, 'Type(Context) == '
                    Type(Context))
                case 2:
                    if IsSet(Str) {
                        Extra := '``Options.MaxExtent`` is unset.'
                    } else if Options.MaxExtent {
                        Extra := '``Str`` is unset.'
                    } else {
                        Extra := '``Str`` and ``Options.MaxExtent`` are unset.'
                    }
                    err := UnsetError('``Str`` and ``Options.MaxExtent`` must be set when ``Context`` is a number.', -2, Extra)
            }
            err.What := Fn
            err.Line := Line
            throw err
        }
        _TrimRight() {
            ; Trim whitespace right
            while NumGet(ptr, Pos * 2, 'str') < 33 {
                Pos++
                if Pos > Len {
                    Text := ''
                    return 1
                }
            }
            Text := SubStr(Text, Pos + 1)
        }
        _TrimLeft() {
            while NumGet(ptr, (Pos - 2) * 2, 'str') < 33 {
                Pos--
            }
        }
    }

    class Options {
        static __New() {
            this.DeleteProp('__New')
            proto := this.Prototype
            proto.AdjustObject := false
            proto.BreakChars := '-'
            proto.EndOfLine := '`r`n'
            proto.HyphenateLetters := true
            proto.HyphenateNumbers := true
            proto.MaxExtent := ''
            proto.MeasureLines := false
            proto.MinExtent := ''
            proto.RespectSoftHyphen := true
        }

        __New(options?) {
            if IsSet(options) {
                if IsSet(WrapTextConfig) {
                    for prop in PopupWindow_WrapText.Options.Prototype.OwnProps() {
                        if HasProp(options, prop) {
                            this.%prop% := options.%prop%
                        } else if HasProp(WrapTextConfig, prop) {
                            this.%prop% := WrapTextConfig.%prop%
                        }
                    }
                } else {
                    for prop in PopupWindow_WrapText.Options.Prototype.OwnProps() {
                        if HasProp(options, prop) {
                            this.%prop% := options.%prop%
                        }
                    }
                }
            } else if IsSet(WrapTextConfig) {
                for prop in PopupWindow_WrapText.Options.Prototype.OwnProps() {
                    if HasProp(WrapTextConfig, prop) {
                        this.%prop% := WrapTextConfig.%prop%
                    }
                }
            }
            if this.HasOwnProp('__Class') {
                this.DeleteProp('__Class')
            }
        }
    }
}

class PopupWindow_InsertHyphenationPoints {
    /**
     * @description - {@link PopupWindow_InsertHyphenationPoints} uses a simple heuristic to insert more natural hyphenation
     * points into the input text. {@link PopupWindow_InsertHyphenationPoints} uses character 0x200B, "Zero Width Space".
     * While not every hyphenation point will feel completely natural, the result with {@link PopupWindow_WrapText}
     * will be much more consistent with what people expect regarding hyphenated words. This should
     * be used with strings that consist of mostly English words. Because the heuristic approximates
     * syllable boundaries, {@link PopupWindow_InsertSoftHyphens} is not intended to be used with non-word text.
     * @param {VarRef} Str - This variable should contain the string to have soft hyphens inserted
     * into. It will be modified directly
     * @param {Integer} [Mode = 1] - Either 1 or 2. At this time, don't use 2. It needs more work.
     */
    static Call(&Str, Mode := 1) {
        Str := RegExReplace(Str, this.Pattern[Mode], '${first}' Chr(0x200B) '${second}')
    }
    static GetPattern(which) {
        switch which, 0 {
            case 1: return (
                'iJ)'
                '(?:'
                    '(?<first>' this.vowel ')' this.boundary '(?<second>' this.consonant ')'
                    '|(?<first>' this.consonant ')' this.boundary '(?<second>' this.vowel ')'
                    '|(?<first>' this.vowel this.clusters this.consonant ')' this.boundary '(?<second>' this.consonant ')'
                    '|(?<first>' this.consonant this.vowel ')' this.boundary '(?<second>' this.consonant ')'
                    '|' this.clusters '(?<first>' this.consonant ')' this.boundary '(?<second>' this.consonant this.vowel ')'
                ')'
            )
            case 2: return (
                'iJ)'
                '(?:'
                    '(?<first>' this.vowel ')' this.boundary '(?<second>' this.consonant this.vowel ')'
                    '|(?<first>' this.vowel this.clusters this.consonant ')' this.boundary '(?<second>' this.consonant this.vowel ')'
                    '|(?<first>' this.consonant this.vowel this.clusters this.consonant ')' this.boundary '(?<second>' this.consonant ')'
                ')'
            )
        }
    }
    static Vowel := '[aeiouy]'
    , Consonant := '[bcdfghjklmnpqrstvwz]'
    , Clusters := '(?!th|ch|ph|sh|wh|qu|gh|ck|ng|wr)' ; words should not be split between these
    , Boundary := '(?<!\W|^)(?<!\W.|^.)(?!\W|$)(?!.\W|.$)' ; don't break too close to non-alphanumeric / beginning / end
    , Pattern := [ this.GetPattern(1), this.GetPattern(2) ]
}

class PopupWindow_ControlFitText {
    static __New() {
        this.DeleteProp('__New')
        this.Cache := this.TextExtentPaddingCollection()
    }

    /**
     * @description -  - Resizes a control according to its text contents.
     *
     * Leave the `UseCache` parameter set with `true` to direct {@link PopupWindow_ControlFitText} and
     * {@link PopupWindow_ControlFitText.MaxWidth} to cache the value for each control type, and use the
     * cached value when available.
     *
     * {@link PopupWindow_ControlFitText.TextExtentPadding} is an imperfect approximation of the padding added
     * to a control's area that displays the text. To get the correct dimensions, each control's text
     * content would have to be evaluated individually. However, any discrepencies will likely be
     * unnoticeable, and you can account for discrepencies by adding an additional pixel or two using
     * the `PaddingX` or `PaddingY` parameters. In most cases you shouldn't need to use additional padding.
     * In my tests, the most common problem was edit controls wrapping text when using a vertical scrollbar;
     * a `PaddingX` value of `1` is sufficient in thise case.
     *
     * Not all controls are compatible with {@link PopupWindow_ControlFitText} and {@link PopupWindow_ControlFitText.MaxWidth}.
     * {@link PopupWindow_ControlFitText} will not evaluate the size correctly unless the control satisfies the following
     * conditions:
     * - `Ctrl.Text` must return a string that is the same as the text that is displayed in the gui.
     * - `Ctrl.GetPos`, when called directly after adding a control to a gui, must return the dimensions
     *   of the control that is relevant to the text's bounding rectangle.
     * - `Ctrl.Move` must resize the portion of the control that is relevant to the text's bounding
     *   rectangle.
     *
     * Invalid control types: DateTime, DropDownList, GroupBox, Hotkey, ListBox, ListView, MonthCal,
     * Picture, Progress, Slider, Tab, Tab2, Tab3, TreeView, and UpDown.
     *
     * Valid control types: ActiveX (possibly), Button, CheckBox, ComboBox, Custom (possibly), Edit,
     * Radio, Text.
     *
     * {@link PopupWindow_ControlFitText} returns the width (`OutWidth`) and height (`OutHeight`) for a
     * control to fit its text contents, plus any additional padding.
     *
     * @param {dGui.Control|Gui.Control} Ctrl - The control object.
     * @param {Integer} [PaddingX = 0] - A number of pixels to add to the width.
     * @param {Integer} [PaddingY = 0] - A number of pixels to add to the height.
     * @param {Boolean} [UseCache = true] - If true, stores or retrieves the output from
     * {@link PopupWindow_ControlFitText.TextExtentPadding}. If false, a new instance is evaluated.
     * @param {VarRef} [OutExtentPoints] - A variable that will receive an array of  {@link PopupWindow_Size} objects
     * returned from `GetMultiExtentPoints`.
     * @param {VarRef} [OutWidth] - A variable that will receive the width as integer.
     * @param {VarRef} [OutHeight] - A variable that will receive the height as integer.
     * @param {Boolean} [MoveControl = true] - If true, the `Gui.Control.Prototype.Move` will be
     * called for `Ctrl` using `OutWidth` and `OutHeight`. If false, the calculations are performed
     * without moving the control.
     */
    static Call(Ctrl, PaddingX := 0, PaddingY := 0, UseCache := true, &OutExtentPoints?, &OutWidth?, &OutHeight?, MoveControl := true) {
        OutExtentPoints := StrSplit(RegExReplace(Ctrl.Text, '\R', '`n'), '`n')
        context := PopupWindow_SelectFontIntoDc(Ctrl.Hwnd)
        hdc := context.Hdc
        _Proc()
        context()
        OutHeight := 0
        if UseCache {
            if !this.Cache.Has(Ctrl.Type) {
                this.Cache.Set(Ctrl.Type, this.TextExtentPadding(Ctrl))
            }
            Padding := this.Cache.Get(Ctrl.Type)
        } else {
            Padding := this.TextExtentPadding(Ctrl)
        }
        OutWidth += PaddingX + Padding.W
        for sz in OutExtentPoints {
            if sz {
                OutHeight += sz.H + Padding.LinePadding
            } else {
                OutHeight += Padding.LineHeight
            }
        }
        OutHeight += PaddingY + Padding.H + Padding.LinePadding * OutExtentPoints.Length
        if MoveControl {
            Ctrl.Move(, , OutWidth, OutHeight)
        }

        return

        _Proc() {
            local sz
            OutWidth := 0
            for Str in OutExtentPoints {
                if Str {
                    if DllCall('Gdi32.dll\GetTextExtentPoint32'
                        , 'Ptr', hdc
                        , 'Ptr', StrPtr(Str)
                        , 'Int', StrLen(Str)
                        , 'Ptr', sz := PopupWindow_Size()
                        , 'Int'
                    ) {
                        OutExtentPoints[A_Index] := sz
                        OutWidth := Max(OutWidth, sz.W)
                    } else {
                        throw OSError()
                    }
                }
            }
        }
    }

    /**
     * @description - {@link PopupWindow_ControlFitText.MaxWidth} resizes a control to fit the text contents of the
     * control plus any additional padding while limiting the width of the control to a maximum value.
     * Note that {@link PopupWindow_ControlFitText.MaxWidth} does not include the width value when calling `Ctrl.Move`;
     * it is assumed your code has handled setting the width.
     *
     * @param {dGui.Control} Ctrl - The control object. See the notes in the class description above
     * {@link PopupWindow_ControlFitText} for compatibility requirements.
     * @param {Integer} [MaxWidth] - The maximum width in pixels. If unset, uses the controls current
     * width.
     * @param {Integer} [PaddingX = 0] - A number of pixels to add to the width.
     * @param {Integer} [PaddingY = 0] - A number of pixels to add to the height.
     * @param {Boolean} [UseCache = true] - If true, stores or retrieves the output from
     * {@link PopupWindow_ControlFitText.TextExtentPadding}. If false, a new instance is evaluated.
     * @param {VarRef} [OutExtentPoints] - A variable that will receive an array of  {@link PopupWindow_Size} objects
     * returned from `GetMultiExtentPoints`.
     * @param {VarRef} [OutHeight] - A variable that will receive an integer value representing the
     * height that was passed to `Ctrl.Move`.
     * @param {Boolean} [MoveControl = true] - If true, the `Gui.Control.Prototype.Move` will be
     * called for `Ctrl` using `OutHeight`. If false, the calculations are performed without moving
     * the control.
     */
    static MaxWidth(Ctrl, MaxWidth?, PaddingX := 0, PaddingY := 0, UseCache := true, &OutExtentPoints?, &OutHeight?, MoveControl := true) {
        OutExtentPoints := StrSplit(RegExReplace(Ctrl.Text, '\R', '`n'), '`n')
        context := PopupWindow_SelectFontIntoDc(Ctrl.Hwnd)
        hdc := context.Hdc
        _Proc()
        context()
        if !IsSet(MaxWidth) {
            Ctrl.GetPos(, , &MaxWidth)
        }
        if UseCache {
            if !this.Cache.Has(Ctrl.Type) {
                this.Cache.Set(Ctrl.Type, this.TextExtentPadding(Ctrl))
            }
            Padding := this.Cache.Get(Ctrl.Type)
        } else {
            Padding := this.TextExtentPadding(Ctrl)
        }
        MaxWidth -= Padding.W + PaddingX
        OutHeight := PaddingY + Padding.H
        for sz in OutExtentPoints {
            if sz {
                lines := Ceil(sz.W / MaxWidth)
                OutHeight += (sz.H + Padding.LinePadding) * lines
            } else {
                OutHeight += Padding.LineHeight
            }
        }
        if MoveControl {
            Ctrl.Move(, , , OutHeight)
        }

        return

        _Proc() {
            local sz
            OutWidth := 0
            for Str in OutExtentPoints {
                if Str {
                    if DllCall('Gdi32.dll\GetTextExtentPoint32'
                        , 'Ptr', hdc
                        , 'Ptr', StrPtr(Str)
                        , 'Int', StrLen(Str)
                        , 'Ptr', sz := PopupWindow_Size()
                        , 'Int'
                    ) {
                        OutExtentPoints[A_Index] := sz
                        OutWidth := Max(OutWidth, sz.W)
                    } else {
                        throw OSError()
                    }
                }
            }
        }
    }

    class TextExtentPadding {
        /**
         * An instance of {@link PopupWindow_ControlFitText.TextExtentPadding} has four properties:
         * - {@link PopupWindow_ControlFitText.TextExtentPadding#W} - The padding added to the text's extent
         * along the X axis.
         * - {@link PopupWindow_ControlFitText.TextExtentPadding#H} - The padding added to the text's extent
         * along the Y axis, not including the padding added for each individual line.
         * - {@link PopupWindow_ControlFitText.TextExtentPadding#LinePadding} - The padding added to the text's
         * extent along the Y axis for each individual line.
         * - {@link PopupWindow_ControlFitText.TextExtentPadding#LineHeight} - The approximate height of an
         * blank line.
         *
         * The values of each property are approximations. See the description above
         * {@link PopupWindow_ControlFitText} for more details and limitations.
         * @class
         *
         * @param {dGui.Control} Ctrl - The control object.
         * @param {String} [Opt = ""] - Options to pass to `Gui.Prototype.Add`.
         * @param {Integer} [ThreadDpiAwarenessContext] - If set, {@link PopupWindow_ControlFitText.TextExtentPadding.__New}
         * calls `SetThreadDpiAwarenessContext` at the beginning, and calls it again before returning
         * to set the thread's context to its original value.
         */
        __New(Ctrl, Opt := '', ThreadDpiAwarenessContext?) {
            if IsSet(ThreadDpiAwarenessContext) {
                originalContext := DllCall('SetThreadDpiAwarenessContext', 'ptr', ThreadDpiAwarenessContext, 'ptr')
            }
            lf := PopupWindow_Logfont(Ctrl.Hwnd)
            G := Gui()
            fontOpt := 's' lf.FontSize ' w' lf.Weight
            if lf.Quality {
                fontOpt .= ' q' lf.Quality
            }
            if lf.Italic {
                fontOpt .= ' italic'
            }
            if lf.StrikeOut {
                fontOpt .= ' strike'
            }
            if lf.Underline {
                fontOpt .= ' underline'
            }
            G.SetFont(fontOpt, lf.FaceName)
            _ctrl := G.Add(Ctrl.Type, Opt, 'line')
            _ctrl.GetPos(, , , &h)
            _ctrl2 := G.Add(Ctrl.Type, Opt, 'line`r`nline')
            _ctrl2.GetPos(, , &w2, &h2)
            sz := _Proc(_ctrl)
            sz2 := _Proc(_ctrl2)
            G.Destroy()
            this.W := w2 - sz2.W
            this.H := h - sz.H
            this.LinePadding := h2 - sz2.H - h + sz.H
            this.LineHeight := (h2 - this.H) / 2
            if IsSet(originalContext) {
                DllCall('SetThreadDpiAwarenessContext', 'ptr', originalContext, 'ptr')
            }

            return

            _Proc(Ctrl) {
                local sz, h, w
                W := H := 0

                lines := StrSplit(RegExReplace(Ctrl.Text, '\R', '`n'), '`n')
                context := PopupWindow_SelectFontIntoDc(Ctrl.Hwnd)
                for line in lines {
                    if line {
                        if DllCall('Gdi32.dll\GetTextExtentPoint32', 'Ptr', context.hdc, 'Ptr', StrPtr(line), 'Int', StrLen(line), 'Ptr', sz := PopupWindow_Size(), 'Int') {
                            H += sz.H
                            W := Max(W, sz.W)
                            lines[A_Index] := sz

                        } else {
                            context()
                            throw OSError()
                        }
                    }
                }
                context()
                return { H: H, Lines: Lines, W: W }
            }
        }
    }

    class TextExtentPaddingCollection extends Map {
    }
}

class PopupWindow_Logfont {
    static __New() {
        this.DeleteProp('__New')
        Proto := this.Prototype
        Proto.Encoding := 'cp1200'
        Proto.Handle := Proto.Hwnd := 0
        Proto.CbSizeInstance :=
        4 + ; LONG  lfHeight                    0
        4 + ; LONG  lfWidth                     4
        4 + ; LONG  lfEscapement                8
        4 + ; LONG  lfOrientation               12
        4 + ; LONG  lfWeight                    16
        1 + ; BYTE  lfItalic                    20
        1 + ; BYTE  lfUnderline                 21
        1 + ; BYTE  lfStrikeOut                 22
        1 + ; BYTE  lfCharSet                   23
        1 + ; BYTE  lfOutPrecision              24
        1 + ; BYTE  lfClipPrecision             25
        1 + ; BYTE  lfQuality                   26
        1 + ; BYTE  lfPitchAndFamily            27
        64  ; WCHAR lfFaceName[LF_FACESIZE]     28
    }
    /**
     * @description - A wrapper around the LOGFONT structure.
     * {@link https://learn.microsoft.com/en-us/windows/win32/api/dimm/ns-dimm-logfontw}
     * @class
     *
     * @param {Integer} [Hwnd] - The window handle to associate with the `Logfont` object. If
     * set, {@link PopupWindow_Logfont.Prototype.Call} is called, filling the structure with the values
     * associated with the window. If unset, the buffer is filled with 0.
     * @param {String} [Encoding] - The encoding used when getting and setting string values associated
     * with LOGFONT members. The default encoding used by `Logfont` objects is UTF-16 (cp1200).
     */
    __New(Hwnd?, Encoding?) {
        /**
         * A reference to the buffer object which is used as the LOGFONT structure.
         * @memberof Logfont
         * @instance
         */
        this.Buffer := Buffer(this.CbSizeInstance, 0)
        if IsSet(Encoding) {
            /**
             * The encoding to use with `StrPut` and `StrGet` when handling strings.
             * @memberof Logfont
             * @instance
             */
            this.Encoding := Encoding
        }
        if IsSet(Hwnd) {
            /**
             * The handle to the window associated with this object, if any.
             * @memberof Logfont
             * @instance
             */
            this.Hwnd := Hwnd
            this()
        }
    }
    /**
     * @description - Calls `CreateFontIndirectW` then sends WM_SETFONT to the window associated
     * with this `Logfont` object.
     * @param {Boolean} [Redraw = true] - The value to pass to the `lParam` parameter when sending
     * WM_SETFONT. If true, the control redraws itself.
     */
    Apply(Redraw := true) {
        hFontOld := SendMessage(0x0031,,, this.Hwnd) ; WM_GETFONT
        Flag := this.Handle = hFontOld
        /**
         * The handle to the font object created by this object.
         * @memberof Logfont
         * @instance
         */
        this.Handle := DllCall('CreateFontIndirectW', 'ptr', this, 'ptr')
        SendMessage(0x0030, this.Handle, Redraw, this.Hwnd) ; WM_SETFONT
        if Flag {
            DllCall('DeleteObject', 'ptr', hFontOld, 'int')
        }
    }
    /**
     * @description - Sends WM_GETFONT to the window associated with this `Logfont` object, updating
     * this object's properties with the values obtained from the window.
     * @throws {OSError} - Failed to get font object.
     */
    Call(*) {
        if !DllCall(
            'Gdi32.dll\GetObject',
            'ptr', SendMessage(0x0031,,, this.Hwnd), ; WM_GETFONT
            'int', this.Size,
            'ptr', this,
            'uint'
        ) {
            throw OSError('Failed to get font object.')
        }
    }
    __Delete() {
        if this.Handle {
            DllCall('DeleteObject', 'ptr', this.Handle)
            this.Handle := 0
        }
    }
    /**
     * Gets or sets the character set.
     * @memberof Logfont
     * @instance
     */
    CharSet {
        Get => NumGet(this, 23, 'uchar')
        Set => NumPut('uchar', Value, this, 23)
    }
    /**
     * Gets or sets the behavior when part of a character is clipped.
     * @memberof Logfont
     * @instance
     */
    ClipPrecision {
        Get => NumGet(this, 25, 'uchar')
        Set => NumPut('uchar', Value, this, 25)
    }
    /**
     * If this `Logfont` object is associated with a window, returns the dpi for the window.
     * @memberof Logfont
     * @instance
     */
    Dpi => this.Hwnd ? DllCall('GetDpiForWindow', 'Ptr', this.Hwnd, 'UInt') : ''
    /**
     * Gets or sets the escapement measured in tenths of a degree.
     * @memberof Logfont
     * @instance
     */
    Escapement {
        Get => NumGet(this, 8, 'int')
        Set => NumPut('int', Value, this, 8)
    }
    /**
     * Gets or sets the font facename.
     * @memberof Logfont
     * @instance
     */
    FaceName {
        Get => StrGet(this.ptr + 28, 32, this.Encoding)
        Set => StrPut(SubStr(Value, 1, 31), this.Ptr + 28, 32, this.Encoding)
    }
    /**
     * Gets or sets the font family.
     * @memberof Logfont
     * @instance
     */
    Family {
        Get => NumGet(this, 27, 'uchar') & 0xF0
        Set => NumPut('uchar', (this.Family & 0x0F) | (Value & 0xF0), this, 27)
    }
    /**
     * Gets or sets the font size. "FontSize" requires that the `Logfont` object is associated
     * with a window handle because it needs a dpi value to work with.
     * @memberof Logfont
     * @instance
     */
    FontSize {
        Get => this.Hwnd ? Round(this.Height * -72 / this.Dpi, 2) : ''
        Set => this.Height := Round(Value * this.Dpi / -72)
    }
    /**
     * Gets or sets the font height.
     * @memberof Logfont
     * @instance
     */
    Height {
        Get => NumGet(this, 0, 'int')
        Set => NumPut('int', Value, this, 0)
    }
    /**
     * Gets or sets the italic flag.
     * @memberof Logfont
     * @instance
     */
    Italic {
        Get => NumGet(this, 20, 'uchar')
        Set => NumPut('uchar', Value ? 1 : 0, this, 20)
    }
    /**
     * Gets or sets the orientation measured in tenths of degrees.
     * @memberof Logfont
     * @instance
     */
    Orientation {
        Get => NumGet(this, 12, 'int')
        Set => NumPut('int', Value, this, 12)
    }
    /**
     * Gets or sets the behavior when multiple fonts with the same name exist on the system.
     * @memberof Logfont
     * @instance
     */
    OutPrecision {
        Get => NumGet(this, 24, 'uchar')
        Set => NumPut('uchar', Value, this, 24)
    }
    /**
     * Gets or sets the pitch.
     * @memberof Logfont
     * @instance
     */
    Pitch {
        Get => NumGet(this, 27, 'uchar') & 0x0F
        Set => NumPut('uchar', (this.Pitch & 0xF0) | (Value & 0x0F), this, 27)
    }
    /**
     * Returns the pointer to the buffer.
     * @memberof Logfont
     * @instance
     */
    Ptr => this.Buffer.Ptr
    /**
     * Gets or sets the quality flag.
     * @memberof Logfont
     * @instance
     */
    Quality {
        Get => NumGet(this, 26, 'uchar')
        Set => NumPut('uchar', Value, this, 26)
    }
    /**
     * Returns the buffer's size in bytes.
     * @memberof Logfont
     * @instance
     */
    Size => this.Buffer.Size
    /**
     * Gets or sets the strikeout flag.
     * @memberof Logfont
     * @instance
     */
    StrikeOut {
        Get => NumGet(this, 22, 'uchar')
        Set => NumPut('uchar', Value ? 1 : 0, this, 22)
    }
    /**
     * Gets or sets the underline flag.
     * @memberof Logfont
     * @instance
     */
    Underline {
        Get => NumGet(this, 21, 'uchar')
        Set => NumPut('uchar', Value ? 1 : 0, this, 21)
    }
    /**
     * Gets or sets the weight flag.
     * @memberof Logfont
     * @instance
     */
    Weight {
        Get => NumGet(this, 16, 'int')
        Set => NumPut('int', Value, this, 16)
    }
    /**
     * Gets or sets the width.
     * @memberof Logfont
     * @instance
     */
    Width {
        Get => NumGet(this, 4, 'int')
        Set => NumPut('int', Value, this, 4)
    }
}

/**
 * @description - Calculates the optimal position to move one rectangle adjacent to another while
 * ensuring that the `Subject` rectangle stays within the monitor's work area. The properties
 * { L, T, R, B } of `Subject` are updated with the new values.
 *
 * @example
 * ; Assume I have Edge and VLC open
 * rcSub := WinRect(WinGetId("ahk_exe msedge.exe"))
 * rcTar := WinRect(WinGetId("ahk_exe vlc.exe"))
 * rcSub.MoveAdjacent(rcTar)
 * rcSub.Apply()
 * @
 *
 * @param {*} Subject - The object representing the rectangle that will be moved. This can be an
 * instance of `Rect` or any class that inherits from `Rect`, or any object with properties
 * { L, T, R, B }. Those four property values will be updated with the result of this function call.
 *
 * @param {*} [Target] - The object representing the rectangle that will be used as reference. This
 * can be an instance of `Rect` or any class that inherits from `Rect`, or any object with properties
 * { L, T, R, B }. If unset, the mouse's current position relative to the screen is used. To use
 * a point instead of a rectangle, set the properties "L" and "R" equivalent to one another, and
 * "T" and "B" equivalent to one another.
 *
 * @param {*} [ContainerRect] - If set, `ContainerRect` defines the boundaries which restrict
 * the area that the window is permitted to be moved within. The object must have poperties
 * { L, T, R, B } to be valid. If unset, the work area of the monitor with the greatest area of
 * intersection with `Target` is used.
 *
 * @param {String} [Dimension = "X"] - Either "X" or "Y", specifying if the window is to be moved
 * adjacent to `Target` on either the X or Y axis. If "X", `Subject` is moved to the left or right
 * of `Target`, and `Subject`'s vertical center is aligned with `Target`'s vertical center. If "Y",
 * `Subject` is moved to the top or bottom of `Target`, and `Subject`'s horizontal center is aligned
 * with `Target`'s horizontal center.
 *
 * @param {String} [Prefer = ""] - A character indicating a preferred side. If `Prefer` is an
 * empty string, the function will move the window to the side the has the greatest amount of
 * space between the monitor's border and `Target`. If `Prefer` is any of the following values,
 * the window will be moved to that side unless doing so would cause the the window to extend
 * outside of the monitor's work area.
 * - "L" - Prefers the left side.
 * - "T" - Prefers the top side.
 * - "R" - Prefers the right side.
 * - "B" - Prefes the bottom.
 *
 * @param {Number} [Padding = 0] - The amount of padding to leave between `Subject` and `Target`.
 *
 * @param {Integer} [InsufficientSpaceAction = 0] - Determines the action taken if there is
 * insufficient space to move the window adjacent to `Target` while also keeping the window
 * entirely within the monitor's work area. The function will always sacrifice some of the padding
 * if it will allow the window to stay within the monitor's work area. If the space is still
 * insufficient, the action can be one of the following:
 * - 0 : The function will not move the window.
 * - 1 : The function will move the window, allowing the window's area to extend into a non-visible
 *   region of the monitor.
 * - 2 : The function will move the window, keeping the window's area within the monitor's work
 *   area by allowing the window to overlap with `Target`.
 *
 * @returns {Integer} - If the insufficient space action was invoked, returns 1. Else, returns 0.
 */
PopupWindow_MoveAdjacent(Subject, Target?, ContainerRect?, Dimension := 'X', Prefer := '', Padding := 0, InsufficientSpaceAction := 0) {
    Result := 0
    if IsSet(Target) {
        tarL := Target.L
        tarT := Target.T
        tarR := Target.R
        tarB := Target.B
    } else {
        mode := CoordMode('Mouse', 'Screen')
        MouseGetPos(&tarL, &tarT)
        tarR := tarL
        tarB := tarT
        CoordMode('Mouse', mode)
    }
    tarW := tarR - tarL
    tarH := tarB - tarT
    if IsSet(ContainerRect) {
        monL := ContainerRect.L
        monT := ContainerRect.T
        monR := ContainerRect.R
        monB := ContainerRect.B
        monW := monR - monL
        monH := monB - monT
    } else {
        buf := Buffer(16)
        NumPut('int', tarL, 'int', tarT, 'int', tarR, 'int', tarB, buf)
        Hmon := DllCall('MonitorFromRect', 'ptr', buf, 'uint', 0x00000002, 'ptr')
        mon := Buffer(40)
        NumPut('int', 40, mon)
        if !DllCall('GetMonitorInfo', 'ptr', Hmon, 'ptr', mon, 'int') {
            throw OSError()
        }
        monL := NumGet(mon, 20, 'int')
        monT := NumGet(mon, 24, 'int')
        monR := NumGet(mon, 28, 'int')
        monB := NumGet(mon, 32, 'int')
        monW := monR - monL
        monH := monB - monT
    }
    subL := Subject.L
    subT := Subject.T
    subR := Subject.R
    subB := Subject.B
    subW := subR - subL
    subH := subB - subT
    if Dimension = 'X' {
        if Prefer = 'L' {
            if tarL - subW - Padding >= monL {
                X := tarL - subW - Padding
            } else if tarL - subW >= monL {
                X := monL
            }
        } else if Prefer = 'R' {
            if tarR + subW + Padding <= monR {
                X := tarR + Padding
            } else if tarR + subW <= monR {
                X := monR - subW
            }
        } else if Prefer {
            throw _ValueError('Prefer', Prefer)
        }
        if !IsSet(X) {
            flag_nomove := false
            X := _Proc(subW, subL, subR, tarW, tarL, tarR, monW, monL, monR, Prefer = 'L' ? 1 : Prefer = 'R' ? -1 : 0)
            if flag_nomove {
                return Result
            }
        }
        Y := tarT + tarH / 2 - subH / 2
        if Y + subH > monB {
            Y := monB - subH
        } else if Y < monT {
            Y := monT
        }
    } else if Dimension = 'Y' {
        if Prefer = 'T' {
            if tarT - subH - Padding >= monT {
                Y := tarT - subH - Padding
            } else if tarT - subH >= monT {
                Y := monT
            }
        } else if Prefer = 'B' {
            if tarB + subH + Padding <= monB {
                Y := tarB + Padding
            } else if tarB + subH <= monB {
                Y := monB - subH
            }
        } else if Prefer {
            throw _ValueError('Prefer', Prefer)
        }
        if !IsSet(Y) {
            flag_nomove := false
            Y := _Proc(subH, subT, subB, tarH, tarT, tarB, monH, monT, monB, Prefer = 'T' ? 1 : Prefer = 'B' ? -1 : 0)
            if flag_nomove {
                return Result
            }
        }
        X := tarL + tarW / 2 - subW / 2
        if X + subW > monR {
            X := monR - subW
        } else if X < monL {
            X := monL
        }
    } else {
        throw _ValueError('Dimension', Dimension)
    }
    Subject.L := X
    Subject.T := Y
    Subject.R := X + subW
    Subject.B := Y + subH

    return Result

    _Proc(SubLen, SubMainSide, SubAltSide, TarLen, TarMainSide, TarAltSide, MonLen, MonMainSide, MonAltSide, Prefer) {
        if TarMainSide - MonMainSide > MonAltSide - TarAltSide {
            if TarMainSide - SubLen - Padding >= MonMainSide {
                return TarMainSide - SubLen - Padding
            } else if TarMainSide - SubLen >= MonMainSide {
                return MonMainSide + TarMainSide - SubLen
            } else {
                Result := 1
                switch InsufficientSpaceAction, 0 {
                    case 0: flag_nomove := true
                    case 1: return TarMainSide - SubLen
                    case 2: return MonMainSide
                    default: throw _ValueError('InsufficientSpaceAction', InsufficientSpaceAction)
                }
            }
        } else if TarAltSide + SubLen + Padding <= MonAltSide {
            return TarAltSide + Padding
        } else if TarAltSide + SubLen <= MonAltSide {
            return MonAltSide - TarAltSide + SubLen
        } else {
            Result := 1
            switch InsufficientSpaceAction, 0 {
                case 0: flag_nomove := true
                case 1: return TarAltSide
                case 2: return MonAltSide - SubLen
                default: throw _ValueError('InsufficientSpaceAction', InsufficientSpaceAction)
            }
        }
    }
    _ValueError(name, Value) {
        if IsObject(Value) {
            return TypeError('Invalid type passed to ``' name '``.', -2)
        } else {
            return ValueError('Unexpected value passed to ``' name '``.', -2, Value)
        }
    }
}

/**
 * @description - Calculates the optimal position to a window adjacent to the mouse's current
 * position, ensuring that the window stays within the monitor's work area. The object passed to
 * `Subject` is updated to reflect the resulting position. If successful, the window is moved to the
 * new position.
 *
 * @param {*} Subject - The object representing the window that will be moved. This can be an
 * instance of `Rect` or any class that inherits from `Rect`, or any object with properties
 * { L, T, R, B }. Those four property values will be updated with the result of this function call.
 *
 * @param {*} [ContainerRect] - If set, `ContainerRect` defines the boundaries which restrict
 * the area that the window is permitted to be moved within. The object must have poperties
 * { L, T, R, B } to be valid. If unset, the work area of the monitor which contains the mouse
 * pointer is used.
 *
 * @param {String} [Dimension = "X"] - Either "X" or "Y", specifying if the window is centered with
 * the mouse's position along the X or Y axis. If "X", `Subject`'s vertical center is aligned with the
 * mouse's position. If "Y", `Subject`'s horizontal center is aligned with the mouse's position.
 *
 * @param {String} [Prefer = ""] - A character indicating a preferred side. If `Prefer` is an
 * empty string, the function will move the window to the side the has the greatest amount of
 * space between the monitor's border and the mouse. If `Prefer` is any of the following values,
 * the window will be moved to that side unless doing so would cause the the window to extend
 * outside of the monitor's work area.
 * - "L" - Prefers the left side.
 * - "T" - Prefers the top side.
 * - "R" - Prefers the right side.
 * - "B" - Prefes the bottom.
 *
 * @param {Number} [Padding = 0] - The amount of padding to leave between `Subject` and the mouse.
 *
 * @param {Integer} [InsufficientSpaceAction = 0] - Determines the action taken if there is
 * insufficient space to move the window adjacent to the mouse while also keeping the window
 * entirely within the monitor's work area. The function will always sacrifice some of the padding
 * if it will allow the window to stay within the monitor's work area. If the space is still
 * insufficient, the action can be one of the following:
 * - 0 : The function will not move the window.
 * - 1 : The function will move the window, allowing the window's area to extend into a non-visible
 *   region of the monitor.
 * - 2 : The function will move the window, keeping the window's area within the monitor's work
 *   area by allowing the window to overlap with the mouse.
 *
 * @param {VarRef} [OutRect] - A variable that will receive a reference to the {@link PopupWindow_Rect}
 * object representing the window's dimensions.
 *
 * @returns {Integer} - If the insufficient space action was invoked, returns 1. Else, returns 0.
 */
PopupWindow_MoveByMouse(Hwnd, ContainerRect?, Dimension := 'X', Prefer := '', Padding := 0, InsufficientSpaceAction := 0, &OutRect?) {
    OutRect := PopupWindow_Rect()
    if HRESULT := DllCall('Dwmapi\DwmGetWindowAttribute', 'ptr', Hwnd, 'uint', 9, 'ptr', OutRect, 'uint', 16, 'uint') {
        throw OSError('``DwmGetWindowAttribute`` failed.', , 'HRESULT: ' Format('{:X}', HRESULT))
    }
    CoordMode('Mouse', 'Screen')
    MouseGetPos(&x, &y)
    result := PopupWindow_MoveAdjacent(OutRect, { L: x, T: y, R: x, B: y }, ContainerRect ?? unset, Dimension, Prefer, Padding, InsufficientSpaceAction)
    if !result || InsufficientSpaceAction {
        WinMove(OutRect.L, OutRect.T, , , Hwnd)
    }
    return result
}

class PopupWindow_Rect extends Buffer {
    static __New() {
        this.DeleteProp('__New')
        proto := this.Prototype
        proto.offset_l := 0
        proto.offset_t := 4
        proto.offset_r := 8
        proto.offset_b := 12
    }
    __New(L?, T?, R?, B?) {
        this.Size := 16
        if IsSet(L) {
            this.L := L
        }
        if IsSet(T) {
            this.T := T
        }
        if IsSet(R) {
            this.R := R
        }
        if IsSet(B) {
            this.B := B
        }
    }
    ToClient(hwndParent) {
        if !DllCall('ScreenToClient', 'ptr', hwndParent, 'ptr', this, 'int') {
            throw OSError()
        }
        if !DllCall('ScreenToClient', 'ptr', hwndParent, 'ptr', this.Ptr + 8, 'int') {
            throw OSError()
        }
    }
    ToScreen(hwndParent) {
        if !DllCall('ClientToScreen', 'ptr', hwndParent, 'ptr', this, 'int') {
            throw OSError()
        }
        if !DllCall('ClientToScreen', 'ptr', hwndParent, 'ptr', this.Ptr + 8, 'int') {
            throw OSError()
        }
    }
    L {
        Get => NumGet(this, this.offset_l, 'int')
        Set => NumPut('int', Value, this, this.offset_l)
    }
    T {
        Get => NumGet(this, this.offset_t, 'int')
        Set => NumPut('int', Value, this, this.offset_t)
    }
    R {
        Get => NumGet(this, this.offset_r, 'int')
        Set => NumPut('int', Value, this, this.offset_r)
    }
    B {
        Get => NumGet(this, this.offset_b, 'int')
        Set => NumPut('int', Value, this, this.offset_b)
    }
    X {
        Get => NumGet(this, this.offset_l, 'int')
        Set => NumPut('int', Value, this, this.offset_l)
    }
    Y {
        Get => NumGet(this, this.offset_t, 'int')
        Set => NumPut('int', Value, this, this.offset_t)
    }
    W {
        Get => NumGet(this, 8, 'int') - NumGet(this, 0, 'int')
        Set => NumPut('int', NumGet(this, this.offset_l, 'int') + Value, this, this.offset_r)
    }
    H {
        Get => NumGet(this, 12, 'int') - NumGet(this, 4, 'int')
        Set => NumPut('int', NumGet(this, this.offset_t, 'int') + Value, this, this.offset_b)
    }
}
