@echo OFF
setlocal

REM Defined cript variables
set YASMDL=http://www.tortall.net/projects/yasm/releases
set YASMVERSION=1.3.0
set VSWHEREDL=https://github.com/Microsoft/vswhere/releases/download
set VSWHEREVERSION=2.6.7

REM Store current directory and ensure working directory is the location of current .bat
set CALLDIR=%CD%
set SCRIPTDIR=%~dp0

REM Initialise error check value
set ERROR=0
REM Check if being called from another instance
if not "%~1"=="" (
    set MSVC_VER=%~1
    set VSINSTANCEDIR=%2
    set ISINSTANCE=1
    goto MSVCCALL
)

REM Check what architecture we are installing on
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo Detected 64 bit system...
    set SYSARCH=64
) else if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    if "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
        echo Detected 64 bit system running 32 bit shell...
        set SYSARCH=64
    ) else (
        echo Detected 32 bit system...
        set SYSARCH=32
    )
) else (
    echo Error: Could not detect current platform architecture!"
    goto Terminate
)

REM Check if already running in an environment with VS setup
if defined VCINSTALLDIR (
    if defined VisualStudioVersion (
        echo Existing Visual Studio environment detected...
        if "%VisualStudioVersion%"=="16.0" (
            set MSVC_VER=16
            goto MSVCVarsDone
        ) else if "%VisualStudioVersion%"=="15.0" (
            set MSVC_VER=15
            goto MSVCVarsDone
        ) else if "%VisualStudioVersion%"=="14.0" (
            set MSVC_VER=14
            goto MSVCVarsDone
        ) else if "%VisualStudioVersion%"=="12.0" (
            set MSVC_VER=12
            goto MSVCVarsDone
        ) else (
            echo Unknown Visual Studio environment detected '%VisualStudioVersion%', Creating a new one...
        )
    )
)

REM Get vswhere to detect VS installs
if exist "%SCRIPTDIR%\vswhere.exe" (
    echo Using existing vswhere binary...
    goto VSwhereDetection
)
set VSWHEREDOWNLOAD=%VSWHEREDL%/%VSWHEREVERSION%/vswhere.exe
echo Downloading required vswhere release binary...
powershell.exe -Command (New-Object Net.WebClient).DownloadFile('%VSWHEREDOWNLOAD%', '%SCRIPTDIR%\vswhere.exe') >nul 2>&1
if not exist "%SCRIPTDIR%\vswhere.exe" (
    echo Error: Failed to download required vswhere binary!
    echo    The following link could not be resolved "%VSWHEREDOWNLOAD%"
    echo    Now trying fallback detection..."
    goto MSVCRegDetection
)

:VSwhereDetection
REM Use vswhere to list detected installs
for /f "usebackq tokens=1* delims=: " %%i in (`"%SCRIPTDIR%\vswhere.exe" -products * -prerelease -requires Microsoft.Component.MSBuild`) do (
    if /i "%%i"=="installationPath" (
        for /f "delims=" %%a in ('echo %%j ^| find "2019"') do (
            if not "%%a"=="" (
                echo Visual Studio 2019 environment detected...
                call "%~0" "16" "%%j"
                if not ERRORLEVEL 1 (
                    set MSVC16=1
                    set MSVCFOUND=1
                )
            )
        )
        for /f "delims=" %%a in ('echo %%j ^| find "2017"') do (
            if not "%%a"=="" (
                echo Visual Studio 2017 environment detected...
                call "%~0" "15" "%%j"
                if not ERRORLEVEL 1 (
                    set MSVC15=1
                    set MSVCFOUND=1
                )
            )
        )
    )
)

REM Try and use vswhere to detect legacy installs
for /f "usebackq tokens=1* delims=: " %%i in (`"%SCRIPTDIR%\vswhere.exe" -legacy`) do (
    if /i "%%i"=="installationPath" (
        for /f "delims=" %%a in ('echo %%j ^| find "2015"') do (
            if not "%%a"=="" (
                echo Visual Studio 2015 environment detected...
                call "%~0" "13" "%%j"
                if not ERRORLEVEL 1 (
                    set MSVC13=1
                    set MSVCFOUND=1
                )
            )
        )
        for /f "delims=" %%a in ('echo %%j ^| find "2013"') do (
            if not "%%a"=="" (
                echo Visual Studio 2013 environment detected...
                call "%~0" "12" "%%j"
                if not ERRORLEVEL 1 (
                    set MSVC12=1
                    set MSVCFOUND=1
                )
            )
        )
    )
)
if not defined MSVCFOUND (
    echo Error: Failed to detect VS installations using vswhere!
    echo    Now trying fallback detection...
) else (
    goto Exit
)

