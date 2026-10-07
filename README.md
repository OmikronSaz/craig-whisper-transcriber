# Transcripción local de sesiones de Craig con Faster-Whisper

Herramienta para transcribir automáticamente grabaciones multitrack de Craig para Discord.

El proceso identifica las pistas de cada participante, transcribe el audio localmente con Faster-Whisper, asigna nombres o personajes, combina todas las intervenciones cronológicamente y genera una sola transcripción final.

## Qué hace

Al ejecutar el programa:

1. Busca los archivos `.flac` de Craig dentro de `input`.
2. Lee `info.txt` cuando está disponible.
3. Identifica las pistas correspondientes a participantes de Discord.
4. Evita transcribir pistas adicionales que no correspondan a participantes cuando pueden identificarse mediante `info.txt`.
5. Transcribe cada participante con Faster-Whisper.
6. Usa `player_names.txt` para reemplazar nombres de Discord por nombres de personajes.
7. Combina todas las intervenciones cronológicamente.
8. Añade información de la sesión al inicio de la transcripción.
9. Guarda la transcripción final dentro de `output`.
10. Mueve los archivos procesados a una carpeta única dentro de `archive`.
11. Deja `player_names.txt` dentro de `input` para la siguiente sesión.

## Privacidad

Las grabaciones se transcriben localmente en tu computador.

Los archivos de audio no se envían a un servicio externo de transcripción.

La primera vez que se utilice el modelo de Whisper puede ser necesario descargar el modelo desde Internet.

## Requisitos

Configuración recomendada:

- Windows 11
- Python 3.13
- GPU NVIDIA compatible con CUDA
- Espacio disponible para el modelo, los archivos de audio y las transcripciones

El proyecto utiliza versiones específicas de sus dependencias para mantener un entorno reproducible.

## Instalación

### 1. Instalar Python 3.13

Descarga Python 3.13 desde:

https://www.python.org/

Durante la instalación asegúrate de instalar también Python Launcher.

Puedes comprobar la instalación abriendo una terminal y ejecutando:

py -3.13 --version

### 2. Descargar este proyecto

Descarga el ZIP desde la sección Releases de este repositorio y extráelo en una carpeta de tu computador.

No es necesario instalar el proyecto dentro de una ruta específica.

### 3. Ejecutar la configuración inicial

Haz doble clic en:

setup.bat

Este proceso:

- verifica que Python 3.13 esté disponible;
- crea un entorno virtual local llamado `.venv`;
- instala Faster-Whisper;
- instala las versiones necesarias de CTranslate2 y PyAV;
- verifica que las dependencias puedan importarse correctamente.

Normalmente solo necesitas ejecutar `setup.bat` una vez.

## Configurar nombres de personajes

Dentro de:

input\player_names.txt

puedes indicar qué nombre quieres mostrar en la transcripción.

Formato:

usuario_de_discord: Nombre del personaje

Ejemplo:

usuario121: Nombre del personaje
usuario122: Segundo personaje

Puedes agregar tantos jugadores como necesites.

No importa si `player_names.txt` contiene jugadores que no participaron en una sesión determinada. Las entradas que no correspondan a los archivos procesados simplemente se ignoran.

Si un usuario no aparece en `player_names.txt`, se utilizará automáticamente su nombre de Discord.

Si tampoco es posible determinar el nombre de Discord, se utilizará un identificador único como:

Jugador 03

## Procesar una sesión

### 1. Descargar la grabación de Craig

Descarga la versión multitrack de la sesión desde Craig.

### 2. Extraer los archivos

Extrae el contenido del ZIP de Craig directamente dentro de:

input

Normalmente encontrarás archivos similares a:

01_usuario1_0.flac
02_usuario2_0.flac
03_usuario3_0.flac
info.txt

No es necesario renombrar los archivos.

Tampoco es necesario eliminar manualmente pistas adicionales.

Cuando `info.txt` está disponible, el programa lo utiliza para identificar qué pistas corresponden a participantes de Discord.

### 3. Ejecutar la transcripción

Haz doble clic en:

run_transcription.bat

El programa mostrará el progreso mientras procesa las pistas.

La duración del proceso depende principalmente de:

- la duración de la sesión;
- la cantidad de participantes;
- la velocidad de la GPU.

No cierres la ventana mientras el proceso esté trabajando.

## Resultado

Al terminar correctamente, encontrarás la transcripción combinada dentro de:

output

El nombre incluye la fecha y hora de la sesión para evitar sobrescribir transcripciones anteriores.

Ejemplo:

combined_transcript_2026-10-04_200020.txt

La transcripción comienza con información básica de la sesión:

============================================================
INFORMACIÓN DE LA SESIÓN
============================================================
Fecha: 2026-10-04 20:00:20
Campaña: Ejemplo de campaña
Duración: 03:16:43
Participantes: 8

Personajes:
  usuario1: Personaje Uno
  usuario2: Personaje Dos

============================================================
TRANSCRIPCIÓN
============================================================

Después aparecen las intervenciones combinadas cronológicamente:

