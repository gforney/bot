@echo off
set CURDIR=%CD%

:: build and upload bundle
call run_bundlebot -c

:: build but don't upload bundle (for testing)
:: call run_bundlebot -c -U
cd %CURDIR%
echo complete