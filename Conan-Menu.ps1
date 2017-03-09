<#    
      .SYNOPSIS   
        Awesome Conan Admin Script!
      .DESCRIPTION   
        Can optimize database, clean assets based on login time of character,
        remove all bedrolls/campfires, separate chatlogs to a new file,
        separate logon logs to a new file and maybe more..?
      .NOTES 
        Author: Jack Swedjemark (Wrexthor)
        Updated: 06-03-2017            
        Credit for sql queries: https://github.com/A15Bog/conanexilessql                                        
#>

# preparations

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

<#
Block 1
Find and set conan path
Set log path
#>

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

# database stuff

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

# queries
$getCharsQuery = 'SELECT playerID,id,char_Name,level,guild, lastTimeOnline FROM characters;'
$optimizeQuery = "PRAGMA default_cache_size=700000;PRAGMA cache_size=700000;PRAGMA PAGE_SIZE = 4096;VACUUM;REINDEX;ANALYZE;pragma integrity_check"
$deleteMiscQuery = "delete from buildable_health where object_id in (select distinct object_id from buildings where object_id in (select distinct object_id from properties where name like '%Bedroll%' or name like '%CampFire%'));
delete from building_instances where object_id in (select distinct object_id from buildings where object_id in (select distinct object_id from properties where name like '%Bedroll%' or name like '%CampFire%'));
delete from actor_position where id in (select distinct object_id from buildings where object_id in (select distinct object_id from properties where name like '%Bedroll%' or name like '%CampFire%'));
delete from item_inventory where template_id in ('12001','10001');
delete from buildings where object_id in (select distinct object_id from properties where name like '%Bedroll%' or name like '%CampFire%');
delete from properties where name like '%Bedroll%' or name like '%CampFire%';"


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
      while ($userMenuChoice -lt 1 -or $userMenuChoice -gt 4) {
        Write-Host ''
        write-host $ascii -ForegroundColor Red        
        Write-Host "`nWhats up?" -ForegroundColor Yellow
	    Write-Host "1. Optimize database"
        Write-Host "2. Remove buildings from characters that has not logged on in x days"
	    Write-Host "3. Remove all campfires and bedrolls"
	    Write-Host "4. NOT DONE! Write chat logs to separate file"
        Write-Host "5. NOT DONE! Write logon logs to separate file"
        Write-Host "6. Fail at life (exit)"
    
        [int]$userMenuChoice = Read-Host "Please choose an option"

        switch ($userMenuChoice) {
          1 # optimize
          { # runs a database optimization query
            Write-Host "Do you wish to perform database optimization? (remove unsed space, reindex, set cache to higher size, analyze, check integrity)" -ForegroundColor Yellow
            $choice = Read-Host -Prompt "y/n"
            if ($choice -like 'y')
            {
                Copy-Item "$conanPath\ConanSandbox\Saved\game.db" "$conanPath\ConanSandbox\Saved\backup_optimize_$($now)_game.db"
                write-host "Making backup of database; $conanPath\ConanSandbox\Saved\backup_optimize_$($now)_game.db" -ForegroundColor Yellow
                write-host "Running query.." -ForegroundColor Yellow
                $res = Invoke-SqliteQuery -DataSource $database -Query $optimizeQuery
                write-host "Database integrity check: $($res.integrity_check)" -ForegroundColor Yellow
            }
            else {write-host 'No action taken.' -ForegroundColor Yellow}
          }
          2 # remove old chars
	      {
            <#
            Part 1
            Read logfiles
            Write logins to file
            #>

            Write-host 'Please note that this script is only as good as the logs it reads. 
            If there are only logs for today, it will think everyone who has not logged in today should be cleaned.
            Make sure to save log files for as long back as possible for optimal results.' -ForegroundColor Yellow

            # create empty array
            $logons =@()
            # define how many days past logs should be parsed
            write-host "Enter amount of days from today to look for logs. Example 5 looks 5 days back in logs." -ForegroundColor Yellow
            $days = Read-Host -Prompt "Enter number of days"

            # read logfiles to memory
            write-host "Getting all .log files from $logsPath.." -ForegroundColor Green
            $files = get-childitem $logsPath -filter *.log -Recurse | where {$_.LastWriteTime -ge (Get-Date).AddDays(-$days)}

            # check oldest file found
            $oldest = (($files | sort LastWriteTime | select -first 1).LastWriteTime).ToShortDateString()
            Write-Host "Oldest logfile found is from $oldest" -ForegroundColor Yellow
            Write-Debug "Files found: $files"

            # loop files, looking for certain pattern in each file
            write-host "Filtering logfiles for login data (this takes a while).." -ForegroundColor Green
            foreach ($file in $files)
            {
                # add matches to array, include 2 lines after found match
                $logons += Get-Content $file.FullName | Select-String -Pattern 'Dreamworld:Display: PreLogin'
                Write-Debug "Logons found in logfiles: $logons"
            }

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


            <#
            Part 2
            Query databse for character info
            filter based on level
            #>

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

            <#
            Part 3
            Compare ID's from logfiles to filtered characters from database
            #>

            # get all id's not present in logons, output to file
            $diff = ($allChars | Where-Object {$_.level -lt $level} | Select playerID) | where {$logonsClean -notcontains $_}
            $diff | out-file c:\no-logons_$now.txt
            Write-Host "The following players will have their buildings cleared: $($allChars | Where-Object {$_.level -lt $level} | select char_name)"
            write-host "$($diff.count) characters has not logged in since $oldest that is below level $level" -ForegroundColor Yellow
            Write-Host "Character ID's written to c:\no-logons_$now.txt" -ForegroundColor Green
            
            <#
            Part 4
            Remove data from database
            #>

            Write-Host "Do you wish to delete all buildings with the owned ID's of found characters? This will not include Clans, 
            all characters in a Clan will be unaffected since Clans own all buildings of members." -ForegroundColor Red
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
                    $idQuery = "SELECT id from characters where playerId = '$($playerId.playerId)'"
                    
                    $id = Invoke-SqliteQuery -DataSource $database -Query $idQuery

                    $deleteQuery="delete from buildable_health where object_id in (select object_id from buildings where owner_id = '$($id.id)');
                    delete from building_instances where object_id in (select object_id from buildings where owner_id = '$($id.id)');
                    delete from properties where object_id in (select object_id from buildings where owner_id = '$($id.id)') and name not like '%Spawn%';
                    delete from buildings where owner_id = '$($id.id)';
                    delete from item_inventory where owner_id = '$($id.id)';"       
        
                    Invoke-SqliteQuery -DataSource $database -Query $deleteQuery
                    write-host "Deleting $i/$($diff.count)"        
                }

            }
            else {write-host 'No action taken.' -ForegroundColor Yellow}
          
	      }
	      3 # remove campfire
	      {
            <#
            Block 6
            Clean all bedrolls and campfires
            #>

            Write-Host "Do you wish to remove all bedrolls and campfires?" -ForegroundColor Yellow
            $choice = Read-Host -Prompt "y/n"
            if ($choice -like 'y')
            {
                Copy-Item "$conanPath\ConanSandbox\Saved\game.db" "$conanPath\ConanSandbox\Saved\backup_bedrolls_$($now)_game.db"
                write-host "Making backup of database; $conanPath\ConanSandbox\Saved\backup_bedrolls_$($now)_game.db" -ForegroundColor Yellow
                $deleteMiscQuery = "delete from buildable_health where object_id in (select distinct object_id from buildings where object_id in (select distinct object_id from properties where name like '%Bedroll%' or name like '%CampFire%'));
		delete from building_instances where object_id in (select distinct object_id from buildings where object_id in (select distinct object_id from properties where name like '%Bedroll%' or name like '%CampFire%'));
		delete from actor_position where id in (select distinct object_id from buildings where object_id in (select distinct object_id from properties where name like '%Bedroll%' or name like '%CampFire%'));
		delete from item_inventory where template_id in ('12001','10001');
		delete from buildings where object_id in (select distinct object_id from properties where name like '%Bedroll%' or name like '%CampFire%');
		delete from properties where name like '%Bedroll%' or name like '%CampFire%';"
                Invoke-SqliteQuery -DataSource $database -Query $deleteMiscQuery
            }
            else {write-host 'No action taken.' -ForegroundColor Yellow}          
	      }
	      4 # write char logs
	      { 
            write-host "No yet done, please come back later"
	      }
          5 # write logon logs
          {
            write-host "No yet done, please come back later"
          }
          6 # yet to be determined
          {
            write-host "Bye!" -ForegroundColor Cyan
            Start-Sleep -Seconds 3
            exit
          }
          default {Write-Host "Nothing selected" -ForegroundColor Red}
        }
      }
    }
