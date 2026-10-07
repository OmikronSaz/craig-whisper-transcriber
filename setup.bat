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
    echo Instala Python desde:
    echo https://www.python.org/downloads/windows/
    echo.
    echo Asegurate de instalar tambien Python Launcher.
    echo.
    pause
    exit /b 1
)

REM ------------------------------------------------------------
REM Select supported Python version
REM Prefer 3.14, fall back to 3.13
REM ------------------------------------------------------------

set "PY_VERSION="

py -3.14 --version >nul 2>&1
if not errorlevel 1 (
    set "PY_VERSION=3.14"
)

if not defined PY_VERSION (
    py -3.13 --version >nul 2>&1
    if not errorlevel 1 (
        set "PY_VERSION=3.13"
    )
)

if not defined PY_VERSION (
    echo ERROR: No se encontro una version compatible de Python.
    echo.
    echo Versiones compatibles actualmente:
    echo.
    echo     Python 3.14
    echo     Python 3.13
    echo.
    echo Instala una version compatible desde:
    echo https://www.python.org/downloads/windows/
    echo.
    echo Versiones de Python detectadas:
    py -0p
    echo.
    pause
    exit /b 1
)

echo Python seleccionado:
py -%PY_VERSION% --version
echo.

REM ------------------------------------------------------------
REM Create or validate virtual environment
REM ------------------------------------------------------------

set "VENV=%~dp0.venv"
set "PYTHON=%VENV%\Scripts\python.exe"

if not exist "%PYTHON%" (
    echo Creando entorno virtual con Python %PY_VERSION%...
    echo.

    py -%PY_VERSION% -m venv "%VENV%"

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

    for /f "tokens=2" %%V in ('"%PYTHON%" --version 2^>^&1') do set "VENV_VERSION=%%V"

    echo Python del entorno existente: %VENV_VERSION%
    echo.

    echo %VENV_VERSION% | findstr /b "3.14." >nul
    if not errorlevel 1 goto VENV_OK

    echo %VENV_VERSION% | findstr /b "3.13." >nul
    if not errorlevel 1 goto VENV_OK

    echo ERROR: El entorno virtual existente usa una version
    echo de Python que no esta soportada actualmente.
    echo.
    echo Version detectada:
    echo     %VENV_VERSION%
    echo.
    echo Versiones compatibles:
    echo     Python 3.14
    echo     Python 3.13
    echo.
    echo Elimina la carpeta .venv y vuelve a ejecutar setup.bat
    echo para crear un entorno nuevo.
    echo.
    pause
    exit /b 1
)

:VENV_OK

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
REM Check Faster-Whisper dependencies
REM ------------------------------------------------------------

echo.
echo Verificando dependencias de Whisper...
echo.

"%PYTHON%" -c "from importlib.metadata import version; import sys; sys.exit(0 if version('faster-whisper')=='1.2.1' and version('ctranslate2')=='4.8.2' and version('av')=='18.0.0' else 1)" >nul 2>&1

if errorlevel 1 (
    echo Instalando dependencias de Whisper...
    echo.

    "%PYTHON%" -m pip install ^
        "faster-whisper==1.2.1" ^
        "ctranslate2==4.8.2" ^
        "av==18.0.0"

    if errorlevel 1 (
        echo.
        echo ERROR: No se pudieron instalar las dependencias de Whisper.
        echo.
        pause
        exit /b 1
    )
) else (
    echo Dependencias de Whisper ya instaladas.
)

REM ------------------------------------------------------------
REM NVIDIA library paths
REM ------------------------------------------------------------

set "CUBLAS_BIN=%VENV%\Lib\site-packages\nvidia\cublas\bin"
set "CUDNN_BIN=%VENV%\Lib\site-packages\nvidia\cudnn\bin"

REM ------------------------------------------------------------
REM Install NVIDIA CUDA libraries only if needed
REM ------------------------------------------------------------

echo.
echo Verificando librerias NVIDIA...
echo.

if exist "%CUBLAS_BIN%\cublas64_12.dll" (
    if exist "%CUDNN_BIN%\cudnn64_9.dll" (
        echo cuBLAS y cuDNN ya estan instalados.
        goto NVIDIA_READY
    )
)

