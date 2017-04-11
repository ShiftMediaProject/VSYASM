@ECHO OFF

REM Defined cript variables
set YASMDL=http://www.tortall.net/projects/yasm/releases
set YASMVERSION=1.3.0

REM Store current directory and ensure working directory is the location of current .bat
set CALLDIR=%CD%
set SCRIPTDIR=%~dp0

REM Initialise error check value
SET ERROR=0

REM Check what architecture we are installing on
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo Detected 64 bit system...
    set SYSARCH=x64
) else if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    if "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
        echo Detected 64 bit system running 32 bit shell...
        set SYSARCH=x64
    ) else (
        echo Detected 32 bit system...
        set SYSARCH=x32
    )
) else (
    echo Error: Could not detect current platform architecture!"
    goto Terminate
)

REM Check if already running in an environment with VS setup
if defined VCINSTALLDIR (
    if defined VisualStudioVersion (
        echo Existing Visual Studio environment detected...
        if "%VisualStudioVersion%"=="15.0" (
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

REM First check for a environment variable to help locate the VS installation
if defined VS140COMNTOOLS (
    if exist "%VS140COMNTOOLS%\..\..\VC\vcvarsall.bat" (
        echo Visual Studio 2015 environment detected...
        call "%VS140COMNTOOLS%\..\..\VC\vcvarsall.bat" 1>NUL 2>NUL
        set MSVC_VER=14
        goto MSVCVarsDone
    )
)
if defined VS120COMNTOOLS (
    if exist "%VS120COMNTOOLS%\..\..\VC\vcvarsall.bat" (
        echo Visual Studio 2013 environment detected...
        call "%VS120COMNTOOLS%\..\..\VC\vcvarsall.bat" 1>NUL 2>NUL
        set MSVC_VER=12
        goto MSVCVarsDone
    )
)

REM Check for default install locations based on current system architecture
if "%SYSARCH%"=="x32" (
    goto MSVCVARSX86
) else if "%SYSARCH%"=="x64" (
    goto MSVCVARSX64
) else (
    goto Terminate
)

:MSVCVARSX86
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars32.bat" (
    echo Visual Studio 2017 installation detected...
    call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars32.bat" 1>NUL 2>NUL
    set MSVC_VER=15
    goto MSVCVarsDone
) else if exist "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\bin\vcvars32.bat" (
    echo Visual Studio 2015 installation detected...
    call "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\bin\vcvars32.bat" 1>NUL 2>NUL
    set MSVC_VER=14
    goto MSVCVarsDone
) else if exist "C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\bin\vcvars32.bat" (
    echo Visual Studio 2013 installation detected...
    call "C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\bin\vcvars32.bat" 1>NUL 2>NUL
    set MSVC_VER=12
    goto MSVCVarsDone
) else (
    echo Error: Could not find valid 64 bit x86 Visual Studio installation!
    goto Terminate
)

:MSVCVARSX64
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars64.bat" (
    echo Visual Studio 2017 installation detected...
    call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars64.bat" 1>NUL 2>NUL
    set MSVC_VER=15
    goto MSVCVarsDone
) else if exist C:\"Program Files (x86)\Microsoft Visual Studio 14.0"\VC\bin\amd64\vcvars64.bat (
    echo Visual Studio 2015 installation detected...
    call C:\"Program Files (x86)\Microsoft Visual Studio 14.0"\VC\bin\amd64\vcvars64.bat 1>NUL 2>NUL
    set MSVC_VER=14
    goto MSVCVarsDone
) else if exist C:\"Program Files (x86)\Microsoft Visual Studio 12.0"\VC\bin\amd64\vcvars64.bat (
    echo Visual Studio 2013 installation detected...
    call C:\"Program Files (x86)\Microsoft Visual Studio 12.0"\VC\bin\amd64\vcvars64.bat 1>NUL 2>NUL
    set MSVC_VER=12
    goto MSVCVarsDone
) else (
    echo Error: Could not find valid 64 bit x86 Visual Studio installation!
    goto Terminate
)

:MSVCVarsDone
REM Get the location of the current msbuild
powershell.exe -Command ((Get-Command msbuild.exe).Path ^| Split-Path -parent) > msbuild.txt
set /p MSBUILDDIR=<msbuild.txt
del /F /Q msbuild.txt 1>NUL 2>NUL
if "%MSBUILDDIR%"=="" (
    echo Error: Failed to get location of msbuild!
    goto Terminate
)
if "%MSVC_VER%"=="15" (
    set VCTargetsPath="..\..\..\Common7\IDE\VC\VCTargets"
) else (
    set VCTargetsPath="..\..\..\Microsoft.Cpp\v4.0\V%MSVC_VER%0"
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
del /F /Q "%VCTargetsPath%\BuildCustomizations\yasm.*" 1>NUL 2>NUL
copy /B /Y /V "%SCRIPTDIR%\yasm.*" "%VCTargetsPath%\BuildCustomizations\" 1>NUL 2>NUL
if not exist "%VCTargetsPath%\BuildCustomizations\yasm.props" (
    echo Error: Failed to copy build customisations!
    echo    Ensure that this script is run in a shell with the necessary write privileges
    goto Terminate
)

REM Check if a yasm binary was bundled
if not exist "%SCRIPTDIR%\yasm\" (
    REM Download the latest yasm binary for windows goto Terminate
    call :DownloadYasm
) else (
    REM Use the bundled binaries
    if "%SYSARCH%"=="x32" (
        copy /B /Y /V "%SCRIPTDIR%\yasm\yasm-32.exe" "%SCRIPTDIR%\yasm.exe" 1>NUL 2>NUL
    ) else if "%SYSARCH%"=="x64" (
        copy /B /Y /V "%SCRIPTDIR%\yasm\yasm-64.exe" "%SCRIPTDIR%\yasm.exe" 1>NUL 2>NUL
    ) else (
        goto Terminate
    )
)

REM copy yasm executable to VC installation folder
echo Installing required YASM release binary...
del /F /Q "%VCINSTALLDIR%\yasm.exe" 1>NUL 2>NUL
move /Y "%SCRIPTDIR%\yasm.exe" "%VCINSTALLDIR%\" 1>NUL 2>NUL
if not exist "%VCINSTALLDIR%\yasm.exe" (
    echo Error: Failed to install YASM binary!
    echo    Ensure that this script is run in a shell with the necessary write privileges
    del /F /Q "%SCRIPTDIR%\yasm.exe" 1>NUL 2>NUL
    goto Terminate
)
echo Finished Successfully
goto Exit

:Terminate
SET ERROR=1

:Exit
cd %CALLDIR%
IF "%APPVEYOR%"=="" (
    pause
)
exit /b %ERROR%

:DownloadYasm
if "%SYSARCH%"=="x32" (
    set YASMDOWNLOAD=%YASMDL%/yasm-%YASMVERSION%-win32.exe
) else if "%SYSARCH%"=="x64" (
    set YASMDOWNLOAD=%YASMDL%/yasm-%YASMVERSION%-win64.exe
) else (
    goto Terminate
)
echo Downloading required YASM release binary...
powershell.exe -Command (New-Object Net.WebClient).DownloadFile('%YASMDOWNLOAD%', '%SCRIPTDIR%\yasm.exe') 1>NUL 2>NUL
if not exist "%SCRIPTDIR%\yasm.exe" (
    echo Error: Failed to download required YASM binary!
    echo    The following link could not be resolved "%YASMDOWNLOAD%"
    goto Terminate
)
goto :eof