[00:00:14.70 -> 00:00:32.38] Personaje Uno: ...
[00:00:32.40 -> 00:00:33.86] Personaje Dos: ...

Las conversaciones simultáneas se conservan según sus timestamps originales.

## Cómo se determinan los nombres

El programa utiliza este orden:

1. Nombre configurado en `player_names.txt`.
2. Nombre de usuario de Discord.
3. Identificador basado en el número de pista, por ejemplo `Jugador 03`.

Esto permite que la transcripción continúe incluso si `player_names.txt` está incompleto o ausente.

## Archivo automático

Después de una ejecución exitosa, los archivos utilizados se mueven automáticamente a una carpeta única dentro de:

archive

Ejemplo:

archive\
    2026-10-04_200020\
        01_usuario1_0.flac
        01_usuario1_0.txt
        02_usuario2_0.flac
        02_usuario2_0.txt
        info.txt

Las transcripciones individuales generadas durante el proceso también se conservan dentro del archivo de la sesión.

`player_names.txt` no se mueve.

Después de una ejecución exitosa, `input` queda listo para recibir la siguiente sesión.

## Si algo falla

Los archivos originales solo se archivan después de crear correctamente la transcripción final.

Si ocurre un error antes de completar el proceso, los archivos permanecen disponibles dentro de `input` para poder intentarlo nuevamente.

La ventana de `run_transcription.bat` permanece abierta para mostrar el mensaje de error.

## Estructura del proyecto

Whisper\
│
├── input\
│   └── player_names.txt
│
├── output\
│
├── archive\
│
├── scripts\
│   └── transcribe_session.py
│
├── setup.bat
└── run_transcription.bat

El entorno `.venv` se crea localmente al ejecutar `setup.bat`.

No forma parte del paquete distribuido.

## Seguridad y confianza

No necesitas confiar ciegamente en un archivo ejecutable desconocido.

Los principales archivos de este proyecto son archivos de texto que pueden inspeccionarse antes de ejecutarlos:

setup.bat
run_transcription.bat
scripts\transcribe_session.py

En Windows puedes hacer clic derecho sobre un archivo `.bat` y seleccionar Editar para revisar sus comandos.

El código fuente publicado en el repositorio permite revisar exactamente qué hace el programa antes de utilizarlo.

El proyecto no necesita enviar las grabaciones a un servicio externo para realizar la transcripción.

## Dependencias

El entorno de Python utiliza versiones específicas para mantener resultados reproducibles:

Python:          3.13.x
faster-whisper:  1.2.1
CTranslate2:     4.8.2
PyAV:            18.0.0
Modelo Whisper:  large-v3

PyAV 18.0.0 se fija intencionalmente debido a una incompatibilidad entre PyAV 19 y la versión de Faster-Whisper utilizada por este proyecto.

## Archivos principales

### setup.bat

Prepara el entorno local.

Crea `.venv`, instala las dependencias necesarias y verifica la instalación.

### run_transcription.bat

Inicia el procesamiento de una sesión.

No necesitas abrir una terminal ni activar manualmente el entorno virtual.

### scripts\transcribe_session.py

Contiene la lógica principal:

- identificación de pistas;
- lectura de `info.txt`;
- lectura de `player_names.txt`;
- transcripción;
- separación de segmentos;
- combinación cronológica;
- generación del encabezado;
- creación de la transcripción final;
- archivo de los archivos procesados.

### input\player_names.txt

Archivo opcional y persistente para relacionar usuarios de Discord con nombres de personajes.

## Flujo resumido

Descargar ZIP multitrack de Craig

→ Extraer los archivos dentro de `input`

→ Opcionalmente actualizar `player_names.txt`

→ Ejecutar `run_transcription.bat`

→ Esperar a que termine la transcripción

→ Abrir la transcripción combinada dentro de `output`

→ Los archivos de la sesión quedan organizados automáticamente dentro de `archive`
## Librerías NVIDIA CUDA

El flujo local con GPU NVIDIA utiliza Faster-Whisper mediante CTranslate2.

Durante una prueba externa en un portátil limpio, la GPU fue detectada correctamente, pero la transcripción falló porque las librerías necesarias de CUDA no estaban disponibles:

`cublas64_12.dll`

A partir de la versión 1.0.1, `setup.bat` instala automáticamente dentro del entorno virtual del proyecto las librerías NVIDIA necesarias:

- `nvidia-cublas-cu12`
- `nvidia-cudnn-cu12`

`run_transcription.bat` también añade temporalmente las carpetas de estas DLL al `PATH` durante cada ejecución.

No es necesario instalar manualmente el CUDA Toolkit completo para este flujo.

Si `setup.bat` termina correctamente, verifica:

- detección de GPU CUDA;
- soporte para `float16`;
- cuBLAS;
- cuDNN;
- carga de las DLL necesarias de NVIDIA.

Si estas verificaciones fallan, comprueba que los drivers de NVIDIA estén actualizados. Si no tienes una GPU NVIDIA compatible, utiliza el flujo de Kaggle del tutorial.