echo Instalando librerias NVIDIA para CUDA...
echo.
echo NOTA: Esta descarga puede ser grande y tardar varios minutos.
echo.

"%PYTHON%" -m pip install ^
    nvidia-cublas-cu12 ^
    nvidia-cudnn-cu12

if errorlevel 1 (
    echo.
    echo ERROR: No se pudieron instalar las librerias NVIDIA.
    echo.
    echo Comprueba tu conexion a Internet e intenta de nuevo.
    echo.
    pause
    exit /b 1
)

:NVIDIA_READY

set "PATH=%CUBLAS_BIN%;%CUDNN_BIN%;%PATH%"

REM ------------------------------------------------------------
REM Verify Python packages
REM ------------------------------------------------------------

echo.
echo Verificando instalacion...
echo.

"%PYTHON%" -c "from importlib.metadata import version; import faster_whisper, ctranslate2, av; print('Python:', __import__('sys').version.split()[0]); print('faster-whisper:', version('faster-whisper')); print('CTranslate2:', version('ctranslate2')); print('PyAV:', version('av')); print('cuBLAS:', version('nvidia-cublas-cu12')); print('cuDNN:', version('nvidia-cudnn-cu12'))"

if errorlevel 1 (
    echo.
    echo ERROR: La instalacion termino, pero la verificacion fallo.
    echo.
    pause
    exit /b 1
)

REM ------------------------------------------------------------
REM Verify NVIDIA runtime files
REM ------------------------------------------------------------

echo.
echo Verificando archivos de NVIDIA...
echo.

if not exist "%CUBLAS_BIN%\cublas64_12.dll" (
    echo ERROR: No se encontro cublas64_12.dll
    echo.
    echo Ruta esperada:
    echo %CUBLAS_BIN%
    echo.
    pause
    exit /b 1
)

if not exist "%CUDNN_BIN%\cudnn64_9.dll" (
    echo ERROR: No se encontro cudnn64_9.dll
    echo.
    echo Ruta esperada:
    echo %CUDNN_BIN%
    echo.
    pause
    exit /b 1
)

echo cuBLAS encontrado.
echo cuDNN encontrado.

REM ------------------------------------------------------------
REM Verify NVIDIA GPU and actual DLL loading
REM ------------------------------------------------------------

echo.
echo Verificando GPU NVIDIA y CUDA...
echo.

"%PYTHON%" -c "import os, ctypes, ctranslate2, sys; cb=os.environ['CUBLAS_BIN']; cd=os.environ['CUDNN_BIN']; h1=os.add_dll_directory(cb); h2=os.add_dll_directory(cd); ctypes.WinDLL(os.path.join(cb,'cublas64_12.dll')); ctypes.WinDLL(os.path.join(cd,'cudnn64_9.dll')); n=ctranslate2.get_cuda_device_count(); print('GPU CUDA detectadas:', n); types=ctranslate2.get_supported_compute_types('cuda') if n else set(); print('Modos compatibles:', ', '.join(sorted(types)) if types else 'ninguno'); sys.exit(0 if n > 0 and 'float16' in types else 1)"

if errorlevel 1 (
    echo.
    echo ============================================================
    echo ERROR: CUDA NO ESTA LISTO PARA WHISPER
    echo ============================================================
    echo.
    echo La GPU NVIDIA puede estar presente, pero las librerias
    echo necesarias para ejecutar Whisper no pudieron cargarse.
    echo.
    echo Comprueba que tus drivers NVIDIA esten actualizados.
    echo.
    echo Si no tienes una GPU NVIDIA compatible, utiliza la version
    echo de Kaggle del tutorial.
    echo.
    pause
    exit /b 1
)

echo.
echo GPU NVIDIA, CUDA, cuBLAS y cuDNN detectados correctamente.

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
echo Version de Python utilizada:
"%PYTHON%" --version
echo.
echo A partir de ahora usa:
echo.
echo     run_transcription.bat
echo.
echo para procesar tus sesiones.
echo.
pause

exit /b 0