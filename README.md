# AutoHotkey-WinMover
An AutoHotkey (AHK) script that makes it super easy to move / resize windows and controls.

# Introduction

`WinMover` provides the following functionality:
- Click-and-drag to resize the window beneath the mouse cursor.
- Click-and-drag to move the window beneath the mouse cursor.
- Click-and-drag to resize the control beneath the mouse cursor.
- Click-and-drag to move the control beneath the mouse cursor.
- Press a key chord combination to move and resize the currently active window to a predefined configuration.

# AutoHotkey.com post

Join the conversation on [AutoHotkey.com](https://www.autohotkey.com/boards/viewtopic.php?f=83&t=126656&p=560974#p560974)

# Reddit.com post

Join the conversation on [Reddit.com](https://www.reddit.com/r/AutoHotkey/comments/1q1myw9/winmover_enable_global_clickanddrag_resizing/)

# Example

![gif depicting functionality](https://raw.githubusercontent.com/Nich-Cebolla/AutoHotkey-WinMover/refs/heads/main/resources/example.gif)

# Setup

- Clone the repository.
  ```cmd
  git clone https://github.com/Nich-Cebolla/AutoHotkey-WinMover
  ```
- Copy AutoHotkey-WinMover\src\WinMover.ahk to your [lib folder](https://www.autohotkey.com/docs/v2/Scripts.htm#lib).
  ```cmd
  xcopy AutoHotkey-WinMover\src\WinMover.ahk %USERPROFILE%\Documents\AutoHotkey\Lib\WinMover.ahk
  ```
- Prepare a script that creates hotkeys to call methods from the object. See below.

# Preparing the script

Copy templates\template.ahk and open it in your code editor. That file contains:

```ahk
#include <WinMover>
#Requires AutoHotkey v2.0
#SingleInstance force

SetWinDelay 50

global WinMoverObj := WinMover(
    'CHORDMODIFIER'
  , Map(
        1, { X: 0, Y: 0, W: 0.5, H: 1 } ; left-half
      , 2, { X: 0.5, Y: 0, W: 0.5, H: 1 } ; right-half
      , 3, { X: 0, Y: 0, W: 1, H: 1 } ; full-screen
      , 'q', { X: 0, Y: 0, W: 0.5, H: 0.5 } ; top-left quarter
      , 'w', { X: 0.5, Y: 0, W: 0.5, H: 0.5 } ; top-right quarter
      , 'a', { X: 0, Y: 0.5, W: 0.5, H: 0.5 } ; bottom-left quarter
      , 's', { X: 0.5, Y: 0.5, W: 0.5, H: 0.5 } ; bottom-right quarter
    )
)

; Use only one set

MOD1 & RButton::WinMoverObj.DynamicResize()
MOD1 & LButton::WinMoverObj.DynamicMove()

CapsLock & RButton::WinMoverObj.DynamicResize_CapsLock()
CapsLock & LButton::WinMoverObj.DynamicMove_CapsLock()

; Use only one set

MOD2 & RButton::WinMoverObj.DynamicResizeControl()
MOD2 & LButton::WinMoverObj.DynamicMoveControl()

CapsLock & RButton::WinMoverObj.DynamicResizeControl_CapsLock()
CapsLock & LButton::WinMoverObj.DynamicMoveControl_CapsLock()

```

Overwrite "CHORDMODIFIER" with whatever modifier key you want to use with key chords.

You only need one set of each group. If you use CapsLock as a modifier key, use the methods that end in "_CapsLock" and delete the other set. Overwrite "MOD#" with the actual modifier key. Once finished, run the script and try it out.

# About the methods

The methods were inspired by the [Easy Window Dragging (KDE style)](https://www.autohotkey.com/docs/v2/scripts/index.htm#EasyWindowDrag_(KDE)) example provided in the AHK official docs. There were some issues with the original, so I fixed those. I also expanded it to also work with window controls, and added in the key-chord functionality.

## Moving / resizing a window under the mouse cursor

While holding the modifier key, left-click and drag the window to move the window.

While holding the modifier key, right-click and drag the window to resize the window.

## Moving / resizing a control under the mouse cursor

While holding the modifier key, left-click and drag the window to move the control. This may not work as expected for all controls, particularly if the control is a WebView2 (or similar) implementation.

While holding the modifier key, right-click and drag the window to resize the control. This may not work as expected for all controls, particularly if the control is a WebView2 (or similar) implementation.

## Key chords

"Chord" and "Chord_CapsLock" are designed to allow the user to specify a monitor using a number key, then specify an action afterward. The built-in options are:
- 1 : Moves the currently active window to occupy the left half of the monitor's work area.
- 2 : Moves the currently active window to occupy the right half of the monitor's work area.
- 3 : Moves the currently active window to occupy the entire monitor's work area.

For example, say I have three monitors. Say I want to move the active window to the left side of the second monitor. To accomplish that, I:
1. Press and hold the modifier.
2. Press and release 2.
3. Press and release 1.
4. Release the modifier.

To move the active window to occupy the entirety of monitor 1, I:
1. Press and hold the modifier.
2. Press and release 1.
3. Press and release 3.
4. Release the modifier.

You can expand the built-in configurations by defining a map object and passing it to the "Presets" parameter of `WinMover.Prototype.__New`. The map keys correspond to the second key of the key chord. The map values are objects specifying the target position and size of the currently active window.

The objects have properties `{ X, Y, W, H }`. Each property value is a quotient that is multiplied with the monitor's corresponding value.

For example, if my object is `{ X: 0, Y: 0, W: 1, H: 1 }`, then the window will be moved to the top-left corner of the monitor and the window will be resized to occupy the monitor's entire work area.

If my object is `{ X: 0.5, Y: 0, W: 0.5, H: 1 }`, then the window will be moved to the top-center position of the monitor's work area, and the window will be resized to occupy the right-half of the monitor's work area.

For example, here is the default map object:
```ahk
Presets := Map(
    1, { X: 0, Y: 0, W: 0.5, H: 1 } ; left-half
  , 2, { X: 0.5, Y: 0, W: 0.5, H: 1 } ; right-half
  , 3, { X: 0, Y: 0, W: 1, H: 1 } ; full-screen
)
```

`obj.X` gets multiplied by the left coordinate of the monitor's work area, and that becomes the x coordinate of the window.
`obj.Y` gets multiplied by the top coordinate of the monitor's work area, and that becomes the y coordinate of the window.
`obj.W` gets multiplied by the width of the monitor's work area, and that becomes the width of the window.
`obj.H` gets multiplied by the height of the monitor's work area, and that becomes the height of the window.

If I wanted to be able to tile the windows using 1/4 of the monitor's work area, I would add objects like this:
```ahk
Presets := Map(
    1, { X: 0, Y: 0, W: 0.5, H: 1 } ; left-half
  , 2, { X: 0.5, Y: 0, W: 0.5, H: 1 } ; right-half
  , 3, { X: 0, Y: 0, W: 1, H: 1 } ; full-screen
  , 4, { X: 0, Y: 0, W: 0.5, H: 0.5 } ; top-left quarter
  , 5, { X: 0.5, Y: 0, W: 0.5, H: 0.5 } ; top-right quarter
  , 6, { X: 0, Y: 0.5, W: 0.5, H: 0.5 } ; bottom-left quarter
  , 7, { X: 0.5, Y: 0.5, W: 0.5, H: 0.5 } ; bottom-right quarter
)
```

The key does not have to be a number. The following is also valid:
```ahk
Presets := Map(
    1, { X: 0, Y: 0, W: 0.5, H: 1 } ; left-half
  , 2, { X: 0.5, Y: 0, W: 0.5, H: 1 } ; right-half
  , 3, { X: 0, Y: 0, W: 1, H: 1 } ; full-screen
  , 'q', { X: 0, Y: 0, W: 0.5, H: 0.5 } ; top-left quarter
  , 'w', { X: 0.5, Y: 0, W: 0.5, H: 0.5 } ; top-right quarter
  , 'a', { X: 0, Y: 0.5, W: 0.5, H: 0.5 } ; bottom-left quarter
  , 's', { X: 0.5, Y: 0.5, W: 0.5, H: 0.5 } ; bottom-right quarter
)
```

## Specifying a monitor

The monitors are selected using their relative position, **not** the monitor number as defined by the operating system. The primary monitor is always 1. Then, the top-left monitor is next, and it proceeds in left-right, top-down order. I found this to be more intuitive as a user of the function.

You can customize this behavior. See the parameter hint above `dMon.GetOrder` for details.

When a monitor is added / removed, the script automatically updates the hotkeys to reflect the change. For example, say I have the following monitors:

```
 ____________
 | 2  || 3  |
 ------------
   ______
   | 1  |
   ------
```

Then I remove the top-right monitor...

```
 ______
 | 2  |
 ------
   ______
   | 1  |
   ------
```

The script will unbind `modifier & 3`, so it no longer triggers the function.

If I remove the top-left monitor instead of the top-right monitor...

```
     ______
     | 2  |
     ------
   ______
   | 1  |
   ------
```

The script still unbinds `modifier & 3`, and `modifier & 2` will now target the top-right monitor.

If I add the top-left monitor back...

```
 ____________
 | 2  || 3  |
 ------------
   ______
   | 1  |
   ------
```

The script binds `modifier & 3`, and `modifier & 2` targets the top-left monitor, and `modifier & 3` targets the top-right monitor.

It does not matter the monitor's actual monitor number nor the order in which they are plugged in, because they are selected according to relative position.
