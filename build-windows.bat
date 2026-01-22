@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Enter the Node source folder
pushd node

rem Apply local patches, if any
for %%f in (../patches/*.patch) do (
    echo Applying %%f...
    git apply --reject --whitespace=fix "../patches/%%f"
)

rem Build Release and Debug DLLs (clang-cl, no tests, no npm)
call vcbuild.bat release x64 dll no-cctest clang-cl nonpm
call vcbuild.bat debug   x64 dll no-cctest clang-cl nonpm

rem Staging directories for packaging
set STAGE_ROOT=..\out
set STAGE_REL=%STAGE_ROOT%\Release
set STAGE_REL_LIB=%STAGE_REL%\lib
set STAGE_DBG=%STAGE_ROOT%\Debug
set STAGE_DBG_LIB=%STAGE_DBG%\lib

if not exist "%STAGE_REL%" mkdir "%STAGE_REL%"
if not exist "%STAGE_REL_LIB%" mkdir "%STAGE_REL_LIB%"
if not exist "%STAGE_DBG%" mkdir "%STAGE_DBG%"
if not exist "%STAGE_DBG_LIB%" mkdir "%STAGE_DBG_LIB%"

rem Helper to copy headers (*.h, *.hpp) recursively
rem Usage: call :copy_headers "src_dir" "dest_dir"
goto :after_functions
:copy_headers
    set SRC=%~1
    set DST=%~2
    if not exist "%DST%" mkdir "%DST%"
    rem robocopy returns codes <8 for success; ignore non-fatal codes
    robocopy "%SRC%" "%DST%" *.h   /S >nul & if errorlevel 8 exit /b %ERRORLEVEL%
    robocopy "%SRC%" "%DST%" *.hpp /S >nul & if errorlevel 8 exit /b %ERRORLEVEL%
    exit /b 0
:after_functions

echo Collect includes (node, uv, v8, openssl) into include/node
set INC_REL=%STAGE_REL%\include\node
set INC_DBG=%STAGE_DBG%\include\node

call :copy_headers "src"               "%INC_REL%"   || goto :fail
call :copy_headers "deps\uv\include"  "%INC_REL%\uv\include"   || goto :fail
call :copy_headers "deps\v8\include"  "%INC_REL%\v8\include"   || goto :fail
call :copy_headers "deps\openssl"      "%INC_REL%\openssl"       || goto :fail

call :copy_headers "src"               "%INC_DBG%"   || goto :fail
call :copy_headers "deps\uv\include"  "%INC_DBG%\uv\include"   || goto :fail
call :copy_headers "deps\v8\include"  "%INC_DBG%\v8\include"   || goto :fail
call :copy_headers "deps\openssl"      "%INC_DBG%\openssl"       || goto :fail

echo Locate built artifacts and copy/rename to expected names
echo %CWD%
set REL_BUILD=out\Release
set DBG_BUILD=out\Debug

copy /Y "%REL_BUILD%\libnode22.dll" "%STAGE_REL%\lib\libnode22.dll" >nul
copy /Y "%REL_BUILD%\libnode22.lib" "%STAGE_REL%\lib\libnode22.lib" >nul
copy /Y "%REL_BUILD%\libnode22.pdb" "%STAGE_REL%\lib\libnode22.pdb" >nul

copy /Y "%DBG_BUILD%\libnode22.dll" "%STAGE_DBG%\lib\libnode22.dll" >nul
copy /Y "%DBG_BUILD%\libnode22.lib" "%STAGE_DBG%\lib\libnode22.lib" >nul
copy /Y "%DBG_BUILD%\libnode22.pdb" "%STAGE_DBG%\lib\libnode22.pdb" >nul

echo Create tar.xz packages if tar (bsdtar) is available
where tar >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Creating archives...
    tar -cJf "%STAGE_ROOT%\libnode22-release.tar.xz" -C "%STAGE_REL%" .
    tar -cJf "%STAGE_ROOT%\libnode22-debug.tar.xz"   -C "%STAGE_DBG%" .
    echo Done: %STAGE_ROOT%\libnode22-release.tar.xz
    echo Done: %STAGE_ROOT%\libnode22-debug.tar.xz
) else (
    echo WARN: 'tar' not found. Skipping archive creation. Artifacts left in:
    echo   %STAGE_REL%
    echo   %STAGE_DBG%
)

popd
echo Windows Node build and packaging completed.
exit /b 0

:fail
popd
echo Build failed. See output above.
exit /b 1
