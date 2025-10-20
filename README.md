# WinXploy

> “A magic dwells in each beginning...”

This words wrote the German author Hermann Hesse — no doubt on a typewriter. Had he needed to install a Windows computer first,
I am sure that he might have lost that magic before writing *Steps*.

WinXploy aims to automate the process of (re-)building a productive Windows OS from scratch to make it less time consuming.
Basically it is just a simple PowerShell-Script (WinXploy.ps1) which makes use of and orchestrates other tools or their functions.
The real hard work is done by all the great open source projects it makes use of, big thanks for sharing!

## How it works?

The workflow is based on the PowerShell-Framework [OSDCloud](https://github.com/OSDeploy/OSDCloud) which is really a great work done by
[David Segura](https://github.com/OSDeploy) and many other people. 

Further more I use the following tools to debloat and configure my OS at the end of the installation process:

- [Sophia Script](https://github.com/farag2/Sophia-Script-for-Windows)
- [Win11Debloat](https://github.com/Raphire/Win11Debloat)
- [winscript](https://github.com/flick9000/winscript)

For detailed dokumentation please have a look at the comments included in `WinXploy.ps1`.
