Diablo II Macros
================

Diablo II is a great game, but some of its controls provide an opportunity for a more efficient setup. This project contains [AutoHotkey][ahk] macros for Diablo II.

*Note:* These macros are designed for AutoHotkey 1.1+, formerly known as AutoHotkey_L (the Lexikos fork) and Diablo II: Lord of Destruction played in 800x600 resolution on Windows. They should work on any version of Windows supported by these two pieces of software.

[ahk]: http://ahkscript.org/

Features
--------

**Automatic binding of controls which are set from a configuration file.** This is perfect for someone who plays multiple accounts and would like to have the same keys for each account. Stop wasting time manually synchronizing them between characters!

**Skill-based weapon sets.** Diablo II: LOD introduced weapon sets, which refer to a primary and alternate weapon/shield set for each character. Often times, it makes sense to use a specific skill with a specific weapon set. Using these macros, you can set your skill keys to change to a preferred weapon set for that skill as well as changing to the skill.

Here's a motivating example; in fact, the one that motivated these macros' creation. Let's say you play as a hybrid Sorceress (e.g., MeteOrb) who uses both cold and fire spells. You have a primary staff which gives bonuses to fire spells in addition to being best for general spells (e.g., bonuses to Warmth). You also have an alternate staff that gives bonuses to cold spells, but isn't good for much else. Obviously, fire spells are best used with the fire staff, while cold spells are best used with the cold staff. However, it can get confusing trying to manage the current spell as well as the current weapon set.

These macros solve this problem by allowing you to specify the preferred weapon set for each skill. When you press that skill's key, the macros automatically switch to the preferred weapon if you are not currently using it.

**PLANNED: Mass inventory macros.** Select a section of your inventory or stash and decided to sell it, drop it, or trade it.

Requests for new features welcome!

Installation
------------

Coming soon!

Usage
-----

### Skill-based Weapon Sets

Before you start the macros, switch to your primary weapon set using the "Swap Weapons" key. Start the macros, and immediately stop using the "Swap Weapons" key (that's the whole point, remember?). The macros currently have no way of knowing what weapon set or skill you are currently using other than intercepting your keystrokes. The "Swap Weapons" key is deliberately not hotkeyed, so if the macros become out-of-sync with the game you can manually correct by swapping your weapons.

More information coming soon!

Known Issues
------------

**Macros become out-of-sync with game.** This can happen if you button-mash or the game lags. There is a slight delay after swapping weapons. We try to keep the delay to a minimum in the macros, but sometimes it is not long enough and the keystrokes do not take effect in the game. Swap your weapons manually if the preferred weapons are reversed, or switch skills a bit to set those correctly. In the future, a function to reset the macros may be implemented.

**Skills activated using the Skill Speed Bar.** The only way the macros know the state of the game are by intercepting your keystrokes. Therefore, they do not know when you have switched skills using the mouse and the Skill Speed Bar. After using a skill selected from the Skill Speed Bar, press a skill hotkey *which does not change the current weapon* to get the macros back on track.

**Old skill for weapon set used when activating a skill which causes a weapon swap.** This can happen because the macros wait slightly to activate the skill after swapping weapons. There really isn't a way around this because the game takes a short amount of time to swap weapons, and the same thing would probably happen if you did it manually. Just wait slightly longer before using the skill.

**Keys become unbound when auto-configuring.** This can happen if you have two actions assigned to the same key. The action which comes last in the list will take precedence and unbind the earlier action. Check your configuration for duplicate keys.

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
* Coco for [AutoHotkey-JSON](https://github.com/cocobelgica/AutoHotkey-JSON)