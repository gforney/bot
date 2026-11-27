@echo off
setlocal
set "GUI_OPTION="
:options
if "%~1" == "-u" (
  shift
  goto options
)
if /i "%~1" == "-gui" (
  set "GUI_OPTION=-gui"
  shift
  goto options
)
if /i "%~1" == "-h" goto usage
if not "%~1" == "" (
  echo *** error: unexpected argument "%~1"
  call :usage
  exit /b 1
)

if defined GUI_OPTION (
  where cpack.exe >nul 2>&1
  if errorlevel 1 (
    echo *** error: CPack was not found on PATH. Install CMake first.
    exit /b 1
  )
  where makensis.exe >nul 2>&1
  if errorlevel 1 (
    echo *** error: makensis.exe was not found on PATH. Install NSIS and add it to PATH.
    exit /b 1
  )
)


call "%~dp0..\bundle_lock.bat" acquire || exit /b 1
call :run_bundle
set "BUNDLE_BUILD_RESULT=%ERRORLEVEL%"
if defined BUNDLE_LOCK_OWNED call "%~dp0..\bundle_lock.bat" release
exit /b %BUNDLE_BUILD_RESULT%

:run_bundle
set "UPLOADOWNER=%USERNAME%"
call config

:: uncomment and edit the following lines if building a test bundle.
:: otherwise use settings in config.bat.
::set BUNDLE_SMV_HASH=9ce553208
::set BUNDLE_SMV_TAG=SMV-6.9.1test

set scan_bundle=1


set basename=%BUNDLE_SMV_TAG%_win
set fullfilebase=%userprofile%\.bundle\bundles\%basename%
set CURDIR=%CD%
set OUTDIR=%CURDIR%\output

cd ..\..\..
set GITROOT=%CD%
cd %CURDIR%

:: update web repo
if NOT exist ..\..\..\webpages echo *** error webpages repos does not exist
if NOT exist ..\..\..\webpages exit /b
cd ..\..\..\webpages
git remote update
git merge origin/nist-pages
cd %CURDIR%


:: clone smv repo
call clone_smv_repo  %BUNDLE_SMV_HASH% release %BUNDLE_SMV_TAG%

:: build apps
set progs=LIBS pnginfo part2iso fds2fed wind2fds smokeview
for %%x in ( %progs% ) do (
  cd %GITROOT%\smv\Build\%%x\intel_win
  echo *** building %%x
  call make_%%x > %OUTDIR%\stage4_%%x 2>&1
) 

:: make bundle
cd %CURDIR%
set "SMV_INSTALLER="
if defined GUI_OPTION set "SMV_INSTALLER=CPACK"
call make_smv_bundle %BUNDLE_SMV_TAG% %scan_bundle% %SMV_INSTALLER%
if defined GUI_OPTION if errorlevel 1 exit /b 1

:: upload bundles

echo uploading %fullfilebase%.exe
gh release upload SMOKEVIEW_TEST %fullfilebase%.exe  -R github.com/%UPLOADOWNER%/test_bundles --clobber
echo uploading %fullfilebase%_manifest.html
gh release upload SMOKEVIEW_TEST %fullfilebase%_manifest.html  -R github.com/%UPLOADOWNER%/test_bundles --clobber
exit /b

:usage
echo Usage: BuildSmvRelease.bat [-gui] [-h] [-u]
echo -gui - build the Windows GUI installer with CPack and NSIS
echo -h - display this message
echo -u - upload to the current Windows account's GitHub test_bundles repository
exit /b 0
