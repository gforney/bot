@echo off
setlocal
call "%~dp0config.bat"
for %%I in ("%~dp0..\..\..") do set "gitroot=%%~fI"

call :GETREV cad   "%BUNDLE_CAD_HASH%"   "%BUNDLE_CAD_TAG%"
call :GETREV cfast "%BUNDLE_CFAST_HASH%" "%BUNDLE_CFAT_TAG%"
call :GETREV exp   "%BUNDLE_EXP_HASH%"   "%BUNDLE_EXP_TAG%"
call :GETREV fds   "%BUNDLE_FDS_HASH%"   "%BUNDLE_FDS_TAG%"
call :GETREV fig   "%BUNDLE_FIG_HASH%"   "%BUNDLE_FIG_TAG%"
call :GETREV out   "%BUNDLE_OUT_HASH%"   "%BUNDLE_OUT_TAG%"
call :GETREV smv   "%BUNDLE_SMV_HASH%"   "%BUNDLE_SMV_TAG%"
exit /b

:GETREV
pushd "%gitroot%\%~1" || exit /b 1
set "REPOVERSION="
set "HASH="
for /f "delims=" %%I in ('git describe --dirty --long') do set "REPOVERSION=%%I"
for /f "delims=" %%I in ('git rev-parse --short HEAD') do set "HASH=%%I"
echo repo   %REPOVERSION%
echo config %~3
echo repo   %HASH%
echo config %~2
echo(
popd
exit /b
