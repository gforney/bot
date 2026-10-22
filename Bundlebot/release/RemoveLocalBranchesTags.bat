@echo off
rem Delete local branches whose names are absent from every configured remote.
rem Also delete unpublished tags pointing at HEAD before checkout.
rem Check out master first; skip the repository if checkout fails.
rem Unmerged branches are deleted too. Checked-out branches are protected.
setlocal DisableDelayedExpansion
for %%I in ("%~dp0..\..\..") do set "FMROOT=%%~fI"
set "STATUS=0"
for %%R in (cad cfast exp fds fig out smv) do call :REPO %%R
exit /b %STATUS%

:REPO
setlocal
set "REPO=%~1"
echo ----------------------------------------------
echo repo: %REPO%
pushd "%FMROOT%\%REPO%" || goto repo_failed
call :PROCESS
set "RESULT=%ERRORLEVEL%"
popd
if not "%RESULT%"=="0" goto repo_failed
endlocal
exit /b 0
:repo_failed
endlocal & set "STATUS=1"
exit /b 1

:PROCESS
:make_temp
set "CHECKDIR=%TEMP%\RemoveLocalBranches-%RANDOM%-%RANDOM%"
if exist "%CHECKDIR%" goto make_temp
mkdir "%CHECKDIR%" || exit /b 1
git tag --points-at HEAD > "%CHECKDIR%\current-tags.txt"
if errorlevel 1 goto failed
echo git checkout master
git checkout master
if errorlevel 1 (
  echo ***Warning: cannot check out master in %REPO%; skipping this repository. Resolve modified files or other checkout errors and try again. >&2
  goto failed
)
echo git remote prune origin
git remote prune origin
if errorlevel 1 (
  echo ***Warning: cannot prune origin in %REPO%; skipping this repository. >&2
  goto failed
)

git remote > "%CHECKDIR%\remotes.txt"
if errorlevel 1 goto failed
set "HASREMOTE="
for /f "usebackq delims=" %%R in ("%CHECKDIR%\remotes.txt") do set "HASREMOTE=1"
if not defined HASREMOTE (
  echo ***Error: no remotes configured for %REPO%; skipping repository >&2
  goto failed
)
type nul > "%CHECKDIR%\remote-refs.txt"
set "QUERYFAILED="
for /f "usebackq delims=" %%R in ("%CHECKDIR%\remotes.txt") do (
  set "REMOTE=%%R"
  call :READ_REMOTE
)
if defined QUERYFAILED goto failed
git for-each-ref --format="%%(refname:strip=2)" refs/heads/ > "%CHECKDIR%\branches.txt"
if errorlevel 1 goto failed
git branch --show-current > "%CHECKDIR%\current.txt"
if errorlevel 1 goto failed
set "CURRENT="
set /p CURRENT=<"%CHECKDIR%\current.txt"
set "DELETEFAILED="
for /f "usebackq delims=" %%B in ("%CHECKDIR%\branches.txt") do (
  set "BRANCH=%%B"
  call :CHECK_BRANCH
)
for /f "usebackq delims=" %%T in ("%CHECKDIR%\current-tags.txt") do (
  set "TAG=%%T"
  call :CHECK_TAG
)
if defined DELETEFAILED goto failed
call :cleanup
exit /b 0

:READ_REMOTE
if defined QUERYFAILED exit /b 1
git ls-remote --heads --tags "%REMOTE%" > "%CHECKDIR%\remote.txt"
if errorlevel 1 (
  echo ***Error: cannot read branches and tags from remote "%REMOTE%" for %REPO%; skipping repository >&2
  set "QUERYFAILED=1"
  exit /b 1
)
for /f "usebackq tokens=2" %%H in ("%CHECKDIR%\remote.txt") do >> "%CHECKDIR%\remote-refs.txt" echo %%H
exit /b 0

:CHECK_BRANCH
if "%BRANCH%"=="%CURRENT%" (
  echo Skipping checked-out branch "%BRANCH%"
  exit /b 0
)
findstr /l /x /c:"refs/heads/%BRANCH%" "%CHECKDIR%\remote-refs.txt" >nul
if errorlevel 2 (
  echo ***Error: cannot compare remote branches for "%BRANCH%" >&2
  set "DELETEFAILED=1"
  exit /b 1
)
if not errorlevel 1 exit /b 0
echo git branch -D -- "%BRANCH%"
git branch -D -- "%BRANCH%"
if errorlevel 1 (
  echo ***Error: could not delete branch "%BRANCH%" for %REPO% >&2
  set "DELETEFAILED=1"
  exit /b 1
)
echo Removed local branch "%BRANCH%" from repository "%REPO%".
exit /b 0

:CHECK_TAG
findstr /l /x /c:"refs/tags/%TAG%" "%CHECKDIR%\remote-refs.txt" >nul
if errorlevel 2 (
  echo ***Error: cannot compare remote tags for "%TAG%" >&2
  set "DELETEFAILED=1"
  exit /b 1
)
if not errorlevel 1 exit /b 0
echo git tag -d -- "%TAG%"
git tag -d -- "%TAG%"
if errorlevel 1 (
  echo ***Error: could not delete tag "%TAG%" for %REPO% >&2
  set "DELETEFAILED=1"
  exit /b 1
)
echo Removed local tag "%TAG%" from repository "%REPO%".
exit /b 0

:failed
call :cleanup
exit /b 1

:cleanup
del /q "%CHECKDIR%\*.txt" >nul 2>&1
rmdir "%CHECKDIR%"
exit /b 0
