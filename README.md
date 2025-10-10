# UnlockCmd
Unlock chars via commands on the select screen.

>Last tested on Ikemen GO v0.99 and Nightly Build (2025-01-12).  
>Module developed by Rakíel

A module for Ikemen GO that enables configuring char unlock commands and customizing animations for hidden chars directly via def file.

# Installation

1. Extract archive content into "./external/mods" directory
2. Add your command and its settings to the unlockCmdConfig.def.
3. Add sprites to unlockCmdSprites.sff, as required.
5. Add sounds to unlockCmdSounds.snd, as required.
6. Link the command to the char you want it to unlock in the select.def

# unlockCmdConfig.def parameters

- name:
  - The name of the char to be unlocked with the command. It must match exactly how it is written in select.def.  
- command:
  - Write here the command to unlock the char (in the same format as commands are written in the char's CMD file).  
- holdstart:
  - If set to 1, the command requires holding the start button to execute.  
- unlocked:
  - If set to true, the char will be unlocked by default.  
- unlocksnd:
  - Group, index and volume of the sound to be played when the command is executed. Sounds must be added to unlockCmdSounds.snd.  
- hidden:
  - If set to 1, the cell will remain invisible until the char is unlocked. Valid values are 1 (true) or 0 (false).  
- keep:
  - If true, will keep the char unlocked after closing the game, valid values are 1 (true) or 0 (false).
- anim:
  - The sprite or anim to be used as the char's portrait when locked. If omitted, the default random select icon from the portrait will be used, this uses the standard .air syntax, allowing you to specify a single sprite or define an anim.  
   You must add your sprites to unlockCmdSprites.sff.  
- storyboard:
  - Path to the storyboard to play when the char is unlocked

# Example
  ```ini
[UnlockConfig]
name = SuaveDude
command = ~F,F,F,B,B,B,s
holdstart = 0
unlocked = false
unlocksnd = 1,0,100
hidden = 0
keep = 0
anim = 1,0, 0,0, -1
storyboard = chars/suavedud/unlock.def
 ```
# Select.def

After customizing the unlockCmdConfig, you need to edit the select.def as follows:

``SuaveDude, hidden = 2, unlock = unlockCmd("SuaveDude")``

You can also use hidden = 3 to turn the cell into a random select cell until the char is unlocked. Note that hidden = 1 will not work with the mod.

After the command is executed, if you want an unlock animation, you need to add the line ``portrait.anim = *your anim*`` to the [Select Info] in the ``system.def``. By default, the animation number should be 9000, but if your char uses this animation for something else, 
you should use a different number. If no corresponding animation exists, the char will default to using ``portrait.spr``. Make sure to use a very specific animation number here that doesn't exist in other chars to avoid issues.
