
#include <WinMover>
#Requires AutoHotkey >=2.0-a
#SingleInstance force

SetWinDelay 50

; This is how I have my keys set up.

global WinMoverObj := WinMover('CapsLock', Map(
    1, { X: 0, Y: 0, W: 0.5, H: 1 } ; left-half
  , 2, { X: 0.5, Y: 0, W: 0.5, H: 1 } ; right-half
  , 3, { X: 0, Y: 0, W: 1, H: 1 } ; full-screen
  , 'q', { X: 0, Y: 0, W: 0.5, H: 0.5 } ; top-left quarter
  , 'w', { X: 0.5, Y: 0, W: 0.5, H: 0.5 } ; top-right quarter
  , 'a', { X: 0, Y: 0.5, W: 0.5, H: 0.5 } ; bottom-left quarter
  , 's', { X: 0.5, Y: 0.5, W: 0.5, H: 0.5 } ; bottom-right quarter
))

CapsLock & RButton::WinMoverObj.DynamicResize_CapsLock()
CapsLock & LButton::WinMoverObj.DynamicMove_CapsLock()

#RButton::WinMoverObj.DynamicResizeControl()
#LButton::WinMoverObj.DynamicMoveControl()
