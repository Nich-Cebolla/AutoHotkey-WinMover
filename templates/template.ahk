
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
