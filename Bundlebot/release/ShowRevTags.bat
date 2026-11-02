@echo off
setlocal
call "%~dp0config.bat"
for %%I in ("%~dp0..\..\..") do set "gitroot=%%~fI"

call :GETREV cad   "%BUNDLE_CAD_HASH%"   "%BUNDLE_CAD_TAG%"
call :GETREV cfast "%BUNDLE_CFAST_HASH%" "%BUNDLE_CFAST_TAG%"
call :GETREV exp   "%BUNDLE_EXP_HASH%"   "%BUNDLE_EXP_TAG%"
call :GETREV fds   "%BUNDLE_FDS_HASH%"   "%BUNDLE_FDS_TAG%"
call :GETREV fig   "%BUNDLE_FIG_HASH%"   "%BUNDLE_FIG_TAG%"
call :GETREV out   "%BUNDLE_OUT_HASH%"   "%BUNDLE_OUT_TAG%"
call :GETREV smv   "%BUNDLE_SMV_HASH%"   "%BUNDLE_SMV_TAG%"
exit /b

:GETREV
pushd "%gitroot%\%~1" || exit /b 1
set "REPOVERSION="
set "BRANCH="
for /f "delims=" %%I in ('git describe --dirty --long') do set "REPOVERSION=%%I"
for /f "delims=" %%I in ('git branch --show-current') do set "BRANCH=%%I"
echo repo version   %REPOVERSION%/%BRANCH%
echo config version %~3/%~2
echo(
popd
exit /b
