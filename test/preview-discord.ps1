<#
.SYNOPSIS
  PowerShell wrapper around test/preview-discord.sh.

.DESCRIPTION
  PowerShell cannot execute a .sh file, and plain `bash` on Windows usually resolves to WSL rather
  than Git Bash. This finds Git Bash, checks the prerequisites, and forwards every argument
  through unchanged.

  Renders only; nothing is sent until you pass -send.

.EXAMPLE
  .\test\preview-discord.ps1
  .\test\preview-discord.ps1 --status failure
  .\test\preview-discord.ps1 --file build\libs\app.jar
  .\test\preview-discord.ps1 --send $env:WEBHOOK --lifecycle
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'

# `bash` on PATH is usually WSL, which has no Git Bash userland. Locate Git's bash directly.
$bash = $null
$candidates = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)
foreach ($candidate in $candidates) {
    if (Test-Path $candidate) { $bash = $candidate; break }
}
if (-not $bash) {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $guess = Join-Path (Split-Path (Split-Path $git.Source)) 'bin\bash.exe'
        if (Test-Path $guess) { $bash = $guess }
    }
}
if (-not $bash) {
    Write-Error "Git Bash not found. Install Git for Windows, or run the .sh script from a Git Bash prompt."
    exit 1
}

if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    Write-Host "jq is required and is not on your PATH." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  winget install jqlang.jq"
    Write-Host ""
    Write-Host "Then open a new terminal so the PATH change takes effect."
    exit 1
}

$script = Join-Path $PSScriptRoot 'preview-discord.sh'

# A Discord webhook URL is often copied out of a chat client as a markdown link,
# "[https://...](https://...)", which is not a URL. Catch that before the shell sees it.
foreach ($a in $Args) {
    if ($a -like '`[http*' -or $a -like '*`]`(http*') {
        Write-Error "That webhook looks like a pasted markdown link. Pass the plain URL only, with no brackets."
        exit 2
    }
}

& $bash $script @Args
exit $LASTEXITCODE
