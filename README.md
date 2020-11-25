# findcmd
 Stata command to automatically find built-in commands and user written commands used in a do or ado file.

## Installation
```stata
* findcmd can be installed from github

net set other `"`c(sysdir_plus)'/f"'
net install findcmd, all replace ///
	from("https://raw.githubusercontent.com/PovertyAction/findcmd/main")
```