:MSVCRegDetection
if "%SYSARCH%"=="32" (
    set MSVCVARSDIR=
    set WOWNODE=
) else if "%SYSARCH%"=="64" (
    set MSVCVARSDIR=\amd64
    set WOWNODE=\WOW6432Node
) else (
    goto Terminate
)
REM First check for a environment variable to help locate the VS installation
if defined VS140COMNTOOLS (
    if exist "%VS140COMNTOOLS%\..\..\VC\bin%MSVCVARSDIR%\vcvars%SYSARCH%.bat" (
        echo Visual Studio 2015 environment detected...
        call "%~0" "14" "%VS140COMNTOOLS%\..\..\"
        if not ERRORLEVEL 1 (
            set MSVC14=1
            set MSVCFOUND=1
        )
    )
)
if defined VS120COMNTOOLS (
    if exist "%VS120COMNTOOLS%\..\..\VC\bin%MSVCVARSDIR%\vcvars%SYSARCH%.bat" (
        echo Visual Studio 2013 environment detected...
        call "%~0" "12" "%VS120COMNTOOLS%\..\..\"
        if not ERRORLEVEL 1 (
            set MSVC12=1
            set MSVCFOUND=1
        )
    )
)

REM Check for default install locations based on current system architecture
if not defined MSVC15 (
    reg.exe query "HKLM\SOFTWARE%WOWNODE%\Microsoft\VisualStudio\SxS\VS7" /v 15.0 >nul 2>&1
    if not ERRORLEVEL 1 (
        echo Visual Studio 2017 installation detected...
        for /f "skip=2 tokens=2,*" %%i in ('reg.exe query "HKLM\SOFTWARE%WOWNODE%\Microsoft\VisualStudio\SxS\VS7" /v 15.0') do (
            call "%~0" "15" "%%j"
            if not ERRORLEVEL 1 (
                set MSVC15=1
                set MSVCFOUND=1
            )
        )
    )
)
if not defined MSVC14 (
    reg.exe query "HKLM\Software%WOWNODE%\Microsoft\VisualStudio\14.0" /v "InstallDir" >nul 2>&1
    if not ERRORLEVEL 1 (
        echo Visual Studio 2015 installation detected...
        for /f "skip=2 tokens=2,*" %%i in ('reg.exe query "HKLM\Software%WOWNODE%\Microsoft\VisualStudio\14.0" /v "InstallDir"') do (
            call "%~0" "14" "%%j"
            if not ERRORLEVEL 1 (
                set MSVC14=1
                set MSVCFOUND=1
            )
        )
    )
)
if not defined MSVC12 (
    reg.exe query "HKLM\Software%WOWNODE%\Microsoft\VisualStudio\12.0" /v "InstallDir" >nul 2>&1
    if not ERRORLEVEL 1 (
        echo Visual Studio 2013 installation detected...
        for /f "skip=2 tokens=2,*" %%i in ('reg.exe query "HKLM\Software%WOWNODE%\Microsoft\VisualStudio\12.0" /v "InstallDir"') do (
            call "%~0" "12" "%%j"
            if not ERRORLEVEL 1 (
                set MSVC12=1
                set MSVCFOUND=1
            )
        )
    )
)
if not defined MSVCFOUND (
    echo Error: Could not find valid Visual Studio installation!
    goto Terminate
)
goto Exit

:MSVCCALL
if "%SYSARCH%"=="32" (
    set MSVCVARSDIR=
) else if "%SYSARCH%"=="64" (
    set MSVCVARSDIR=\amd64
) else (
    goto Terminate
)
REM Call the required vcvars file in order to setup up build locations
if "%MSVC_VER%"=="16" (
    set VCVARS=%VSINSTANCEDIR%\VC\Auxiliary\Build\vcvars%SYSARCH%.bat
) else if "%MSVC_VER%"=="15" (
    set VCVARS=%VSINSTANCEDIR%\VC\Auxiliary\Build\vcvars%SYSARCH%.bat
) else if "%MSVC_VER%"=="14" (
    set VCVARS=%VSINSTANCEDIR%\VC\bin%MSVCVARSDIR%\vcvars%SYSARCH%.bat
) else if "%MSVC_VER%"=="12" (
    set VCVARS=%VSINSTANCEDIR%\VC\bin%MSVCVARSDIR%\vcvars%SYSARCH%.bat
) else (
    echo Error: Invalid MSVC version!
    goto Terminate
)
if exist %VCVARS% (
    call %VCVARS% >nul 2>&1
) else (
    echo Error: Invalid VS install location detected!
    goto Terminate
)

