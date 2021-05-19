﻿#NoEnv
#Persistent
#SingleInstance, force
DetectHiddenWindows, Off
SendMode Input
SetWorkingDir %A_ScriptDir%
SetTitleMatchMode, 2
SetTitleMatchMode, Fast

Menu, Tray, NoStandard
Menu, Tray, Add, `tToggle Anti-Idle, ToggleAntiIdle
Menu, Tray, Add
Menu, Tray, Add, ---- Context-Specific Hotkeys ----, DummyLabel
Menu, Tray, Disable, ---- Context-Specific Hotkeys ----
Menu, Tray, Add, (Alt + Shift + \)`tToggle Active Window Always-On-Top, ToggleActiveWindowAlwaysOnTop
Menu, Tray, Disable, (Alt + Shift + \)`tToggle Active Window Always-On-Top
Menu, Tray, Add, (Alt + Shift + /)`tCopy && Web Search Clipboard, CopyAndWebSearchClipboard
Menu, Tray, Disable, (Alt + Shift + /)`tCopy && Web Search Clipboard
Menu, Tray, Add
Menu, Tray, Add, Reload Script, ReloadScript
Menu, Tray, Add, Exit Script, ExitScript

StartDiscordOnStartup()

; Alt + Shift + \
!+\::
    ToggleActiveWindowAlwaysOnTop()
    return

; Alt + Shift + /
!+/::
    CopyAndWebSearchClipboard()
    return

DummyLabel:
    return

AntiIdle:
    if (A_TimeIdlePhysical > 150000)
    {
        MouseMove, 100, 100, , R
        Sleep, 500
        MouseMove, -100, -100, , R
    }

    return

; Ensure that Discord starts minimized on computer startup when this script is
;     run at startup
StartDiscordOnStartup()
{
    if (FileExist("%A_AppData%\..\Local\Discord\Update.exe"))
    {
        Process, Exist, Discord.exe

        if (ErrorLevel == 0)
        {
            RunWait, %A_AppData%\..\Local\Discord\Update.exe --processStart Discord.exe
            WinWait, ahk_exe Discord.exe, , , Discord Updater
            WinClose, ahk_exe Discord.exe
        }
    }
}

; Move mouse back-and-forth 100 pixels every 2 minutes if physically idle for
;     more than 2.5 minutes
ToggleAntiIdle()
{
    static isChecked = false

    if (isChecked)
    {
        Menu, Tray, Uncheck, `tToggle Anti-Idle
        isChecked := false

        SetTimer, AntiIdle, Off
    } else {
        Menu, Tray, Check, `tToggle Anti-Idle
        isChecked := true

        SetTimer, AntiIdle, 120000
    }
}

; Toggle active window's Always-On-Top status
ToggleActiveWindowAlwaysOnTop()
{
    WinSet, AlwaysOnTop, Toggle, A
}

; Copy highlighted text into clipboard and use it to web search
CopyAndWebSearchClipboard()
{
    Send, ^c
    Sleep, 50
    Run, https://www.google.com/search?q=%clipboard%
}

; Reload this script
ReloadScript()
{
    Reload
}

; Exit this script
ExitScript()
{
    ExitApp
}