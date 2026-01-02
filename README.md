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

# Demonstration

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
#Requires AutoHotkey >=2.0-a
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

## CapsLock

The methods that end in "_CapsLock" are designed to ensure that the caps lock is returned to its original state when the function exits. These methods allow you to use the caps lock key like you normally would, and use it as a modifier key for these methods as well.

## Moving / resizing a window under the mouse cursor

The default configuration is:
- While holding the modifier key, left-click and drag the window to move the window.
- While holding the modifier key, right-click and drag the window to resize the window.

## Moving / resizing a control under the mouse cursor

The default configuration is:
- While holding the modifier key, left-click and drag the window to move the control.
- While holding the modifier key, right-click and drag the window to resize the control.

This may not work as expected for all controls, particularly if the control is a WebView2 (or similar) implementation.

## Key chords

`WinMover.Prototype.Chord` and `WinMover.Prototype.Chord_CapsLock` allow you to move and resize the active window to a specific spot.

You define the modifier key as the first parameter of `WinMover.Prototype.__New`. This is the "CHORDMODIFIER" seen in the template.

You define a map object where each item's key corresponds to the second key press of the key chord, and the value is an object with properties `{ X, Y, W, H }`. Each property value is a number that is multiplied with the monitor's corresponding value.

To invoke a key chord, you:
1. Press and hold the modifier key.
2. Press and release a number key (1-9) to specify the target monitor.
3. Press and release another key to specify the target position / size of the window.
4. Release the modifier key.

This is the default presets:
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

For example, say I have three monitors. Say I want to move the active window to the left side of the third monitor. To accomplish that, I:
1. Press and hold the modifier.
2. Press and release "3" to specify the third monitor.
3. Press and release "1" to select the "left-half" configuration seen above.
4. Release the modifier.

When the method executes, the second key press ("1" in this example) is used to retrieve the object from the map. Then:
- `obj.X` gets multiplied by the left coordinate of the monitor's work area, and that becomes the x coordinate of the window.
- `obj.Y` gets multiplied by the top coordinate of the monitor's work area, and that becomes the y coordinate of the window.
- `obj.W` gets multiplied by the width of the monitor's work area, and that becomes the width of the window.
- `obj.H` gets multiplied by the height of the monitor's work area, and that becomes the height of the window.

For another example, say I want to move the active window to the bottom-right quarter of the primary monitor. To accomplish that, I:
1. Press and hold the modifier.
2. Press and release "1" to specify the primary monitor.
3. Press and release "s" to select the "bottom-right quarter" configuration seen above.
4. Release the modifier.

To move the active window to occupy the entirety of monitor 2, I:
1. Press and hold the modifier.
2. Press and release "2" to specify the primary monitor.
3. Press and release "3" to select the "full-screen" configuration seen above.
4. Release the modifier.

You can expand the built-in configurations by defining a map object and passing it to the "Presets" parameter of `WinMover.Prototype.__New`. For example, if you want to be able to tile windows in two rows of three, you would define a map object like this:

```ahk
Presets := Map(
    'q', { X: 0, Y: 0, W: 0.333, H: 0.5 } ; top-left
  , 'w', { X: 0.333, Y: 0, W: 0.333, H: 0.5 } ; top-middle
  , 'e', { X: 0.666, Y: 0, W: 0.333, H: 0.5 } ; top-right
  , 'a', { X: 0, Y: 0.5, W: 0.333, H: 0.5 } ; bottom-left
  , 's', { X: 0.333, Y: 0.5, W: 0.333, H: 0.5 } ; bottom-middle
  , 'd', { X: 0.666, Y: 0.5, W: 0.333, H: 0.5 } ; bottom-right
)
```

You can specify as many configurations as you have keys, though slow machines may run into some timing issues with a very large number of configurations.

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
