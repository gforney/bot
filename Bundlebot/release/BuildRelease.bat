@echo off
set "GUI_OPTION="
if /i "%~1" == "-gui" (
  set "GUI_OPTION=-gui"
  shift
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


set CURDIR=%CD%

call config.bat

echo cleaning bot repo
cd ..\..
git clean -dxf

set UPLOADBUNDLE=-u
:: uncomment following line to test script (does not upload bundle to github or run gh command)
:: set UPLOADBUNDLE=

cd %CURDIR%
cd ..\nightly
call BuildNightly -R %UPLOADBUNDLE% %GUI_OPTION%
set "BUILD_RESULT=%ERRORLEVEL%"
cd %CURDIR%
if defined GUI_OPTION if not "%BUILD_RESULT%" == "0" exit /b %BUILD_RESULT%

if "X%UPLOADBUNDLE%" == "X" goto :EOF
set "TITLE=Bundle Test - %BUNDLE_FDS_TAG%/%BUNDLE_FDS_HASH% - %BUNDLE_SMV_TAG%/%BUNDLE_SMV_HASH%"
gh release edit FDS_TEST -t %$TITLE% -R github.com/%username%/test_bundles
:EOF
exit /b

:usage
echo Usage: BuildRelease.bat [-gui] [-h]
echo -gui - build the Windows GUI installer with CPack and NSIS
echo -h - display this message
exit /b 0
