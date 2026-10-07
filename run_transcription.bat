@echo off
setlocal

chcp 65001 >nul
cd /d "%~dp0"

set "PYTHON=%~dp0.venv\Scripts\python.exe"
set "SCRIPT=%~dp0scripts\transcribe_session.py"

REM ------------------------------------------------------------
REM NVIDIA CUDA runtime paths
REM ------------------------------------------------------------

set "CUBLAS_BIN=%~dp0.venv\Lib\site-packages\nvidia\cublas\bin"
set "CUDNN_BIN=%~dp0.venv\Lib\site-packages\nvidia\cudnn\bin"

set "PATH=%CUBLAS_BIN%;%CUDNN_BIN%;%PATH%"


echo.
echo ============================================================
echo TRANSCRIPCION DE SESION
echo ============================================================
echo.


REM ------------------------------------------------------------
REM Verify Python environment
REM ------------------------------------------------------------

if not exist "%PYTHON%" (
    echo ERROR: No se encontro el entorno de Python.
    echo.
    echo Ejecuta setup.bat primero.
    echo.
    pause
    exit /b 1
)


REM ------------------------------------------------------------
REM Verify transcription script
REM ------------------------------------------------------------

if not exist "%SCRIPT%" (
    echo ERROR: No se encontro el script de transcripcion.
    echo.
    echo Ruta esperada:
    echo %SCRIPT%
    echo.
    pause
    exit /b 1
)


REM ------------------------------------------------------------
REM Verify NVIDIA runtime files
REM ------------------------------------------------------------

if not exist "%CUBLAS_BIN%\cublas64_12.dll" (
    echo ERROR: No se encontro cublas64_12.dll.
    echo.
    echo Ejecuta setup.bat nuevamente.
    echo.
    pause
    exit /b 1
)

if not exist "%CUDNN_BIN%\cudnn64_9.dll" (
    echo ERROR: No se encontro cudnn64_9.dll.
    echo.
    echo Ejecuta setup.bat nuevamente.
    echo.
    pause
    exit /b 1
)


REM ------------------------------------------------------------
REM Run transcription
REM ------------------------------------------------------------

"%PYTHON%" "%SCRIPT%"

set "EXITCODE=%ERRORLEVEL%"

echo.

if not "%EXITCODE%"=="0" (
    echo ============================================================
    echo EL PROCESO FALLO
    echo ============================================================
    echo.
    echo Revisa el error mostrado arriba.
    echo Los archivos deben permanecer disponibles para intentarlo de nuevo.
) else (
    echo ============================================================
    echo PROCESO COMPLETADO
    echo ============================================================
    echo.
    echo La transcripcion final esta en la carpeta:
    echo output
    echo.
    echo Los archivos procesados fueron movidos a:
    echo archive
)

echo.
echo Puedes cerrar esta ventana.
pause

exit /b %EXITCODE%