@echo off
setlocal

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd "%script_dir%\.." || echo "unable to cd to '%script_dir%\..'"&& exit /b 1
for /f %%i in ('cd') do SET "script_dir=%%i"
call  "%script_dir%\gonextver\echos_macros.bat"
setlocal enabledelayedexpansion
for %%i in ("%~dp0..") do SET "dirname=%%~ni"

for /f "delims=" %%i in ('type "%script_dir%\go.mod"') do (
    if "!module_name!" == "" (
        set "module_name=%%i"
        goto:fldone
    )
)
:fldone
set "module_name=%module_name:module =%"
if "%module_name%" == "" (
        %_fatal% "go.mod in '%script_dir%' does not include a module name" 66
)
%_info% "Project '%dirname%', module '%module_name%', script_dir='%script_dir%'"

if not exist "%script_dir%\senv.bat" ( copy "%script_dir%\gonextver\senv.bat.tpl" "%script_dir%\senv.bat" )
grep "brel=" "%script_dir%\senv.bat" 1>NUL 2>NUL
if errorlevel 1 (
    type "%script_dir%\gonextver\senv.bat.tpl" >> "%script_dir%\senv.bat"
)
if exist "%script_dir%\senv.bat" ( call "%script_dir%\senv.bat" )


rem https://medium.com/@joshroppo/setting-go-1-5-variables-at-compile-time-for-versioning-5b30a965d33e
for /f %%i in ('git describe --long --tags --dirty --always') do set gitver=%%i
for /f %%i in ('git describe --tags 2^>NUL') do set VERSION=%%i
for /f %%i in ('git ls-files -o --directory --exclude-standard^|sed q^|wc -l') do set gituntracked=%%i


rem echo VERSION='%VERSION%'
set "snap=FALSE"
set "askForNewSnapshot=FALSE"
if "%VERSION%" == "" ( set "VERSION=0.0.0" )
if not "%VERSION:-=%" == "%VERSION%" (
    set "snap=TRUE-SNAP"
    set "askForNewSnapshot=new commits"
)
if not "%gitver:-dirty=%" == "%gitver%" (
    set "snap=!snap!-dirty"
    if "%askForNewSnapshot%" == "FALSE" (
        set "askForNewSnapshot=dirty"
    ) else (
        set "askForNewSnapshot=%askForNewSnapshot%, dirty"
    )
) else (
    if not "%gituntracked%" == "0"  (
        set "snap=!snap!-dirty"
        if "%askForNewSnapshot%" == "FALSE" (
            set "askForNewSnapshot=new files, dirty"
        ) else (
            set "askForNewSnapshot=%askForNewSnapshot%, new files, dirty"
        )
    )
)
%_info% "snap1 detection '%snap%' (gitver='%gitver%', VERSION='%VERSION%' and gituntracked='%gituntracked%')"
if not "%snap%" == "FALSE" (
    if not "%snap:-SNAP=%" == "%snap%" (
        set "todelete=-%VERSION:*-=%"
        call set "VERSION=%%VERSION:!todelete!=%%"
    )
    %_info% "snap2 !VERSION! with todelete='!todelete!', askForNewSnapshot='%askForNewSnapshot%'"
) else (
    %_info% "release %VERSION%"
)


set "vdir=%script_dir%\gonextver\version"
if not exist "%script_dir%\version.txt" (
    if "%VERSION%" == "" (
        copy "%vdir%\version.txt.tpl" "%script_dir%\version.txt"
    ) else (
        echo %VERSION:v=%>"%script_dir%\version.txt"
    )
)
if "%1" == "rel" ( 
    sed -i "s/-SNAPSHOT//g" "%script_dir%\version.txt"
    shift
)
for /f %%i in ('type "%script_dir%\version.txt"') do set "appver=%%i"
%_info% "Application Version: '%appver%'"
if "%VERSION%" == "" ( set "VERSION=%appver%")
echo %appver:v=%>"%script_dir%\version.txt"

set "makeNewRelease=FALSE"
if not "v%appver%" == "%VERSION%" (
    if not "%appver:-SNAP=%" == "%appver%" (
        %_ok% "Building '%appver%' from last release Git tag '%VERSION%' (snapshot)"
    ) else (
        set "makeNewRelease=TRUE"
    )
)

%_info% "Git VERSION='%VERSION%', vappver='v%appver%', so makeNewRelease='%makeNewRelease%'"
cd

