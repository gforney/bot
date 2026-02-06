@echo off
setlocal

set error=0
set option=%1

call :getopts %*

set gawk=..\..\Scripts\bin\gawk.exe

if %option% == 1 goto skip1
call :getfile FDS_INFO.txt
grep FDS_HASH     output\FDS_INFO.txt | %gawk% "{print $2}" > output\FDS_HASH
grep SMV_HASH     output\FDS_INFO.txt | %gawk% "{print $2}" > output\SMV_HASH
grep FDS_REVISION output\FDS_INFO.txt | %gawk% "{print $2}" > output\FDS_REVISION
grep SMV_REVISION output\FDS_INFO.txt | %gawk% "{print $2}" > output\SMV_REVISION
goto eof

:skip1
set CURDIR=%CD%
cd ..\..\..\fds
git describe | %gawk% "{ sub(/-[^-]+$/, \"\"); print }"            > output\FDS_REVISION
git describe | %gawk% "{ match($0, /-g([^-]+)$/, a); print a[1] }" > output\FDS_HASH

cd ..\smv
git describe | %gawk% "{ sub(/-[^-]+$/, \"\"); print }"            > output\SMV_REVISION
git describe | %gawk% "{ match($0, /-g([^-]+)$/, a); print a[1] }" > output\SMV_HASH

cd %CURDIR%
goto eof


::-----------------------------------------------------------------------
:getfile
::-----------------------------------------------------------------------
set file=%1
if exist output\%file% erase output\%file%

echo downloading %file%
gh release download FDS_TEST -p %file% -R github.com/firemodels/test_bundles -D output
if NOT exist output\%file% echo failed
exit /b

::-----------------------------------------------------------------------
:getopts
::-----------------------------------------------------------------------
 set stopscript=
 if (%1)==() exit /b
 set valid=0
 set arg=%1
 if /I "%1" EQU "-h" (
   call :usage
   set stopscript=1
   exit /b
 )
 shift
 if %valid% == 0 (
   echo.
   echo ***Error: the input argument %arg% is invalid
   echo.
   echo Usage:
   call :usage
   set stopscript=1
   exit /b 1
 )
if not (%1)==() goto getopts
exit /b 0

::-----------------------------------------------------------------------
:usage
::-----------------------------------------------------------------------

:usage
echo This script gets fds and smv repo hashes and revision from a github release
echo.
echo Options:
echo -h - display this message
exit /b 0

:eof

if "%error%" == "1" exit /b 1
exit /b 0
 
