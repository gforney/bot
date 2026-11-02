@echo off
setlocal
for %%I in ("%~dp0..\..\..") do set "FMROOT=%%~fI"
set "MODE=%~1"
if "%MODE%"=="reset" goto configured
if not exist "%~dp0config.bat" exit /b 1
call "%~dp0config.bat"
if errorlevel 1 exit /b 1
:configured
set "STATUS=0"
call :REPO cad "%BUNDLE_CAD_TAG%" "%BUNDLE_CAD_HASH%"
call :REPO cfast "%BUNDLE_CFAST_TAG%" "%BUNDLE_CFAST_HASH%"
call :REPO exp "%BUNDLE_EXP_TAG%" "%BUNDLE_EXP_HASH%"
call :REPO fds "%BUNDLE_FDS_TAG%" "%BUNDLE_FDS_HASH%"
call :REPO fig "%BUNDLE_FIG_TAG%" "%BUNDLE_FIG_HASH%"
call :REPO out "%BUNDLE_OUT_TAG%" "%BUNDLE_OUT_HASH%"
call :REPO smv "%BUNDLE_SMV_TAG%" "%BUNDLE_SMV_HASH%"
exit /b %STATUS%

:REPO
setlocal
set "REPO=%~1"
set "TAG=%~2"
set "HASH=%~3"
if "%MODE%"=="reset" goto enter_repo
set "ERROR="
if not defined TAG set "ERROR=1"
if not defined HASH set "ERROR=1"
if defined ERROR echo ***Error: missing release tag or revision for %REPO% >&2
if not exist "%FMROOT%\%REPO%\" (
  echo ***Error: repository directory %FMROOT%\%REPO% does not exist >&2
  set "ERROR=1"
)
if defined ERROR goto repo_failed
:enter_repo
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
echo ----------------------------------------------
echo repo: %REPO%
if "%MODE%"=="reset" goto reset_repo
rem Capture output separately so Git failures are not hidden by FOR /F.
:make_temp
set "CHECKDIR=%TEMP%\SetRepoRevTags-%RANDOM%-%RANDOM%"
if exist "%CHECKDIR%" goto make_temp
mkdir "%CHECKDIR%" || exit /b 1
git remote > "%CHECKDIR%\remotes.txt"
if errorlevel 1 goto check_failed
set "HASREMOTE="
for /f "usebackq delims=" %%R in ("%CHECKDIR%\remotes.txt") do set "HASREMOTE=1"
if not defined HASREMOTE (
  echo ***Error: no remotes configured for %REPO%; cannot check tag %TAG% >&2
  goto check_failed
)
set "CHECKFAILED="
for /f "usebackq delims=" %%R in ("%CHECKDIR%\remotes.txt") do call :CHECK_REMOTE "%%R"
if defined CHECKFAILED goto check_failed
call :clean_temp
echo git checkout -B release %HASH%
git checkout -B release "%HASH%"
if errorlevel 1 (
  echo ***Error: checkout failed for %REPO% at %HASH% >&2
  exit /b 1
)
echo git tag -f -a %TAG% -m "tag for %TAG%"
git tag -f -a "%TAG%" -m "tag for %TAG%"
if errorlevel 1 (
  echo ***Error: creation of tag %TAG% failed for %REPO% >&2
  exit /b 1
)
exit /b 0

:CHECK_REMOTE
if defined CHECKFAILED exit /b 1
git ls-remote --tags "%~1" "refs/tags/%TAG%" > "%CHECKDIR%\tag.txt"
if errorlevel 1 (
  echo ***Error: cannot check tag %TAG% on remote %~1 for %REPO% >&2
  set "CHECKFAILED=1"
  exit /b 1
)
for %%F in ("%CHECKDIR%\tag.txt") do if %%~zF GTR 0 (
  echo ***Error: tag %TAG% is already published on remote %~1 for %REPO%; refusing to replace it >&2
  set "CHECKFAILED=1"
  exit /b 1
)
exit /b 0

:check_failed
call :clean_temp
exit /b 1

:clean_temp
del /q "%CHECKDIR%\remotes.txt" "%CHECKDIR%\tag.txt" >nul 2>&1
rmdir "%CHECKDIR%"
exit /b 0

:reset_repo
echo git checkout master
git checkout master
if errorlevel 1 (
  echo ***Error: checkout of master failed for %REPO% >&2
  exit /b 1
)
git show-ref --verify --quiet refs/heads/release
if errorlevel 2 (
  echo ***Error: cannot check release branch for %REPO% >&2
  exit /b 1
)
if errorlevel 1 exit /b 0
echo git branch -D release
git branch -D release
if errorlevel 1 (
  echo ***Error: removal of release branch failed for %REPO% >&2
  exit /b 1
)
exit /b 0