if "%makeNewRelease%" == "TRUE" (
    %_warning% "New release detected '%appver%', differs from last release Git tag '%VERSION%'"
    %_task% "Must commit and tag new v%appver%."
    git add .
    if errorlevel 1 ( %_fatal% "ERROR unable to add before tagging '%appver%'" 40)
    git commit -m "New release '%appver%'"
    if errorlevel 1 ( %_fatal% "ERROR unable to commit before tagging '%appver%'" 41)
    git tag -m "v%appver%" v%appver%
    if errorlevel 1 ( %_fatal% "ERROR unable to tag 'v%appver%'" 42)
    set VERSION="v%appver%"
    for /f %%i in ('git describe --long --tags --dirty --always') do set gitver=%%i
    set "snap=FALSE"
    set "todelete="
)

if "v%appver%" == "%VERSION%" (
    if not "%askForNewSnapshot%" == "FALSE" (
        %_warning% "New modifications detected since last release '%VERSION%' (%askForNewSnapshot%)"
        git diff --cached --quiet
        if errorlevel 1 (
            %_fatal% "Please commit or reset your indexed/staged changes first, to allow version.txt modification and individual commit" 111
        )
        %_task% "Specify the new SNAPSHOT version to do"
        FOR /F "tokens=1,2,3 delims=." %%i in ("%appver%") do (
            set maj=%%i
            set min=%%j
            set fix=%%k
        )
        echo "Major='!maj!', Minor='!min!', Fix='!fix!'"
        set nfix=!fix!
        set /A nfix+=1
        ECHO 1. Fix   update: !maj!.!min!.!nfix!-SNAPSHOT
        set nmin=!min!
        set /A nmin+=1
        ECHO 2. Minor update: !maj!.!nmin!.0-SNAPSHOT
        set nmaj=!maj!
        set /A nmaj+=1
        ECHO 3. Major update: !nmaj!.0.0-SNAPSHOT
        choice /C 123 /M "Select the new snapshot version you want to make next"
        set c=!errorlevel!
        echo "Choice '!c!'"

        if "!c!" == "1" ( set "appver=!maj!.!min!.!nfix!-SNAPSHOT" )
        if "!c!" == "2" ( set "appver=!maj!.!nmin!.0-SNAPSHOT" )
        if "!c!" == "3" ( set "appver=!nmaj!.0.0-SNAPSHOT" )
        echo !appver!>"version.txt"
        git add "version.txt"
        if errorlevel 1 ( %_fatal% "ERROR unable to add version.txt" 112 )
        git commit -m "Begin new '!appver!' from previous release '%VERSION%'"
        if errorlevel 1 ( %_fatal% "ERROR unable to commit version.txt" 112 )
    )
)

rem https://superuser.com/questions/1287756/how-can-i-get-the-date-in-a-locale-independent-format-in-a-batch-file
rem https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-date?view=powershell-7.1
rem C:\Windows\System32\WindowsPowershell\v1.0\powershell -Command "Get-Date -format 'yyyy-MM-dd_HH-mm-ss K'"
%+@% for /f %%a in ('powershell -Command "Get-Date -format yyyy-MM-dd_HH-mm-ss"') do set dtStamp=%%a
rem SET dtStamp
echo "dtStamp='%dtStamp%'"

set outputname=%dirname%.exe

if "%1" == "amd" (
    set GOARCH=amd64
    set GOOS=linux
    set "outputname=%dirname%_%appver%"
    %_info% "AMD build requested for %module_name%"
    set "fflag=-gcflags="all=-N -l""
)
%_info% "Add ldflags with build user/host informations, generate build-info.txt"
echo %appver% (%gitver%)>build-info.txt
echo %USERNAME%>>build-info.txt
echo %dtStamp%>>build-info.txt
for /f "tokens=* delims= " %%i in ('call gonextver\host.bat') do set host=%%i
echo %host%>>build-info.txt
set "host=%host: =/%"
set "host=%host:[=%"
set "host=%host:]=%"
set "ldflags=-X %module_name%/gonextver/version.GitTag=%gitver% -X %module_name%/gonextver/version.BuildUser=%USERNAME% -X %module_name%/gonextver/version.VersionApp=%appver%/%gitver% -X %module_name%/gonextver/version.BuildDate=%dtStamp% -X %module_name%/gonextver/version.BuildHost=%host%"

rem %_info% "Back to build.bat dirname='%dirname%' outputname='%outputname%' fflag='%fflag%' ldflags='%ldflags%'"
endlocal & set "dirname=%dirname%" & set "outputname=%outputname%" & set "fflag=%fflag%" & set "ldflags=%ldflags%"
%_info% "Back_ to build.bat dirname='%dirname%' outputname='%outputname%' fflag='%fflag%' ldflags='%ldflags%'"
@echo @echo off> "%script_dir%\vars.bat
echo set "dirname=%dirname%">> "%script_dir%\vars.bat
echo set "outputname=%outputname%" >> "%script_dir%\vars.bat
echo set "fflag=%fflag%" >> "%script_dir%\vars.bat
echo set "ldflags=%ldflags%" >> "%script_dir%\vars.bat
exit /b 0