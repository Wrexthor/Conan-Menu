# Powershell script to manage Conan Exiles Database.

How it looks:

![alt text](https://github.com/Wrexthor/Conan-Menu/blob/master/menu.PNG?raw=true "Logo Title Text 1")

Features
* Automatically detects conan folder
* Remove buildings from characters that has not logged in in x days (based on conan log files) below y level
* Remove all(!) bedrolls and campfires
* Optimize database (remove unsed space, reindex, set cache to higher size, analyze, check integrity)
* All interactions using a simple script menu, prompting before each action
* Automatically backs up database before each change
* Write chat logs to separate file
* Write login logs to separate file
* Update character name

Planned features
* Remove ALL single foundations
* Delete specified Guild and characters including all their assets
* Delete assets without owner or empty guild assets

Instructions
 1. Download Zip from github
 2. Extract somewhere (does not matter where)
 3. Right click conan-menu.ps1, run with powershell.
 4. Navigate awesome menu
 5. ??
 6. profit!

I don't know SQL very well, Credit for most sql queries goes to: https://github.com/A15Bog/conanexilessql
