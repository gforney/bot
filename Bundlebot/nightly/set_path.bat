@echo off
setlocal DisableDelayedExpansion
rem PowerShell handles PATH strings; setx.exe performs persistent writes.
set "SET_PATH_SELF=%~f0"
set "SET_PATH_COUNT=0"
:collect_args
if "%~1"=="" goto run
set "SET_PATH_ARG_%SET_PATH_COUNT%=%~1"
set /a SET_PATH_COUNT+=1 >nul
shift
goto collect_args
:run
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -Command "$s=[IO.File]::ReadAllText($env:SET_PATH_SELF); & ([scriptblock]::Create($s.Substring($s.LastIndexOf('# POWERSHELL BODY')+17)))"
exit /b %errorlevel%
# POWERSHELL BODY
$ErrorActionPreference = 'Stop'
function Usage {
    @'
set_path [-s|-u] [-a entry|-f entry|-r label] [-d] [-m] [-b] [-p] [-t]
Modify or display the User or System PATH environment variable.
  -a entry   Append entry (unless already present, ignoring case).
  -f entry   Prepend entry (unless already present, ignoring case).
  -r label   Remove all entries containing label, ignoring case.
  -s         Select System PATH (writing requires administrator rights).
  -u         Select User PATH (default).
  -d         Display PATH before and after changes.
  -m         Display a summary of changes.
  -b         Disable the default removal prompt in scripts.
  -p         Explicitly prompt before changes, including with -b.
  -t         Show changes without writing PATH or creating backups.
  -h, -help, -help_all   Display help.
  -v, -version          Display wrapper version and optional file hashes.
  -md5, -sha1, -sha256, -hash_all, -hash_none   Select version hashes.
Quote entries containing spaces or shell characters. The last operation and
scope specified take precedence. Backups are saved in the current directory
as User_path_backup.txt or System_path_backup.txt (with numbered suffixes).
Requires Windows PowerShell and setx.exe. Changes affect future processes.
setx expands environment references and cannot safely write over 1024 characters;
this wrapper refuses such writes. Use set_path.exe for longer PATH values.
'@
}
try {
    $arguments = @(for ($i = 0; $i -lt [int]$env:SET_PATH_COUNT; $i++) {
        [Environment]::GetEnvironmentVariable("SET_PATH_ARG_$i")
    })
    if ($arguments.Count -eq 0) { Usage; exit 1 }
    $scope = 'User'; $operation = ''; $entry = ''
    $display = $false; $summary = $false; $batch = $false
    $prompt = $false; $test = $false; $version = $false; $hash = 'SHA256'
    for ($i = 0; $i -lt $arguments.Count; $i++) {
        switch -CaseSensitive ($arguments[$i]) {
            { $_ -in '-h', '-help', '-help_all' } { Usage; exit 1 }
            { $_ -in '-v', '-version' } { $version = $true }
            '-md5' { $hash = 'MD5' }
            '-sha1' { $hash = 'SHA1' }
            '-sha256' { $hash = 'SHA256' }
            '-hash_all' { $hash = 'all' }
            '-hash_none' { $hash = 'none' }
            '-u' { $scope = 'User' }
            '-s' { $scope = 'System' }
            '-d' { $display = $true }
            '-m' { $summary = $true }
            '-b' { $batch = $true }
            '-p' { $prompt = $true }
            '-t' { $test = $true }
            { $_ -in '-a', '-f', '-r' } {
                $operation = $_
                $i++
                if ($i -ge $arguments.Count -or [string]::IsNullOrEmpty($arguments[$i])) {
                    throw "Missing entry for $operation."
                }
                $entry = $arguments[$i]
            }
            default { throw "Unknown argument: $_. Use -help for usage." }
        }
    }
    if ($version) {
        'set_path.bat 1.0 (setx.exe wrapper)'
        if ($hash -ne 'none') {
            $algorithms = @($hash)
            if ($hash -eq 'all') { $algorithms = @('MD5', 'SHA1', 'SHA256') }
            foreach ($algorithm in $algorithms) {
                $digest = Get-FileHash -LiteralPath $env:SET_PATH_SELF -Algorithm $algorithm
                '{0}: {1}' -f $algorithm, $digest.Hash
            }
        }
        exit 1
    }
    # Read the selected registry value without expanding %references%.
    # The process PATH combines scopes and must never be used here.
    if ($scope -eq 'User') {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
    } else {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment')
    }
    $old = ''
    if ($null -ne $key) {
        try { $old = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
        finally { $key.Dispose() }
    }
    if ($display -or $test -or $operation -eq '') { "  ${scope} path:"; $old }
    if ($operation -eq '') { exit 0 }
    $entries = @($old.Split(';') | Where-Object { $_.Length -gt 0 })
    if ($operation -eq '-r') {
        $remaining = @($entries | Where-Object { $_.IndexOf($entry, [StringComparison]::OrdinalIgnoreCase) -lt 0 })
        if ($remaining.Count -eq $entries.Count) {
            if ($summary) { "  $entry not found in the $scope path." }
            exit 0
        }
        $new = $remaining -join ';'
    } else {
        if ($entries -contains $entry) {
            if ($summary) { "  $entry already present in the $scope path." }
            exit 0
        }
        if ($old.Length -eq 0) { $new = $entry }
        elseif ($operation -eq '-a') { $new = "$old;$entry" }
        else { $new = "$entry;$old" }
    }
    $new = $new.TrimEnd(';')
    if ($test) { "Setting $scope path to: $new"; exit 0 }
    if ($prompt -or ($operation -eq '-r' -and -not $batch)) {
        "`nSet $scope path to:"; $new
        $answer = Read-Host 'y=yes, n=no'
        if ($answer -notmatch '^\s*[yY]') { exit 0 }
    }
    # Check the expanded value because setx expands references when writing.
    $value = [Environment]::ExpandEnvironmentVariables($new)
    if ($value.Length -gt 1024) { throw 'PATH exceeds the setx limit of 1024 characters. No changes made; use set_path.exe.' }
    if ($value -match '[%~]') { throw 'PATH contains unresolved setx environment references (% or ~). No changes made; use set_path.exe.' }
    if ($value.Length -eq 0) { throw 'setx cannot write an empty PATH. No changes made; use set_path.exe.' }
    $setx = Join-Path $env:SystemRoot 'System32\setx.exe'
    if (-not (Test-Path -LiteralPath $setx)) { throw "setx.exe not found: $setx" }
    $backupBase = Join-Path (Get-Location).Path "${scope}_path_backup"
    $backup = "$backupBase.txt"
    $number = 0
    while (Test-Path -LiteralPath $backup) {
        $number++
        $backup = '{0}_{1:000}.txt' -f $backupBase, $number
    }
    [IO.File]::WriteAllText($backup, "$scope Path`r`n$old`r`n", [Text.Encoding]::Unicode)
    # Windows native argument quoting, including quotes and trailing backslashes.
    $quoted = '"' + ([regex]::Replace($value, '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $setx
    $start.Arguments = 'Path ' + $quoted
    if ($scope -eq 'System') { $start.Arguments += ' /M' }
    $start.UseShellExecute = $false
    $process = [Diagnostics.Process]::Start($start)
    $process.WaitForExit()
    $status = $process.ExitCode
    $process.Dispose()
    if ($status -ne 0) { throw "setx.exe failed (exit $status). Backup: $backup" }
    if ($summary) {
        if ($operation -eq '-r') { "  All directories containing $entry were removed from the $scope path." }
        else { "  $entry was added to the $scope path." }
        '  Open a new command window for PATH changes to take effect.'
    }
    if ($display) { "`n  $scope path set to:"; $value }
    exit 0
} catch {
    [Console]::Error.WriteLine('set_path: ' + $_.Exception.Message)
    exit 1
}
