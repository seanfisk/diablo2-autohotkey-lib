Diablo II AutoHotkey Macro Library
==================================

Diablo II is a great game, but some of its controls provide an opportunity for a more efficient setup. This project contains [AutoHotkey][ahk] macros for Diablo II.

Features
--------

**Automatic configuration of controls from a file.** This is perfect for someone who plays multiple accounts and would like to have the same keys for each account. Stop wasting time manually synchronizing them between characters!

**Skill-based weapon sets.** Diablo II: LOD introduced weapon sets, which refer to a primary and alternate weapon/shield set for each character. Often times, it makes sense to use a specific skill with a specific weapon set. Using these macros, you can set your skill keys to change to a preferred weapon set for that skill as well as changing to the skill.

Here's a motivating example; in fact, the one that motivated these macros' creation. Let's say you play as a hybrid Sorceress (e.g., MeteOrb) who uses both cold and fire spells. You have a primary staff which gives bonuses to fire spells in addition to being best for general spells (e.g., bonuses to Warmth). You also have an alternate staff that gives bonuses to cold spells, but isn't good for much else. Obviously, fire spells are best used with the fire staff, while cold spells are best used with the cold staff. However, it can get confusing trying to manage the current spell as well as the current weapon set.

These macros solve this problem by allowing you to specify the preferred weapon set for each skill. When you press that skill's key, the macros automatically switch to the preferred weapon if you are not currently using it.

There is also a function available for use of one-off skills, such as Town Portal. This function allows you to assign a hotkey which switches to a skill, uses it, and then switches back to the last skill.

**Automatic filling of potion belt.** The potion belt is a great way to heal yourself quickly! However, once your potion belt is empty, you have to remove yourself from the fray to refill it. This macro automatically fills your belt with potions from your inventory *and allows you to continue moving while it is executing*. This is a massive advantage as you can get back to the action much more quickly.

**PLANNED: Mass inventory macros.** Select a section of items and easily stash, trade, drop, or transmute them. See #22.

**PLANNED: [Steam][] compatiblity.** Run the game through Steam, open the overlay with hotkeys disabled, and open favorites in the web browser. See #21.

**PLANNED: Heal mercenary.** Heal your mercenary via a hotkey instead of dropping a potion on them! See #19.

Requests for new features welcome!

Requirements
------------

