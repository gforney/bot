@echo off
setlocal

set "SUFFIX=nightly_win"
set "INFO=FDS_INFO.txt"
set "TOC=FDS_TOC.txt"

del /q "%INFO%" "%TOC%" 2>nul
gh release download FDS_TEST -p "%INFO%" -D . -R github.com/firemodels/test_bundles
if errorlevel 1 exit /b 1

set "FDS_REVISION="
set "SMV_REVISION="
for /f "tokens=1,2" %%A in (%INFO%) do (
  if "%%A"=="FDS_REVISION" if not defined FDS_REVISION set "FDS_REVISION=%%B"
  if "%%A"=="SMV_REVISION" if not defined SMV_REVISION set "SMV_REVISION=%%B"
)

if not defined FDS_REVISION exit /b 1
if not defined SMV_REVISION exit /b 1

set "BUNDLENAME=%FDS_REVISION%_%SMV_REVISION%_%SUFFIX%.exe"
gh release view FDS_TEST -R github.com/firemodels/test_bundles | findstr /c:"%SUFFIX%" > "%TOC%"

for /f "tokens=2" %%A in (%TOC%) do (
  if "%%A"=="%BUNDLENAME%" echo %BUNDLENAME% exists
  if "%%A"=="%BUNDLENAME%" exit /b 1
)

echo %BUNDLENAME% does not exist
exit /b 0
