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

filter ColorTable {
    param(
        [string] $word,
        [string] $color
    )
    $lines = ($_ -split '\n')
    # $index = $line.IndexOf($word, [System.StringComparison]::InvariantCultureIgnoreCase)
    # while($index -ge 0){
    #     Write-Host $line.Substring(0,$index) -NoNewline
    #     Write-Host $line.Substring($index, $word.Length) -NoNewline -ForegroundColor $color
    #     $used = $word.Length + $index
    #     $remain = $line.Length - $used
    #     $line = $line.Substring($used, $remain)
    #     $index = $line.IndexOf($word, [System.StringComparison]::InvariantCultureIgnoreCase)
    # }

    foreach ($line in $lines) {
        Write-Host $line
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
    $totalItems = $gitFolders.Count
    $CurrentItem = 0
    $PercentComplete = 0
    $result = New-Object System.Collections.Generic.List[PSCustomObject]

    # Pulls the latest code from git
    foreach ($folder in $gitFolders) {
        Write-Progress -Activity "Checking $folder" -Status "$CurrentItem of $totalItems complete" -PercentComplete $PercentComplete

        # get all branches
        $Branches = Invoke-Expression "git -C $folder branch -a"

        foreach($Branch in $Branches) {
            if ($Branch -match "^.*\/(.*)$branchSuffix$") { 
                $ReleaseBranch = $Branch.Trim()
                break
            }
        }

        $OriginalBranch = $ReleaseBranch.Replace($branchSuffix, '');

        $compareRes = Invoke-Expression "git -C $folder rev-list --left-right --count $OriginalBranch...$ReleaseBranch"

        if ($compareRes -match '^(\d+)\s*(\d+)')
        {
            $result.Add([PSCustomObject]@{
                Name = $folder
                Behind = $Matches[1]
                Ahead = $Matches[2]
            })
        }
        else {
            $result.Add([PSCustomObject]@{
                Name = $folder
                Error = "Error"
            })
        }

        $CurrentItem = $CurrentItem + 1
        $PercentComplete = [int](($CurrentItem / $TotalItems) * 100)
    }

    $result | Format-Table | Out-String | ColorTable
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