- [Diablo II: Lord of Destruction][d2lod]
- [AutoHotkey 1.1.* Unicode/ANSI 32-bit][ahkdl] ([AHKv2][ahkv2] support planned; see #4)
- Windows Vista or greater, for
  - [Microsoft Powershell][ps] (Vista+)
  - [ReadDirectoryChangesW][rdcw] (XP+)
  - [GDI+][gdip] (XP+)

The macros are routinely tested on Windows 8.1. 32-bit AHK is required because the [AHK GDI+ bindings][ahk-gdip] do not have 64-bit compatibility yet.

Installation
------------

These macros are made available as a [library of functions][ahk-user-lib] which you include in your own AutoHotkey script. Some, but not much, AutoHotkey knowledge is required. First, however, we must install the macro library.

1. Ensure you have the above requirements installed.
1. If you are experienced in [Git][], clone this repository from PowerShell with:

   ```posh
   git clone --recursive https://github.com/seanfisk/diablo2-autohotkey-lib.git
   ```

   Otherwise, you can click the *Clone in Desktop* button on the right side of the screen. This will prompt you to install [GitHub for Windows][ghfw], which is a great Git client. After installing, it should prompt you to clone the repository.
1. Open the cloned directory in Windows Explorer. In GitHub for Windows, click the repository, click the gear in the upper right, then choose *Open in Explorer*.
1. Double-click `Install.ahk` to install the script to your [AutoHotkey User Library][ahk-user-lib]. You can also run this from PowerShell:

   ```posh
   .\Install.ahk
   ```

1. Copy the `Sample` directory to the `Personal` directory in the same folder, or run from PowerShell:

   ```posh
   Copy-Item -Recurse Sample Personal
   ```

   If you are experienced in Git, I highly recommend version-controlling your own macros or forking my [diablo2-macros][d2macros] repository.

Move on to the next section to get the macros up and running!

Usage
-----

If you followed the installation instructions, you have now created a personal copy of a macro configuration. Open the `Personal` directory and edit `D2Macros.ahk` by right-clicking it and choosing *Edit Script*. If you are interested in a better editor than Notepad, check out [SciTE4AutoHotkey][scite4ahk]. This is the AutoHotkey script which controls your macros. This sample configuration enables all features.

To run the macros, double-click the file in Windows Explorer. You should see a green rectangle appear in your system tray. You can right-click this to control the macro process. To reload the macros, double-click the file or right-click on the icon and click *Reload This Script*.

The macros are configured primarily by files in a format called [JSON][]. It is a text-based format and relatively easy to edit even if you don't know what you're doing. All keys are listed in AutoHotkey key format; see the [AutoHotkey Key List][ahk-keys] for an enumeration of possible options.

### Auto-configure Controls

Controls are configured with `Controls.json`. It is basically self-explanatory; just put in keys as shown in the [AutoHotkey Key List][ahk-keys]. To assign the keys in-game, press Escape to bring up the menu, then choose *Configure Controls*. Press the assigned hotkey (default is Ctrl+Alt+a) to assign the keys!

If there are duplicate keys, they will be detected and the cursor will not move to the end of the list. Open the log to find out which key assignment was duplicated.

### Skill-based Weapon Sets

Start the macros then start your game. If you are already running the game, make sure you are on your primary weapon set using the "Swap Weapons" key. Start the macros, and immediately stop using the "Swap Weapons" key (that's the whole point, remember?). The macros currently have no way of knowing what weapon set or skill you are currently using other than intercepting your keystrokes. The "Swap Weapons" key is deliberately not hotkeyed, so if the macros become out-of-sync with the game you can manually correct by swapping your weapons.

See the sample file for an example on how to assign a hotkey to a one-off skill, like Town Portal.

### Fill Potion Belt

The setup for this macro is a little bit more elaborate because it relies on image recognition to find potions in your inventory. Before recognizing images, however, we need to generate bitmaps of each potion. The bitmap generation script is written using [PowerShell][ps], so we need to allow the system to run PowerShell scripts. Do this by opening a PowerShell prompt as an Administrator and running:

```posh
Set-ExecutionPolicy RemoteSigned
```

Start the macros. Now, open Diablo II and from the in-game pause menu choose *Video Settings*. Make sure your resolution is set to 800x600; the macros will not work unless this resolution is used. Adjust your Gamma and Contrast to the preferred levels, as these affect the appearance of the potions on the screen.

Next, open your inventory and arrange potions at the top left as follows:

<table>
    <tr>
        <td>Minor Healing</td>
        <td>Light Healing</td>
        <td>Healing</td>
        <td>Greater Healing</td>
        <td>Super Healing</td>
    </tr>
    <tr>
        <td>Minor Mana</td>
        <td>Light Mana</td>
        <td>Mana</td>
        <td>Greater Mana</td>
        <td>Super Mana</td>
    </tr>
    <tr>
        <td>Rejuvenation</td>
        <td>Full Rejuvenation</td>
    </tr>
</table>

You may have any other items in your inventory, but do not leave any of these potions out, *even if you do not intend to use potions of that type*.

Now press your bitmap generation key (default is Ctrl+Alt+b). You will see your inventory open up, then close shortly after. If your inventory does not close, there has been a problem; check the log. If it did close, you should now have an `Images` directory in your `Personal` directory with bitmaps of each potion. FillPotion should now be enabled! Try running it using your FillPotion key (default is f). There are some settings that can be configured in `FillPotion.json`, but for the most part you should leave them alone.

Known Issues
------------

**Skill macros become out-of-sync with game.** This can happen if you button-mash or the game lags. There is a slight delay after swapping weapons. We try to keep the delay to a minimum in the macros, but sometimes it is not long enough and the keystrokes do not take effect in the game. Swap your weapons manually if the preferred weapons are reversed, or switch skills a bit to set those correctly. You can also suspend the hotkeys and manually return to your primary weapon with an associated skill, and reset the macros by hotkey (default is Ctrl+Alt+r), then resume the hotkeys by pressing the suspend key again.

**Skills activated using the Skill Speed Bar.** The only way the macros know the state of the game are by intercepting your keystrokes. Therefore, they do not know when you have switched skills using the mouse and the Skill Speed Bar. After using a skill selected from the Skill Speed Bar, press a skill hotkey *which does not change the current weapon* to get the macros back on track.

**Old skill for weapon set used when activating a skill which causes a weapon swap.** This can happen because the macros wait slightly to activate the skill after swapping weapons. There really isn't a way around this because the game takes a short amount of time to swap weapons, and the same thing would probably happen if you did it manually. Just wait slightly longer before using the skill.

**Fill Potion fails or freezes.** Fill Potion is a relatively brittle macro and there are a lot of things that can possibly go wrong. I recommend resetting the macros if things go haywire (default is Ctrl+Alt+r).

Is this considered botting?
---------------------------

I personally don't consider these macros botting, as they are used to augment human gameplay rather than replace it. These macros cannot nor are intended to run without user intervention. They are intended to enhance the fun of a great game, and remove some of the annoyances one has to go through during routine gameplay. But my opinion doesn't change the opinion of those who own the servers on which you may be playing.

**Bottom line:** Consult your server administrator. It all depends on the rules of the server on which you play. On single player, go nuts. Either way, I accept no responsibility for repercussions one may encounter when using these macros. *Use at your own risk.*

Is it worth it?
---------------

Yes! At least, I think so. Considering you are probably going to be playing this game for hours on end, you may as well take the short time to configure efficient controls, get used to them, and use macros when appropriate to improve your gameplay.

Thanks
------

* James Donley for getting me into programming, and then 8 years later, Diablo II.
* Ryan Moyer for scripting AutoHotkey with me.
* The AutoIt team, Chris Mallett, Lexikos, and the AHK community for AutoHotkey.
* [@cocobelgica](https://github.com/cocobelgica) for [AutoHotkey-JSON](https://github.com/cocobelgica/AutoHotkey-JSON), which provided a sane format for configuration files (INI sucks!).
* [@tariqporter](https://github.com/tariqporter) (tic) for [Gdip][]
* [@MasterFocus](https://github.com/MasterFocus) for [Gdip_ImageSearch](https://github.com/MasterFocus/AutoHotkey/tree/master/Functions/Gdip_ImageSearch)
* [@HotKeyIt](https://github.com/HotKeyIt) for [WatchDirectory][]. Because AutoHotkey's native [ImageSearch][] cannot read the Diablo II display in fullscreen mode, Fill Potion in fullscreen would have been nearly impossible without WatchDirectory.

[ahk]: http://ahkscript.org/
[steam]: http://store.steampowered.com/about/
[d2lod]: http://blizzard.com/diablo2/
[ps]: https://msdn.microsoft.com/en-us/mt173057.aspx
[rdcw]: https://msdn.microsoft.com/en-us/library/windows/desktop/aa365465%28v=vs.85%29.aspx
[gdip]: https://msdn.microsoft.com/en-us/library/ms533797%28v=vs.85%29.aspx
[ahkdl]: http://ahkscript.org/download/
[ahkv2]: http://ahkscript.org/v2/
[ahk-gdip]: https://github.com/tariqporter/Gdip
[git]: https://git-scm.com/
[ghfw]: https://desktop.github.com/
[ahk-user-lib]: http://ahkscript.org/docs/Functions.htm#lib
[d2macros]: https://github.com/seanfisk/diablo2-macros
[scite4ahk]: http://fincs.ahk4.net/scite4ahk/
[json]: http://json.org/
[ahk-keys]: http://ahkscript.org/docs/KeyList.htm
[WatchDirectory]: https://github.com/HotKeyIt/WatchDirectory
[ImageSearch]: http://ahkscript.org/docs/commands/ImageSearch.htm
