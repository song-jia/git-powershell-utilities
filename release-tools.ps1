<#
.DESCRIPTION
USAGE
    .\release-tools.ps1 <command>

COMMANDS
    fetch-all   run `git fetch` in all folders under specified folder
    compare     compare release branch with target branch.
#>

param(
    [Parameter(Position=0)]
    [ValidateSet("rev-list", "fetch-all")]
    [string]$Command,
    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Rest
)

function Command-Help { Get-Help $PSCommandPath }

if (!$Command) {
    Command-Help
    exit
}

$ExecutingDirectory = (Get-Location).Path

function getGitFolders($dir) {
    $Folders = Get-ChildItem -Path $dir -Directory

    $GitFolders = New-Object System.Collections.Generic.List[string]
    
    foreach ($Folder in $Folders) {
    
        # Check if we have a .git folder in the directory
        $FilePath = $Folder | Select-Object -ExpandProperty FullName    
        $HasGit = Get-ChildItem -Path $FilePath -Directory -Hidden -Filter .git
    
        # Save off folders that are managed by git
        if ($NULL -ne $HasGit) {
            $GitFolders.Add($FilePath)
        }
    }

    return $GitFolders
}

function FetchAll {
<#
.SYNOPSIS
fetch all repos in the specified directory.

.DESCRIPTION
USAGE
    .\release-tools.ps1 fetch-all <command>

COMMANDS
    directory     the path of working directory
#>
    param(
        [Parameter(Position=0)]
        [string]$dir
    )

    if (!$dir) {
        Get-Help FetchAll
        Exit
    }

    $folders = getGitFolders $dir
    $totalItems = $folders.Count
    $CurrentItem = 0
    $PercentComplete = 0

    foreach ($folder in $folders) {
        Write-Progress -Activity "Fetching $folder" -Status "$CurrentItem of $totalItems complete" -PercentComplete $PercentComplete
        Invoke-Expression "git -C $folder fetch -ap"
        $CurrentItem++
        $PercentComplete = [int](($CurrentItem / $TotalItems) * 100)
    }
}

function RevList() {
<#
.SYNOPSIS
execute git-rev-list on each repo.

.DESCRIPTION
USAGE
    .\release-tools.ps1 rev-list <command>

COMMANDS
    directory     the path of working directory
    branch-suffix  branch suffix, ex. master_23.1 is created base on master, the suffix is _23.1
#>
    param(
        [Parameter(Position=0)]
        [string]$dir,
        [Parameter(Position=1)]
        [string]$branchSuffix
    )

    if (!$dir -or !$branchSuffix) {
        Get-Help RevList
        Exit
    }

    $gitFolders = getGitFolders $dir
    $result = [System.Collections.ArrayList]::new()

    # Pulls the latest code from git
    foreach ($folder in $gitFolders) {
        Write-Host $folder
        Set-Location -LiteralPath $folder
        #git fetch -ap

        $Branches = git branch -a

        foreach($Branch in $Branches) {
            if ($Branch -match "^.*\/(.*)$branchSuffix$") { 
                $ReleaseBranch = $Branch.Trim()
                break
            }
        }

        $OriginalBranch = $ReleaseBranch.Replace($branchSuffix, '');

        Write-Information -MessageData ('Comparing ' + $OriginalBranch + ' and ' + $ReleaseBranch) -InformationAction Continue

        $compareRes = Invoke-Expression "git -C $folder rev-list --left-right --count $OriginalBranch...$ReleaseBranch"

        if ($compareRes -match '^(\d+)\s*(\d+)')
        {
            if ($Matches[1] -gt 0) {
                $warningMessage = $Matches[1] + ' new commits found on '+$OriginalBranch
                Write-Warning $warningMessage
            }
            else {
                Write-Information 'No new commit' -InformationAction Continue
            }

            $result.Add([PSCustomObject]@{
                Name = $folder
                Behind = $Matches[1]
                Ahead = $Matches[2]
            })
        }
        else {
            $errorMessage = 'Failed to compare ' + $OriginalBranch + $ReleaseBranch
        Write-Error $errorMessage
        }
    }


    $result | Format-Table
}

switch($command) {
    "fetch-all" {
        FetchAll @Rest
    }
    "rev-list" {
        RevList @Rest
    }
}

# Reset our execution directory
Set-Location -LiteralPath $ExecutingDirectory
Exit