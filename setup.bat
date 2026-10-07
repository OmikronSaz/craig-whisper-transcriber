@echo off
setlocal

chcp 65001 >nul
cd /d "%~dp0"

echo.
echo ============================================================
echo CONFIGURACION INICIAL
echo ============================================================
echo.
echo Este proceso preparara el entorno necesario para transcribir.
echo Solo necesitas ejecutarlo una vez.
echo.

REM ------------------------------------------------------------
REM Check Python launcher
REM ------------------------------------------------------------

where py >nul 2>&1

if errorlevel 1 (
    echo ERROR: No se encontro Python Launcher.
    echo.
    echo Instala Python 3.13 desde python.org
    echo y asegurate de instalar tambien Python Launcher.
    echo.
    pause
    exit /b 1
)


REM ------------------------------------------------------------
REM Check Python 3.13
REM ------------------------------------------------------------

py -3.13 --version >nul 2>&1

if errorlevel 1 (
    echo ERROR: No se encontro Python 3.13.
    echo.
    echo Este proyecto requiere Python 3.13.
    echo Instala Python 3.13 desde python.org y vuelve a ejecutar setup.bat.
    echo.
    echo Versiones de Python detectadas:
    py -0p
    echo.
    pause
    exit /b 1
)

echo Python detectado:
py -3.13 --version
echo.


REM ------------------------------------------------------------
REM Create virtual environment
REM ------------------------------------------------------------

set "VENV=%~dp0.venv"
set "PYTHON=%VENV%\Scripts\python.exe"

if not exist "%PYTHON%" (
    echo Creando entorno virtual...
    echo.

    py -3.13 -m venv "%VENV%"

    if errorlevel 1 (
        echo.
        echo ERROR: No se pudo crear el entorno virtual.
        echo.
        pause
        exit /b 1
    )
) else (
    echo El entorno virtual ya existe.
    echo.
)


REM ------------------------------------------------------------
REM Upgrade pip
REM ------------------------------------------------------------

echo Actualizando pip...
echo.

"%PYTHON%" -m pip install --upgrade pip

if errorlevel 1 (
    echo.
    echo ERROR: No se pudo actualizar pip.
    echo.
    pause
    exit /b 1
)


REM ------------------------------------------------------------
REM Install known-good package versions
REM ------------------------------------------------------------

echo.
echo Instalando Faster-Whisper...
echo.

"%PYTHON%" -m pip install ^
    "faster-whisper==1.2.1" ^
    "ctranslate2==4.8.2" ^
    "av==18.0.0"

if errorlevel 1 (
    echo.
    echo ERROR: No se pudieron instalar las dependencias.
    echo.
    pause
    exit /b 1
)


REM ------------------------------------------------------------
REM Verify installation
REM ------------------------------------------------------------

echo.
echo Verificando instalacion...
echo.

"%PYTHON%" -c "from importlib.metadata import version; import faster_whisper, ctranslate2, av; print('faster-whisper:', version('faster-whisper')); print('CTranslate2:', version('ctranslate2')); print('PyAV:', version('av'))"

if errorlevel 1 (
    echo.
    echo ERROR: La instalacion termino, pero la verificacion fallo.
    echo.
    pause
    exit /b 1
)


REM ------------------------------------------------------------
REM Complete
REM ------------------------------------------------------------

echo.
echo ============================================================
echo CONFIGURACION COMPLETADA
echo ============================================================
echo.
echo El entorno esta listo.
echo.
echo A partir de ahora usa:
echo.
echo     run_transcription.bat
echo.
echo para procesar tus sesiones.
echo.
pause

exit /b 0