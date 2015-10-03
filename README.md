<!-- -*- coding: utf-8; -*- -->

Diablo II AutoHotkey Macro Library
==================================

Diablo II is a great game, but some of its controls provide an opportunity for a more efficient setup. This project contains [AutoHotkey][ahk] macros for Diablo II.

Features
--------

**Easily synchronize controls across characters.** [Auto-Configure Controls](#auto-configure-controls) is perfect for someone who plays multiple characters and would like to have the same keys for each one. Stop wasting time manually synchronizing them between characters!

**Associate a skill with a particular weapon set.** Diablo II: LOD introduced weapon sets, which refer to a primary and alternate weapon/shield set for each character. Often times, it makes sense to use a specific skill with a specific weapon set. Using [Skill-based Weapon Sets](#skill-based-weapon-sets), you can associate a skill with a preferred weapon set. As a result, pressing a skill key can cause your character to change their skill *and* weapon set.

Here's a motivating example; in fact, the one that motivated these macros' creation. Let's say you play as a hybrid Sorceress who uses both cold and fire spells (e.g., [MeteOrb][], one of my characters' builds). You have a primary staff which gives bonuses to fire spells in addition to being best for general spells (e.g., bonuses to [Warmth][]). You also have an alternate staff that gives bonuses to cold spells, but isn't good for much else. Obviously, fire spells are best used with the fire staff, while cold spells are best used with the cold staff. However, it can get confusing trying to manage the current spell as well as the current weapon set.

These macros solve this problem by allowing you to specify the preferred weapon set for each skill. When you press that skill's key, the macros automatically switch to the preferred weapon if you are not currently using it.

There is also a function available for use of one-off skills, such as Town Portal. This function allows you to assign a hotkey that switches to a skill, uses it, and then switches back to the last skill.

**Automatically fill your belt with potions.** Using potions from the belt is a great way to heal yourself quickly! However, once your belt is empty, you have to remove yourself from the fray to refill it. [Fill Potion](#fill-potion) automatically fills your belt with potions from your inventory *and allows you to continue moving while it is executing*. This is a massive advantage as you can get back to the action much more quickly.

**Move items around quickly.** Use the [Mass Item Macros](#mass-item-macros) to select a block of multiple items anywhere and easily move or drop all of them at once. Move supports only single-cell items and can be used, for example, to move items within or between the stash, inventory, and Horadric Cube. Drop supports items of any size and can be used, for example, to drop multiple items on the ground, into a shop for selling, or into the Horadric Cube.

**Right-click fix.** Diablo II has an annoying behavior where right-clicking causes the left mouse button not to be considered as held down. Included in the library and sample configuration is a function to fix this behavior.

**Steam overlay integration.** [Steam][] is a great platform for playing games! Even though Diablo II is not a Steam game, Steam can be useful in Diablo II, primarily for voice chat with friends and Steam's awesome overlay. [Steam Helpers](#steam-helpers) are included to run the game through Steam, open the overlay with hotkeys disabled, and open favorites in the web browser.

**Voice alerts and logging.** It is useful to know what the macros are "thinking" when they are running so that you can confirm they are running correctly. Certain actions (especially errors) will trigger voiceover announcements letting you know what is happening for maximum awareness. In addition, all actions are by default logged to a file so that you can see exactly what happened.

**Develop your own macros.** Although this library has many pre-configured behaviors, it is also a framework for developing your own macros. For an example of a macro which uses this library but is not part of it, see my [Sorceress macros][] which make use of [Telekinesis][]. Macro away!

Requests for new features also welcome!

Requirements
------------

- [Diablo II: Lord of Destruction][d2lod]
- [AutoHotkey 1.1.* Unicode/ANSI 32-bit][ahkdl] ([AHKv2][ahkv2] support planned; see [#4](https://github.com/seanfisk/diablo2-autohotkey-lib/issues/4))
- Windows Vista or greater, for
  - [Microsoft Powershell][ps] (Vista+)
  - [ReadDirectoryChangesW][rdcw] (XP+)
  - [GDI+][gdip] (XP+)
- [Sven's GLIDE Wrapper][] for use of the Steam overlay

The macros are routinely tested on Windows 8.1. 32-bit AHK is required because the [AHK GDI+ bindings][ahk-gdip] do not have 64-bit compatibility yet.

Installation
------------

These macros are made available as an [AutoHotkey user library][ahk-user-lib] which you [#Include][ahk-include] in your own AutoHotkey script (explicit `#Include` is required). Some, but not much, AutoHotkey knowledge is required. First, however, we must install the macro library.

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

The macros can be configured by files in a format called [JSON][]. It is a text-based format and relatively easy to edit even if you don't know what you're doing. All keys are listed in AutoHotkey key format; see the [AutoHotkey Key List][ahk-keys] for an enumeration of possible options.

### Auto-configure Controls

Controls are configured with `Controls.json`. It is basically self-explanatory; just put in keys as shown in the [AutoHotkey Key List][ahk-keys]. To assign the keys in-game, press Escape to bring up the menu, then choose *Configure Controls*. Press the assigned hotkey (default is Ctrl+Alt+a) to assign the keys!

If there are duplicate keys, they will be detected and the cursor will not move to the end of the list. Open the log to find out which key assignment was duplicated.

### Skill-based Weapon Sets

The point of this feature is to stop using the Swap Weapons key. Instead, the macros will be swapping weapons for you. To perform this, the macros track your current weapon set based upon the skill keys you press. For this to work, do not change skills using the Skill Speed Bar or the Select Next/Previous Skill keys, or use the Swap Weapons key (you may do this later once you know how the macros work). If you do use a skill from the Skill Speed Bar, press a skill hotkey *which does not change the current weapon* to get the macros back on track.

Begin by opening `Personal\Skills.json` to configure preferred weapon sets for each of your skills. The skills are in numeric order, and for each skill you can specify 1 or 2 (meaning primary or alternate weapon set) or `null` (meaning no preference).

To use the macros, start the macros then start your game. If you are not on your primary weapon, suspend the macros (default is Ctrl+Alt+s) and swap to it using Swap Weapons, then resume the macros (same as suspend). Stop using the Swap Weapons key at this point. The macros will now change and track your current skill and weapon set by intercepting your keystrokes. The Swap Weapons key is deliberately not hotkeyed, so if the macros become out-of-sync with the game you can manually correct by swapping your weapons.

See the sample file for an example on how to assign a hotkey to a one-off skill, like Town Portal.

### Fill Potion

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

Now press your bitmap generation key (default is Ctrl+Alt+b). You will see your inventory open up, then close shortly after. Assuming you have voice alerts enabled, a voice should alert you of the status of your generation. If an error occurred, check the log for more information. If all went well, you should now have an `Images` directory in your `Personal` directory with bitmaps of each potion. Fill Potion should now be enabled! Try running it using your Fill Potion key (default is f).

### Mass Item Macros

There is no setup for these macros: just use and enjoy! Usage is as follows:

1. Position your mouse at the selection start and press the `SelectionStart` hotkey (default is 6). You should hear a voice announce "Select".
1. Position your mouse to define the selection as a rectangle and press the `SelectionEnd` hotkey (default is 7). You should hear a voice announce the number of cells you have selected (which is not necessarily the number of items).
1. Position your mouse to the drop location and press the `Drop` hotkey (default is 8) to drop the items. Position your mouse at the top left of the area to move them and press the `MoveSingleCellItems` hotkey (default is 9) to move the items to that area.

### Steam Helpers

The Steam functions included with this library help to make the experience of using the Steam in-game overlay with Diablo II more enjoyable. As these functions only affect the overlay, enabling this feature is not necessary if you do not want to use the overlay. However, when playing fullscreen, the Steam overlay is really useful as it makes references like Horadric Cube recipes or rune words one click away.

#### Overlay

The first step is getting the Steam overlay working. Diablo II supports three modes of graphics output: DirectDraw, Direct3D, and 3dfx Glide. DirectDraw and Direct3D are natively supported by most Windows installations. 3dfx Glide is no longer supported on any current graphics card, but it is possible to use a [Glide wrapper][] to map Glide API calls to another graphics API.

In this case, the mapping we want is Glide to OpenGL, because Steam's overlay works great with Diablo II on OpenGL. Although there are several Glide wrappers available, I have had luck with [Sven's GLIDE Wrapper][], which uses OpenGL and is designed specifically for Diablo II. Follow the instructions on Sven's website and in his README to get the wrapper installed and working.

When you have the wrapper working, it's time to get the Steam overlay working. First, configure the overlay by opening Steam and choosing *Steam* → *Settings* → *In-Game*. Ensure that the overlay is enabled, and set the key to whatever you'd like (remember the key, though).

Now we need to add Diablo II to the Steam Library as a non-Steam game. Follow these steps:

1. Open the Steam Library.
1. Click *ADD A GAME...* → *Add a Non-Steam Game...*
1. Click *BROWSE...* and navigate to `Documents\AutoHotkey\Lib` within your home directory.
1. Select `Diablo II.exe`. This is a program generated by the macro library installer that will open your Diablo II game straight to Battle.Net (If you don't prefer this, just choose `Diablo II.exe` in the location that you installed it).

In your Steam Library, you should now be able to click *Diablo II* to play it. If everything worked correctly, you will see a Steam pop-up in the lower right of the screen. In addition, pressing the overlay key should bring it up above your game.

#### Launcher

Using the overlay in-game with the default overlay key is nice, but you will find that if you try to type your keystrokes may not come out as intended. This is because the macro hotkeys are still activated. To fix this, suspend them with the suspend key (default is Ctrl+Alt+s).

A better option is to use the macros to open the Steam overlay. In `D2Macros.ahk`, edit the Steam configuration passed to `Diablo2.Init()` to use your overlay key. Lower in the file, change the key binding which activates `Steam.OverlayToggle()` to your preferred binding. When toggling the overlay with the macros, the macro hotkeys will now be automatically suspended and resumed. Note that although Escape can close the overlay, it will not re-enable the macros; use the toggle hotkey to do so.

The next step in convenience is to enable the macros to launch the game through Steam. To do this, you need to find your Steam "rungameid" URL. Follow these steps:

1. In the Steam Library, right-click *Diablo II* → *Create Desktop Shortcut*.
1. On the desktop, right-click the shortcut and choose *Properties*. At the end of `D2Macros.ahk`, paste in the URL, replacing `steam://rungameid/xxxxxxxxxxxxxxxxxxxx`.

Now reboot the macros and press the Steam launch key (default is Ctrl+Alt+l). The game should launch and immediately suspend the macros. The macros will be re-enabled after Enter is pressed thrice: Battle.Net login, character selection, and game creation/join. Enjoy!

#### Browser Favorites

For an in-game web browser, the Steam Web Browser is great! However, it doesn't support favorites. This is unfortunate, because in most sessions I want to use it to reference the same web documents. However, these macros feature a function which can open tabs in your Steam web browser. The `D2Macros.ahk` setup defaults to Horadric Cube recipes and a list of rune words. You can open these tabs by opening the Steam Web Browser, positioning your mouse over the URL bar, and pressing the `Steam.BrowserOpenTabs()` key (default is Ctrl+Alt+w). The Steam overlay is often laggy, and this macro is somewhat finicky and does not always work. But it's really nice to have these references just a click away!

Known Issues
------------

**A note on macros:** I've tried to make the macros as reliable as possible, but sometimes errors do occur. Just remember: these are mouse and keyboard macros interacting with an unaware game, not an application interacting with a stable and official API. Problems *will* infrequently occur, and at that time it is beneficial to know how to solve them.

In particular, [Sleep][] timings (waiting for the game to react) were developed on my machine; I don't know how the game will react on yours. In general, I've tried to minimize the waiting times while maximizing the reliability.

**Skill macros become out-of-sync with game.** This can happen if you button-mash or the game lags. There is a slight delay after swapping weapons. We try to keep the delay to a minimum in the macros, but sometimes it is not long enough and the keystrokes do not take effect in the game. Swap your weapons manually if the preferred weapons are reversed, or switch skills a bit to set those correctly. You can also suspend the hotkeys (default is Ctrl+Alt+s) and manually return to your primary weapon with an associated skill, and reset the macros by hotkey (default is Ctrl+Alt+r), then resume the hotkeys by pressing the suspend key again.

**Old skill for weapon set used when activating a skill which causes a weapon swap.** This can happen because the macros wait slightly to activate the skill after swapping weapons. There really isn't a way around this because the game takes a short amount of time to swap weapons, and the same thing would probably happen if you did it manually. Just wait slightly longer before using the skill.

**Fill Potion fails or freezes.** Fill Potion is a somewhat brittle macro and there are a lot of things that can possibly go wrong. I recommend resetting the macros if things go haywire (default is Ctrl+Alt+r).

### Mass Item issues

- **When moving items, the items were swapped in hand instead of moved.** Ensure the area to which you are moving items is empty. Moving items to a non-empty area is not supported, although you may be able to do it in certain ways if you understand how the macros work ;)
- **When I tried to drop into the Horadric Cube, the game picked up my Cube.** This happens if your selection had an empty cell. Dropping selections with empty cells into the Cube is not supported. Dropping selections with empty cells onto the ground or into a shop should be fine.
- **My character moves when dropping items on the ground.** This can happen if your selection had an empty cell. I'm working on fixing this.

Is this considered botting?
---------------------------

I personally don't consider these macros botting, as they are used to augment human gameplay rather than replace it. These macros cannot nor are intended to run without user intervention. They are intended to enhance the fun of a great game, and remove some of the annoyances encountered during routine gameplay. But my opinion doesn't change the opinion of those who own the servers on which you may be playing.

**Bottom line:** Consult your server administrator. It all depends on the rules of the server on which you play. On single player, go nuts. Either way, I accept no responsibility for repercussions one may encounter when using these macros. *Use at your own risk.*

Is it worth it?
---------------

Yes! At least, *I* think so. Considering you are probably going to be playing this game for hours on end, you may as well take the short time to configure efficient controls, get used to them, and use macros when appropriate to improve your gameplay.

Thanks
------

- James Donley for getting me into programming, and then 8 years later, Diablo II.
- Ryan Moyer for scripting AutoHotkey with me.
- The AutoIt team, Chris Mallett, Lexikos, and the AHK community for AutoHotkey.
- [@cocobelgica](https://github.com/cocobelgica) for [AutoHotkey-JSON](https://github.com/cocobelgica/AutoHotkey-JSON), which provided a sane format for configuration files (INI sucks!).
- [@tariqporter](https://github.com/tariqporter) (tic) for [Gdip][]
- [@MasterFocus](https://github.com/MasterFocus) for [Gdip_ImageSearch](https://github.com/MasterFocus/AutoHotkey/tree/master/Functions/Gdip_ImageSearch)
- [@HotKeyIt](https://github.com/HotKeyIt) for [WatchDirectory][]. Because AutoHotkey's native [ImageSearch][] cannot read the Diablo II display in fullscreen mode, Fill Potion in fullscreen would have been nearly impossible without WatchDirectory.

[ahk]: http://ahkscript.org/
[MeteOrb]: http://diablo.gamepedia.com/MeteOrb_Sorceress_by_Lethal_Weapon
[Warmth]: http://diablo.gamepedia.com/Warmth_%28Diablo_II%29
[steam]: http://store.steampowered.com/about/
[Sorceress macros]: https://github.com/seanfisk/diablo2-macros/blob/master/D2TwentyTwenty.ahk
[Telekinesis]: http://diablo.gamepedia.com/Telekinesis_%28Diablo_II%29
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
[ahk-include]: http://ahkscript.org/docs/commands/_Include.htm
[d2macros]: https://github.com/seanfisk/diablo2-macros
[scite4ahk]: http://fincs.ahk4.net/scite4ahk/
[json]: http://json.org/
[Glide wrapper]: https://en.wikipedia.org/wiki/Glide_API#Glide_wrappers_and_emulators
[Sven's GLIDE Wrapper]: http://www.svenswrapper.de/english/
[ahk-keys]: http://ahkscript.org/docs/KeyList.htm
[Sleep]: https://en.wikipedia.org/wiki/Sleep_%28system_call%29#Windows
[WatchDirectory]: https://github.com/HotKeyIt/WatchDirectory
[ImageSearch]: http://ahkscript.org/docs/commands/ImageSearch.htm
