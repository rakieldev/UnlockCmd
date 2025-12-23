# UnlockCmd
Unlock chars via commands on the select screen.

>Ikemen 1.0 Only.  
>Module developed by Rakíel

A module for Ikemen GO that enables configuring char unlock commands and customizing animations for hidden chars directly via def file.

# Installation

1. Extract archive content into "./external/mods/unlockCmd" directory
2. Add your command and its settings to the unlockCmdConfig.def.
3. Add sprites to unlockCmdSprites.sff, as required.
5. Add sounds to unlockCmdSounds.snd, as required.
6. Link the command to the char you want it to unlock in the select.def

# unlockCmdConfig.def parameters

- name:
  - The name of the command to be used to unlock a char.
- link or charpath:
  - The char path, exactly the same as it’s defined in select.def.
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
- unlockanim:
  - The sprite or animation used as the char’s portrait when being unlocked. If omitted, it won’t be used. This follows the standard .air syntax, allowing you to specify either a single sprite or define an animation. If an animation is defined, the character will be unlocked at the end of the animation. Storyborads will be played after the unlock animation.
  You must add your sprites to unlockCmdSprites.sff. 
- storyboard:
  - Path to the storyboard to play when the char is unlocked

# Example
  ```ini
[UnlockConfig]
name = SuaveUnlockCMD
link = SuaveDude/suave.def
command = ~F,F,F,B,B,B,s
holdstart = 0
unlocked = false
unlocksnd = 1,0,100
hidden = 0
keep = 0
anim = 1,0, 0,0, -1
unlockanim = 
1,1, 0,0, 7
1,2, 0,0, 7
1,3, 0,0, 7
1,4, 0,0, 7
storyboard = chars/SuaveDude/unlock.def
 ```
# Select.def

After customizing the unlockCmdConfig, you need to edit the select.def as follows:

``SuaveDude/suave.def, hidden = 2, unlock = unlockCmd("SuaveUnlockCDM")``

You can also use hidden = 3 to turn the cell into a random select cell until the char is unlocked. Note that hidden = 1 will not work with the mod.