:MSVCVarsDone
REM Get the location of the current msbuild
powershell.exe -Command ((Get-Command msbuild.exe)[0].Path ^| Split-Path -parent) > "%SCRIPTDIR%\msbuild.txt"
findstr /C:"Get-Command" "%SCRIPTDIR%\msbuild.txt" >nul 2>&1
if not ERRORLEVEL 1 (
    echo Error: Failed to get location of msbuild!
    del /F /Q "%SCRIPTDIR%\msbuild.txt" >nul 2>&1
    goto Terminate
)
set /p MSBUILDDIR=<"%SCRIPTDIR%\msbuild.txt"
del /F /Q "%SCRIPTDIR%\msbuild.txt" >nul 2>&1
if "%MSVC_VER%"=="16" (
    set VCTargetsPath="..\..\Microsoft\VC\v160\BuildCustomizations"
) else if "%MSVC_VER%"=="15" (
    set VCTargetsPath="..\..\..\Common7\IDE\VC\VCTargets\BuildCustomizations"
) else (
    if "%MSBUILDDIR%"=="%MSBUILDDIR:amd64=%" (
        set VCTargetsPath="..\..\Microsoft.Cpp\v4.0\V%MSVC_VER%0\BuildCustomizations"
    ) else (
        set VCTargetsPath="..\..\..\Microsoft.Cpp\v4.0\V%MSVC_VER%0\BuildCustomizations"
    )
)

REM Convert the relative targets path to an absolute one
set CURRDIR=%CD%
pushd %MSBUILDDIR%
pushd %VCTargetsPath%
set VCTargetsPath=%CD%
popd
popd
if not "%CURRDIR%"=="%CD%" (
    echo Error: Failed to resolve VCTargetsPath!
    goto Terminate
)

REM copy the BuildCustomizations to VCTargets folder
echo Installing build customisations...
del /F /Q "%VCTargetsPath%\yasm.*" >nul 2>&1
copy /B /Y /V "%SCRIPTDIR%\yasm.*" "%VCTargetsPath%\" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: Failed to copy build customisations!
    echo    Ensure that this script is run in a shell with the necessary write privileges
    goto Terminate
)

REM Check if a yasm binary was bundled
if exist "%SCRIPTDIR%\yasm\" (
    REM Use the bundled binaries
    copy /B /Y /V "%SCRIPTDIR%\yasm\yasm-%SYSARCH%.exe" "%SCRIPTDIR%\yasm-%SYSARCH%.exe" >nul 2>&1
    goto InstallYASM
) else if exist "%SCRIPTDIR%\yasm_%YASMVERSION%_win%SYSARCH%.exe" (
    echo Using existing YASM binary...
    goto InstallYASM
)

REM Download the latest yasm binary for windows goto Terminate
echo Downloading required YASM release binary...
set YASMDOWNLOAD=%YASMDL%/yasm-%YASMVERSION%-win%SYSARCH%.exe
powershell.exe -Command (New-Object Net.WebClient).DownloadFile('%YASMDOWNLOAD%', '%SCRIPTDIR%\yasm_%YASMVERSION%_win%SYSARCH%.exe') >nul 2>&1
if not exist "%SCRIPTDIR%\yasm_%YASMVERSION%_win%SYSARCH%.exe" (
    echo Error: Failed to download required YASM binary!
    echo    The following link could not be resolved "%YASMDOWNLOAD%"
    goto Terminate
)

:InstallYASM
REM copy yasm executable to VC installation folder
echo Installing required YASM release binary...
del /F /Q "%VCINSTALLDIR%\yasm.exe" >nul 2>&1
copy /B /Y /V "%SCRIPTDIR%\yasm*.exe" "%VCINSTALLDIR%\yasm.exe" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: Failed to install YASM binary!
    echo    Ensure that this script is run in a shell with the necessary write privileges
    del /F /Q "%SCRIPTDIR%\yasm*.exe"  >nul 2>&1
    goto Terminate
)
del /F /Q "%SCRIPTDIR%\yasm*.exe"  >nul 2>&1
echo Finished Successfully
goto Exit

:Terminate
SET ERROR=1

:Exit
cd %CALLDIR%
if "%CI%"=="" (
    if not defined ISINSTANCE (
        pause
    )
)
endlocal & exit /b %ERROR%
