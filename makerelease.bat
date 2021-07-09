@echo off

setlocal

set releasenumber=%~1

if "%releasenumber%"=="" (echo Please specifiy version as sole argument && goto fail)

set release_name=togos-example-noise-programs_%releasenumber%
set release_dir=releases\%release_name%

md %release_dir% %release_dir%\locale\en
copy * %release_dir%\
copy locale\en\* %release_dir%\locale\en\

echo Files copied to %release_dir%.  Now make a zip (containing %release_name%) and upload it.

goto eof

:fail
exit /B 1

:eof
