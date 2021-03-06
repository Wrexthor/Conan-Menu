<#    
      .SYNOPSIS   
        Awesome Conan Admin Script!
      .DESCRIPTION   
        Can optimize database, clean assets based on login time of character,
        remove all bedrolls/campfires, separate chatlogs to a new file,
        separate logon logs to a new file and maybe more..?
      .NOTES 
        Author: Jack Swedjemark (Wrexthor)
        Updated: 15-03-2017            
        Credit for sql queries: https://github.com/A15Bog/conanexilessql                                        
#>

# preparations

# make background black, cause black is the new black
$console = $host.UI.RawUI
$console.BackgroundColor = "black"
Clear-Host

# get location of running script
function Get-ScriptDirectory {
    if ($psise) {Split-Path $psise.CurrentFile.FullPath}
    else {$PSScriptRoot}
}

# import PSSQLITE module
Import-Module "$(Get-ScriptDirectory)\PSSQLite"
Write-Debug 'Importing PSSQLite module.'

# get todays date for file naming purposes
$now = (get-date).ToShortDateString()
$sword =@'
                .v~
               .(W
              /<M.
\~b__________/$@|\----------------------------------------------------------.
 >@)$$$$$$$$($( )#H>====================================================----->
/_p~~~~~~~~~~\$@|/----------------------------------------------------------'
              \<M`
               `(B
                 `?_
'@

write-host $sword -ForegroundColor Red

# find conan folder or ask for it if not found

Write-Host 'Looking for conan folder..' -ForegroundColor Green

# supress errror spam from access denied to folders
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

# find conan folder
$conanPath = (gci -path C:\ -filter "Conan" -Recurse).FullName
Write-Debug "Paths found: $conanPath"

# restore error preference
$ErrorActionPreference = $old_ErrorActionPreference 

# check if path was found
if ($conanPath)
{
    # let user verify it is correct
    Write-Host "Conan folder found at $($conanPath[0]) is this correct?" -for Green
    $correct = Read-Host -Prompt 'y/n'
    Write-Debug "User entered $correct"
    # if not, let user enter correct path
    if ($correct -like 'n')
    {
        $conanPath = 'invalidPath'
        # ask for path until it can be verified as correct
        while (!(Test-Path $conanPath))
        {$conanPath = Read-Host -Prompt 'Enter path';Write-Debug "User entered $conanPath"}
    }
    if ($correct -like 'y')
    {$conanPath = $conanPath[0]}
    
}
# if not found, prompt for path
else 
{
    write-host "No conan path found, please specify full conan folder location, example 'C:\conan'" -ForegroundColor Red
    # ask for path until it can be verified as correct
    while (!(Test-Path $conanPath))
    {$conanPath = Read-Host -Prompt 'Enter path';Write-Debug "User entered $conanPath"}    
}

# define path to conan exiles logfiles
$logsPath = "$conanPath\ConanSandbox\Saved\Logs"
Write-Debug "Path to logs set to: $logsPath"

# verify logs folder can be accessed
if (!(Test-Path $logsPath))
{
write-host "Logs folder not found, please specify full conan logs folder location, example 'C:\conan\ConanSandbox\Saved\Logs'" -ForegroundColor Red
    # ask for path until it can be verified as correct
    while (!(Test-Path $logsPath))
    {$logsPath = Read-Host -Prompt 'Enter path';Write-Debug "User entered $logsPath"} 
}

 # read logfiles to memory
write-host "`nGetting all .log files from $logsPath.." -ForegroundColor Green
$files = get-childitem $logsPath -filter *.log -Recurse

# check oldest file found
$oldest = (($files | sort LastWriteTime | select -first 1).LastWriteTime).ToShortDateString()
Write-Host "Oldest logfile found is from $oldest" -ForegroundColor Yellow
Write-Debug "Files found: $files"

# database
$database = "$conanPath\ConanSandbox\Saved\game.db"

# check if correct
if (!(test-path $database))
{
    write-host "Database not found at $database" -ForegroundColor Red
    # prompt user for path
    while (!(Test-Path $database))
        {$database = Read-Host -Prompt 'Enter path (including game.db)';Write-Debug "User entered $database"} 
}
write-host "Database found at $database" -ForegroundColor Green

# get data queries
$getCharsQuery = 'SELECT * FROM characters;'
$getGuildQuery = 'SELECT * FROM guilds;'
$getBuildingsInstacesQuery = 'SELECT * FROM building_instances;'
$getBuildingHealthQuery = 'SELECT * FROM buildable_health;'

# run DB optimizations
$optimizeQuery = "VACUUM;REINDEX;ANALYZE;pragma integrity_check"

# remove all bedrolls and campfires
$deleteMiscQuery = "delete from buildable_health where object_id in (select distinct object_id from buildings where object_id in (select distinct object_id from properties where name like '%Bedroll%' or name like '%CampFire%'));
delete from building_instances where object_id in (select distinct object_id from buildings where object_id in (select distinct object_id from properties where name like '%Bedroll%' or name like '%CampFire%'));
delete from actor_position where id in (select distinct object_id from buildings where object_id in (select distinct object_id from properties where name like '%Bedroll%' or name like '%CampFire%'));
delete from item_inventory where template_id in ('12001','10001');
delete from buildings where object_id in (select distinct object_id from properties where name like '%Bedroll%' or name like '%CampFire%');
delete from properties where name like '%Bedroll%' or name like '%CampFire%';"

# needs player id formated with '',''
$playerIds = "'player1','player2','player3'"
$guildId = "someid"
$deleteAllFromIDQuery = "
delete from buildable_health where object_id in (select distinct object_id from buildings where owner_id in 
(select id from characters where playerid in ($playerIds))) or object_id in (select distinct object_id from buildings where owner_id = '$guildId');
delete from building_instances where object_id in (select distinct object_id from buildings where owner_id in 
(select id from characters where playerid in ($playerIds))) or object_id in (select distinct object_id from buildings where owner_id = '$guildId');
delete from properties where object_id in (select distinct object_id from buildings where owner_id in (select id from characters where playerid in 
($playerIds))) or object_id in (select distinct object_id from buildings where owner_id = '$guildId');
delete from actor_position where id in (select distinct object_id from buildings where owner_id in (select id from characters where playerid in 
($playerIds))) or id in (select distinct object_id from buildings where owner_id = '$guildId');
delete from buildings where owner_id in (select id from characters where playerid in ($playerIds)) or owner_id = '$guildId';
delete from item_properties where owner_id in (select id from characters where playerid in ($playerIds)) or owner_id = '$guildId';
delete from item_inventory where owner_id in (select id from characters where playerid in ($playerIds)) or owner_id = '$guildId';
delete from actor_position where id in (select id from characters where playerid in ($playerIds)) or id = '$guildId';
delete from characters where playerid in ($playerIds);
delete from guilds where guildid = '$guildId';"

# fixes characters unable to log in or stuck in nowhere
$fixLostCharacterQuery = "update actor_position set x='59939.539063', y='310979.625', z='-21411.023438' where x = '1.0' or x = '0.0';"
# update player name query
$updateNameQuery = "update characters set char_name = '$newName' where char_name = '$oldname';"

# list all players and guilds on server
$listCharsInGuildQuery = "
select quote(g.name) as GUILD, quote(g.guildid) as GUILDid, quote(c.char_name) as NAME, 
case c.rank WHEN '2' then 'Leader' WHEN '1' then 'Officer' WHEN '0' then 'Peon' ELSE c.rank 
END RANK, c.level as LEVEL, quote(c.playerid) as STEAMid, quote(c.id) as DBid from guilds g 
inner join characters c on g.guildid = c.guild order by g.name, c.rank desc, c.level desc, c.char_name;"
$listCharsNoGuildQuery = "select quote(char_name) as NAME, level as LEVEL, quote(playerID) as STEAMid, 
quote(id) as DBid from characters where id not in (select distinct c.id from guilds g inner join 
characters c on g.guildid = c.guild order by g.name, c.rank desc, c.level desc, c.char_name) order by char_name, level;"

# DELETE OBJECTS FROM PLAYERS OR GUILDS WHO LONGER EXIST
$deleteEmptyPlayerOrGuildQuery = "delete from buildable_health where object_id in (select distinct object_id from buildings where owner_id not in (select id from characters) and owner_id not in (select guildid from guilds));
delete from building_instances where object_id in (select distinct object_id from buildings where owner_id not in (select id from characters) and owner_id not in (select guildid from guilds));
delete from properties where object_id in (select distinct object_id from buildings where owner_id not in (select id from characters) and owner_id not in (select guildid from guilds));
delete from actor_position where id in (select distinct object_id from buildings where owner_id not in (select id from characters) and owner_id not in (select guildid from guilds));
delete from item_properties where owner_id in (select distinct owner_id from buildings where owner_id not in (select id from characters) and owner_id not in (select guildid from guilds));
delete from properties where object_id in (select distinct object_id from properties where name like '%Player%') and object_id not in (select id from characters) and object_id not in (select guildid from guilds);
delete from item_inventory where owner_id in (select distinct owner_id from buildings where owner_id not in (select id from characters) and owner_id not in (select guildid from guilds));
delete from buildings where owner_id not in (select id from characters) and owner_id not in (select guildid from guilds);"

# function to count number of rows in table
function check-tableCount($database, $table)
{
$query = "SELECT COUNT(*) FROM $table;"
$res = Invoke-SqliteQuery -DataSource $database -Query $query
return $res
}

# function to search logs for pattern
function search-logs
{
        param(
            [Parameter(Mandatory=$true)]
            $files,
            [Parameter(Mandatory=$true)]
            [string]$pattern,
            [Parameter(Mandatory=$false)]
            [string]$pattern2,
            [Parameter(Mandatory=$false)]
            [string]$context='0,0')            
            # create empty array
            $result =@()            
            # define how many days past logs should be parsed
            write-host "Enter amount of days from today to look for logs. Example 5 looks 5 days back in logs." -ForegroundColor Yellow
            [uint16]$days = Read-Host -Prompt "Enter number of days"
            Write-Debug "Pattern $pattern Pattern2 $pattern2 Days $days Files $files"            
            $filesFiltered = $files | where {$_.LastWriteTime -ge (Get-Date).AddDays(-$days)}                       
            Write-Debug "Filtered $filesFiltered"
            # loop files, looking for certain pattern in each file
            write-host "Filtering logfiles for data (this takes a while).." -ForegroundColor Green
            foreach ($file in $filesFiltered)
            {
                # check if more than 1 match is requested
                if ($pattern2)
                {                    
                    $result += Get-Content $file.FullName | Select-String -Pattern $pattern -Context $context
                    $result += Get-Content $file.FullName | Select-String -Pattern $pattern2 -Context 0,1                    
                }
                else
                {                    
                    $result += Get-Content $file.FullName | Select-String -Pattern $pattern -Context $context
                }                
            }
            Write-Debug "Data found in logfiles: $result"
            return $result
}

$ascii = @'
   ______                                                     
  / ____/___  ____  ____ _____     ____ ___  ___  ____  __  __
 / /   / __ \/ __ \/ __ `/ __ \   / __ `__ \/ _ \/ __ \/ / / /
/ /___/ /_/ / / / / /_/ / / / /  / / / / / /  __/ / / / /_/ / 
\____/\____/_/ /_/\__,_/_/ /_/  /_/ /_/ /_/\___/_/ /_/\__,_/ 
'@

# dis the menu

while ($true) {
      [int]$userMenuChoice = 0
      # write options
        Write-Host ''
        write-host $ascii -ForegroundColor Red        
        Write-Host "`nWhats up? (Color determines risk of action, green = read only, yellow = safe changes, red = removing stuff)" -ForegroundColor Yellow
        Write-Host "1. Server report, bunch of info regarding server" -ForegroundColor Green
        Write-Host "2. Write chat logs to separate file" -ForegroundColor Green
	    Write-Host "3. Write logon logs to separate file" -ForegroundColor Green
	    Write-Host "4. List all characters and guilds on server" -ForegroundColor Green
        Write-Host "5. Update character name" -ForegroundColor Yellow
        Write-Host "6. Fix characters stuck in nowhere/unable to login" -ForegroundColor Yellow
        Write-Host "7. Deprected + Remove buildings from characters that has not logged on in x days below y level" -ForegroundColor Red
        Write-Host "8. Not Done - Delete specified Guild and characters including all their assets" -ForegroundColor Red
        Write-Host "9. Delete assets without owner or empty guild assets" -ForegroundColor Red
        Write-Host "10. Remove all campfires and bedrolls" -ForegroundColor Red
        Write-Host "11. Not Done - Remove ALL Single foundations" -ForegroundColor Red
        Write-Host "12. Optimize database (Always do this last)" -ForegroundColor Yellow
        Write-Host "13. I’ll be back! (exit)" -ForegroundColor Cyan
    
        [int]$userMenuChoice = Read-Host "Please choose an option"

        switch ($userMenuChoice) {
          1 # Server report, bunch of info regarding server
          {
            $allchars = Invoke-SqliteQuery -DataSource $database -Query $getCharsQuery
            $allGuilds = Invoke-SqliteQuery -DataSource $database -Query $getGuildQuery
            $allBuildInstances = Invoke-SqliteQuery -DataSource $database -Query $getBuildingsInstacesQuery
            $allBuildHealth = Invoke-SqliteQuery -DataSource $database -Query $getBuildingHealthQuery

            Write-Host "$(($allchars | where {$_.lastTimeOnline -notlike $null}).Count) characters have logged on since patch 14.03.2017 out of $($allchars.Count) characters on the server" -ForegroundColor Yellow
            Write-Host "These characters are: $($allchars | where {$_.lastTimeOnline -notlike $null} | select -ExpandProperty char_name)" -ForegroundColor Yellow

            Write-Host "There are $($allGuilds.Count) Guilds on the server" -ForegroundColor Green
            Write-Host "There are $($allBuildInstances.Count) Building Instances and $($allBuildHealth.Count) building pieces on the server" -ForegroundColor Cyan
          }
          2 # Write chat logs to separate file
	      {
            $chat = search-logs -files $files -pattern 'ChatWindow'            
            Write-Host "All chat logs written to file: $logsPath\chat_log_$now.log"
            $chat | Out-File "$logsPath\chat-log_$now.log"
	      }
	      3 # Write logon logs to separate file
	      {
            $logins = search-logs -files $files -pattern 'Login request' -pattern2 'NotifyAcceptedConnection:' -context '0,2'
            Write-Host "All logins written to file: $("$logsPath\logins_$now.log")"
            $logins | Out-File "$logsPath\logins_$now.log"
	      }
	      4 # List all characters and guilds on server
	      { 
            
            write-host "Getting data from database" -ForegroundColor Green
            $guildChars = Invoke-SqliteQuery -DataSource $database -Query $listCharsInGuildQuery
            $soloChars = Invoke-SqliteQuery -DataSource $database -Query $listCharsNoGuildQuery
            Write-Host "Data written to file: $("$logsPath\character_list_$now.log")"
            $guildChars | Out-File "$logsPath\character_list_$now.log"
            $soloChars| Out-File "$logsPath\character_list_$now.log" -Append
            $guildChars | Out-GridView -Title 'Characters in clan'
            $soloChars | Out-GridView -Title 'Characters without clan'
	      }
          5 # Update character name
          {
          # create false variable
            $testCharName = $false
            Write-Host "Please note that character name is case sensitive" -ForegroundColor Yellow
            $oldName = Read-Host -Prompt "Insert old name of character to change"
            # create query
            $findCharQuery = "select char_name from characters where char_name = '$oldName' ;"
            # test if character is found in db using the name
            $testCharName = Invoke-SqliteQuery -DataSource $database -Query $findCharQuery
            # if not found, keep prompting until found
            while (!$testCharName)
            {
                Write-Host "Name not found, please try again!" -ForegroundColor Red
                $oldName = Read-Host -Prompt "Insert old name of character to change"            
                $findCharQuery = "select char_name from characters where char_name = '$oldName' ;"                
                $testCharName = Invoke-SqliteQuery -DataSource $database -Query $findCharQuery
            }
            write-host "$oldName found!" -ForegroundColor Green
            $newName = Read-Host -Prompt "Insert new name of character"
            # change to new name given by users
            $updateNameQuery = "update characters set char_name = '$newName' where char_name = '$oldname';"
            Invoke-SqliteQuery -DataSource $database -Query $updateNameQuery
            Write-Host "Name changed!" -ForegroundColor Green
            
          }
          6 # fix stuck
          {
            write-host "Running query.." -ForegroundColor Green
            Invoke-SqliteQuery -DataSource $database -Query $fixLostCharacterQuery
            write-host "Stuck characters should now be fixed" -ForegroundColor Green
          }
          7 # Remove buildings from characters that has not logged on in x days below y level
          { write-host "No longer recommended, use the built in decay system instead" -ForegroundColor Yellow
            Write-Host "Do you still wish to continue?" -ForegroundColor Red
            $choice = Read-Host -Prompt "y/n"
                        
            if ($choice -notlike 'y')
            {
                break
            }
            
            Write-host 'Please note that this script is only as good as the logs it reads. 
If there are only logs for today, it will think everyone who has not logged in today should be cleaned.
Make sure to save log files for as long back as possible for optimal results.' -ForegroundColor Yellow
            
            # chars with logon data
            #$allchars | where {$_.lastTimeOnline -notlike $null}            

            # search logs, add result to array
            $logons = search-logs -files $files -pattern 'Dreamworld:Display: PreLogin'

            # declare array
            $logonsClean =@()

            # convert match object to string object
            foreach ($line in $logons)
            {
                $logonsClean += $line.ToString()
            }

            # remove all but id from row
            $i = 0
            foreach ($line in $logonsClean)
            {
                $logonsClean[$i] = $line.Substring(60)
                $i ++
            }

            # remove duplicate logins
            Write-Debug "Count of rows before filtering unique $($logonsClean.count)"
            $logonsClean = $logonsClean | select -Unique
            Write-Debug "Count of rows after filtering unique $($logonsClean.count)"
            
            # get all characters from database using query
            $allchars = Invoke-SqliteQuery -DataSource $database -Query $getCharsQuery
            Write-Debug "Characters found in database: $allChars"

            # filter for level
            write-host 'Filter characters based on level, example would be to filter out all characters below level 10 to be cleaned.' -ForegroundColor Yellow
            $level = 51
            while ($level -gt 50 -or $level -lt 1)
            {
                $level = read-host -Prompt "Enter level to filter below, 10 will filter for 9 and below, value must be between 1-50"
                Write-Debug "Level set to $level"
            }

            write-host "$(($allChars | Where-Object {$_.level -lt $level}).count) characters found to be below level $level in the database." -ForegroundColor Yellow
            
            # get all id's not present in logons, output to file
            $diff = ($allChars | Where-Object {$_.level -lt $level} | Select playerID) | where {$logonsClean -notcontains $_}
            $diff | out-file "$logsPath\Not_logged_on_$now.txt"
            #Write-Host "The following players will have their buildings cleared: $($allChars | Where-Object {$_.level -lt $level} | select char_name)"
            write-host "$($diff.count) characters has not logged in since $oldest that is below level $level" -ForegroundColor Yellow
            Write-Host "Character ID's written to $logsPath\Not_logged_on_$now.txt" -ForegroundColor Green
            
            Write-Host "Do you wish to delete all buildings with the owned ID's of found characters? This will not include Clans, all characters in a Clan will be unaffected since Clans own all buildings of members." -ForegroundColor Red
            $choice = Read-Host -Prompt "y/n"

            $i = 0
            if ($choice -like 'y')
            {
                Copy-Item "$conanPath\ConanSandbox\Saved\game.db" "$conanPath\ConanSandbox\Saved\backup_cleanup_$($now)_game.db"
                write-host "Making backup of database; $conanPath\ConanSandbox\Saved\backup_cleanup_$($now)_game.db" -ForegroundColor Yellow
                foreach ($playerId in $diff)
                {
                    $i++
                    # convert from playerId to id
                    $idQuery = "SELECT id, char_name from characters where playerId = '$($playerId.playerId)'"
                    
                    # get id
                    $id = Invoke-SqliteQuery -DataSource $database -Query $idQuery                    
                    $idclean = $id.id          
                    
                    # query needs to be in loop for correct ID to be set
                    $deleteQuery="delete from buildable_health where object_id in (select object_id from buildings where owner_id = '$idclean');
                    delete from building_instances where object_id in (select object_id from buildings where owner_id = '$idclean');
                    delete from properties where object_id in (select object_id from buildings where owner_id = '$idclean') and name not like '%Spawn%';
                    delete from buildings where owner_id = '$idclean';
                    delete from item_inventory where owner_id = '$idclean';"                
        
                    Invoke-SqliteQuery -DataSource $database -Query $deleteQuery
                    write-host "Deleting number $i/$($diff.count), Char_Name: $($id.char_name)"        
                }

            }
            else {write-host 'No action taken.' -ForegroundColor Yellow}
            #>
          }
          8 # Delete specified Guild and characters including all their assets
          {
            Write-Host "Coming Soon.."
          }
          9 # Delete assets without owner or empty guild asset
          {          
           Write-Host "Do you wish to remove assets without owner or in empty guilds?" -ForegroundColor Yellow
           
            $choice = Read-Host -Prompt "y/n"
            if ($choice -like 'y')
            {
                Copy-Item "$conanPath\ConanSandbox\Saved\game.db" "$conanPath\ConanSandbox\Saved\backup_remove_empty_$($now)_game.db"
                write-host "Making backup of database; $conanPath\ConanSandbox\Saved\backup_remove_empty_$($now)_game.db" -ForegroundColor Yellow                
                $countBefore = check-tableCount -database $database -table 'buildable_health'
                Write-Host "Buildable Health row count before change: $($countBefore.'COUNT(*)')"
                write-host "Running query.." -ForegroundColor Yellow
                Invoke-SqliteQuery -DataSource $database -Query $deleteEmptyPlayerOrGuildQuery
                $countAfter = check-tableCount -database $database -table 'buildable_health'
                Write-Host "Buildable Health row count after change: $($countAfter.'COUNT(*)')"
            }
            else {write-host 'No action taken.' -ForegroundColor Yellow}            
          }
          10 # Remove all campfires and bedrolls
          {          
            Write-Host "Do you wish to remove all bedrolls and campfires?" -ForegroundColor Yellow
            $choice = Read-Host -Prompt "y/n"
            if ($choice -like 'y')
            {
                Copy-Item "$conanPath\ConanSandbox\Saved\game.db" "$conanPath\ConanSandbox\Saved\backup_bedrolls_$($now)_game.db"
                write-host "Making backup of database; $conanPath\ConanSandbox\Saved\backup_bedrolls_$($now)_game.db" -ForegroundColor Yellow                
                Write-Host "Running query on datbase.." -ForegroundColor Yellow
                Invoke-SqliteQuery -DataSource $database -Query $deleteMiscQuery
            }
            else {write-host 'No action taken.' -ForegroundColor Yellow}
          }
          11 # Not Done - Remove ALL Single foundations
          {
            
          }
          12 # Optimize database
          {            
            Write-Host "Do you wish to perform database optimization? (remove unsed space, reindex, analyze, check integrity)" -ForegroundColor Yellow
            $choice = Read-Host -Prompt "y/n"
            if ($choice -like 'y')
            {
                Copy-Item "$conanPath\ConanSandbox\Saved\game.db" "$conanPath\ConanSandbox\Saved\backup_optimize_$($now)_game.db"
                write-host "Making backup of database; $conanPath\ConanSandbox\Saved\backup_optimize_$($now)_game.db" -ForegroundColor Yellow                
                $sizeBefore = Get-ChildItem $database
                Write-Host "Size of database before optimization: $([math]::Round($sizeBefore.Length / 1MB, 2))MB" -ForegroundColor Yellow
                write-host "Running query.." -ForegroundColor Yellow
                $res = Invoke-SqliteQuery -DataSource $database -Query $optimizeQuery
                $sizeAfter = Get-ChildItem $database
                Write-Host "Size of database after optimization: $([math]::Round($sizeAfter.Length / 1MB, 2))MB" -ForegroundColor Green
                write-host "Database integrity check: $($res.integrity_check)" -ForegroundColor Yellow
            }
            else {write-host 'No action taken.' -ForegroundColor Yellow}

          }
          13 # I’ll be back! (exit)
          {
            write-host "Bye!" -ForegroundColor Cyan
            write-host $sword -ForegroundColor Red
            Start-Sleep -Seconds 3
            exit
          }
          default {Write-Host "Nothing selected" -ForegroundColor Red}
          
        }
      #}
    }  
