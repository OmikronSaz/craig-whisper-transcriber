@echo off
setlocal

chcp 65001 >nul
cd /d "%~dp0"

set "PYTHON=%~dp0.venv\Scripts\python.exe"
set "SCRIPT=%~dp0scripts\transcribe_session.py"

echo.
echo ============================================================
echo TRANSCRIPCION DE SESION
echo ============================================================
echo.

if not exist "%PYTHON%" (
    echo ERROR: No se encontro el entorno de Python.
    echo.
    echo Ruta esperada:
    echo %PYTHON%
    echo.
    pause
    exit /b 1
)

if not exist "%SCRIPT%" (
    echo ERROR: No se encontro el script de transcripcion.
    echo.
    echo Ruta esperada:
    echo %SCRIPT%
    echo.
    pause
    exit /b 1
)

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