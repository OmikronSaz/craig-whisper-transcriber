import re
import av
from datetime import datetime
from pathlib import Path
import shutil

from faster_whisper import WhisperModel


# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

MODEL_SIZE = "large-v3"
GAP_THRESHOLD = 2.0

PROJECT_DIR = Path(__file__).resolve().parent.parent
INPUT_DIR = PROJECT_DIR / "input"
OUTPUT_DIR = PROJECT_DIR / "output"
ARCHIVE_DIR = PROJECT_DIR / "archive"

INFO_FILE = INPUT_DIR / "info.txt"
PLAYER_NAMES_FILE = INPUT_DIR / "player_names.txt"


# ------------------------------------------------------------
# player_names.txt
# ------------------------------------------------------------

def load_player_names(path):
    mappings = {}

    if not path.exists():
        print("Aviso: No se encontró player_names.txt.")
        print("Se usarán los nombres de usuario de Discord.")
        print()
        return mappings

    for line_number, raw_line in enumerate(
        path.read_text(encoding="utf-8").splitlines(),
        start=1
    ):
        line = raw_line.strip()

        if not line or line.startswith("#"):
            continue

        if ":" not in line:
            print(
                f"Aviso: Se ignorará la línea inválida "
                f"{line_number} de player_names.txt: {raw_line}"
            )
            continue

        username, display_name = line.split(":", 1)

        username = username.strip()
        display_name = display_name.strip()

        if not username:
            continue

        if not display_name:
            print(
                f"Aviso: No hay un nombre asignado para {username}. "
                f"Se usará el nombre de usuario de Discord."
            )
            continue

        mappings[username.casefold()] = display_name

    return mappings


# ------------------------------------------------------------
# Craig info.txt
# ------------------------------------------------------------

TRACK_RE = re.compile(
    r"^\s*(.*?)\s+\(([^()]+)#\d+\)\s+\((\d+)\)\s*$"
)


def parse_info_file(path):
    result = {
        "start_time": None,
        "usernames": [],
        "campaign": None
    }

    if not path.exists():
        return result

    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    in_tracks = False

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("Start time:"):
            result["start_time"] = (
                stripped.split(":", 1)[1].strip()
            )

        elif stripped == "Tracks:":
            in_tracks = True
            continue

        elif stripped == "Notes:":
            in_tracks = False
            continue

        elif in_tracks and stripped:
            match = TRACK_RE.match(line)

            if match:
                username = match.group(2).strip()
                result["usernames"].append(username)

    expanded_text = text.replace("\\n", "\n")

    campaign_match = re.search(
        r"Campaign:\s*(.+)",
        expanded_text
    )

    if campaign_match:
        result["campaign"] = (
            campaign_match.group(1).strip()
        )

    return result


# ------------------------------------------------------------
# FLAC discovery
# ------------------------------------------------------------

CRAIG_FLAC_RE = re.compile(
    r"^(\d+)_(.+)_0$",
    re.IGNORECASE
)


def get_track_number(path):
    first_part = path.stem.split("_", 1)[0]

    if first_part.isdigit():
        return first_part

    return None


def find_username_from_info(path, usernames):
    """
    Match the FLAC filename against usernames found in Craig's info.txt.

    This also lets temporary test files work without hardcoding
    anything about their names.
    """

    stem = path.stem

    parts = stem.split("_", 1)

    if len(parts) == 2 and parts[0].isdigit():
        filename_body = parts[1]
    else:
        filename_body = stem

    body_folded = filename_body.casefold()

    # Longest first in case one username begins with another.
    for username in sorted(
        usernames,
        key=len,
        reverse=True
    ):
        username_folded = username.casefold()

        if body_folded == username_folded:
            return username

        if body_folded.startswith(
            username_folded + "_"
        ):
            return username

    return None


def find_flac_files(info):
    all_flacs = sorted(INPUT_DIR.glob("*.flac"))

    selected = []
    ignored = []

    info_usernames = info["usernames"]

    for path in all_flacs:
        track_number = get_track_number(path)

        username = None

        # Best source: Craig info.txt
        if info_usernames:
            username = find_username_from_info(
                path,
                info_usernames
            )

            if not username:
                ignored.append(path)
                continue

        # Fallback if info.txt is absent or contains no usable tracks.
        else:
            match = CRAIG_FLAC_RE.match(path.stem)

            if match:
                track_number = match.group(1)
                username = match.group(2)
            else:
                ignored.append(path)
                continue

        selected.append({
            "path": path,
            "track_number": track_number,
            "username": username
        })

    return selected, ignored


# ------------------------------------------------------------
# Speaker names
# ------------------------------------------------------------

def get_speaker_name(track, player_names, fallback_number):
    username = track["username"]

    if username:
        mapped_name = player_names.get(
            username.casefold()
        )

        if mapped_name:
            return mapped_name

        return username

    track_number = track["track_number"]

    if not track_number:
        track_number = f"{fallback_number:02d}"

    return f"Jugador {track_number}"


# ------------------------------------------------------------
# Whisper word-gap splitting
# ------------------------------------------------------------

def split_words_into_chunks(segments):
    all_words = []

    for segment in segments:
        if segment.words:
            all_words.extend(segment.words)

    if not all_words:
        return []

    chunks = []
    current_words = [all_words[0]]

    for word in all_words[1:]:
        previous_word = current_words[-1]

        gap = word.start - previous_word.end

        if gap >= GAP_THRESHOLD:
            chunks.append(current_words)
            current_words = [word]
        else:
            current_words.append(word)

    if current_words:
        chunks.append(current_words)

    results = []

    for words in chunks:
        text = "".join(
            word.word for word in words
        ).strip()

        if not text:
            continue

        results.append({
            "start": words[0].start,
            "end": words[-1].end,
            "text": text
        })

    return results


# ------------------------------------------------------------
# Time formatting
# ------------------------------------------------------------

def format_time(seconds):
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = seconds % 60

    return f"{hours:02d}:{minutes:02d}:{secs:05.2f}"


# ------------------------------------------------------------
# Output filename
# ------------------------------------------------------------

def get_session_datetime(info):
    start_time = info["start_time"]

    if start_time:
        try:
            utc_time = datetime.fromisoformat(
                start_time.replace("Z", "+00:00")
            )

            return utc_time.astimezone()

        except Exception as error:
            print(
                "Aviso: No se pudo leer la fecha de la sesión "
                f"desde info.txt: {error}"
            )

    print(
        "Aviso: No se encontró la fecha de la sesión. "
        "Se usará la fecha y hora actual."
    )

    return datetime.now().astimezone()


def get_session_paths(session_datetime):
    OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True
    )

    ARCHIVE_DIR.mkdir(
        parents=True,
        exist_ok=True
    )

    base_name = session_datetime.strftime(
        "%Y-%m-%d_%H%M%S"
    )

    session_name = base_name
    counter = 2

    while (
        (
            OUTPUT_DIR
            / f"combined_transcript_{session_name}.txt"
        ).exists()
        or
        (
            ARCHIVE_DIR
            / session_name
        ).exists()
    ):
        session_name = (
            f"{base_name}_{counter}"
        )
        counter += 1

    output_file = (
        OUTPUT_DIR
        / f"combined_transcript_{session_name}.txt"
    )

    archive_dir = (
        ARCHIVE_DIR
        / session_name
    )

    return output_file, archive_dir


def archive_input_files(archive_dir):
    archive_dir.mkdir(
        parents=True,
        exist_ok=False
    )

    moved_files = []

    for path in sorted(INPUT_DIR.iterdir()):

        if not path.is_file():
            continue

        # This is the only persistent input file.
        if path.name.casefold() == "player_names.txt":
            continue

        destination = archive_dir / path.name

        shutil.move(
            str(path),
            str(destination)
        )

        moved_files.append(path.name)

    return moved_files


# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

info = parse_info_file(INFO_FILE)

player_names = load_player_names(
    PLAYER_NAMES_FILE
)

tracks, ignored_flacs = find_flac_files(info)

if not tracks:
    print(
        "No se encontraron archivos FLAC "
        "de participantes de Craig en:"
    )
    print(INPUT_DIR)
    raise SystemExit(1)


print()
print(
    f"Se encontraron {len(tracks)} archivo(s) FLAC "
    f"de participantes:"
)
print()


for track_number, track in enumerate(
    tracks,
    start=1
):
    speaker = get_speaker_name(
        track,
        player_names,
        track_number
    )

    print(
        f"  {track['path'].name} -> {speaker}"
    )


if ignored_flacs:
    print()
    print("Archivos FLAC ignorados:")

    for path in ignored_flacs:
        print(f"  {path.name}")


print()
print("Cargando modelo Whisper...")


model = WhisperModel(
    MODEL_SIZE,
    device="cuda",
    compute_type="float16"
)


print("Modelo cargado.")
print()


merged_entries = []


for track_index, track in enumerate(
    tracks,
    start=1
):
    path = track["path"]

    speaker = get_speaker_name(
        track,
        player_names,
        track_index
    )

    print(
        f"[{track_index}/{len(tracks)}] "
        f"Transcribiendo {path.name}"
    )

    segments, info_result = model.transcribe(
        str(path),
        beam_size=5,
        language="es",
        vad_filter=True,
        condition_on_previous_text=False,
        word_timestamps=True
    )

    chunks = split_words_into_chunks(segments)

    transcript_lines = []

    for chunk in chunks:
        transcript_line = (
            f"[{chunk['start']:.2f}s -> "
            f"{chunk['end']:.2f}s] "
            f"{chunk['text']}"
        )

        transcript_lines.append(
            transcript_line
        )

        merged_entries.append({
            "start": chunk["start"],
            "end": chunk["end"],
            "speaker": speaker,
            "text": chunk["text"]
        })

    # Save individual UTF-8 transcript beside the FLAC.
    transcript_file = path.with_suffix(".txt")

    transcript_file.write_text(
        "\n".join(transcript_lines) + "\n",
        encoding="utf-8"
    )

    print(
        f"    {len(chunks)} segmento(s)"
    )

    print(
        f"    Guardado: {transcript_file.name}"
    )

    print()


if not merged_entries:
    print(
        "No se detectó voz en ninguno de los archivos."
    )
    raise SystemExit(1)


# ------------------------------------------------------------
# Audio duration
# ------------------------------------------------------------

def get_audio_duration_seconds(path):
    try:
        with av.open(str(path)) as container:

            if container.duration is not None:
                return float(
                    container.duration / av.time_base
                )

            for stream in container.streams.audio:

                if (
                    stream.duration is not None
                    and stream.time_base is not None
                ):
                    return float(
                        stream.duration
                        * stream.time_base
                    )

    except Exception as error:
        print(
            f"Aviso: No se pudo determinar la duración "
            f"de {path.name}: {error}"
        )

    return None


def format_duration(seconds):
    total_seconds = int(round(seconds))

    hours = total_seconds // 3600
    minutes = (
        total_seconds % 3600
    ) // 60
    secs = total_seconds % 60

    return (
        f"{hours:02d}:"
        f"{minutes:02d}:"
        f"{secs:02d}"
    )


# ------------------------------------------------------------
# Merge speakers chronologically
# ------------------------------------------------------------

merged_entries.sort(
    key=lambda entry: entry["start"]
)

combined_lines = []

for entry in merged_entries:
    line = (
        f"[{format_time(entry['start'])} -> "
        f"{format_time(entry['end'])}] "
        f"{entry['speaker']}: "
        f"{entry['text']}"
    )

    combined_lines.append(line)


session_datetime = get_session_datetime(info)

output_file, archive_dir = get_session_paths(
    session_datetime
)


# ------------------------------------------------------------
# Session header
# ------------------------------------------------------------

durations = []

for track in tracks:
    duration = get_audio_duration_seconds(
        track["path"]
    )

    if duration is not None:
        durations.append(duration)


session_duration = (
    max(durations)
    if durations
    else None
)


header_lines = [
    "=" * 60,
    "INFORMACIÓN DE LA SESIÓN",
    "=" * 60,
    (
        "Fecha: "
        + session_datetime.strftime(
            "%Y-%m-%d %H:%M:%S"
        )
    )
]


if info["campaign"]:
    header_lines.append(
        f"Campaña: {info['campaign']}"
    )


if session_duration is not None:
    header_lines.append(
        "Duración: "
        + format_duration(
            session_duration
        )
    )


header_lines.append(
    f"Participantes: {len(tracks)}"
)

header_lines.append("")
header_lines.append("Personajes:")


for track_index, track in enumerate(
    tracks,
    start=1
):
    speaker = get_speaker_name(
        track,
        player_names,
        track_index
    )

    username = track["username"]

    if not username:
        track_number = (
            track["track_number"]
            or f"{track_index:02d}"
        )

        username = (
            f"Jugador {track_number}"
        )

    header_lines.append(
        f"  {username}: {speaker}"
    )


header_lines.extend([
    "",
    "=" * 60,
    "TRANSCRIPCIÓN",
    "=" * 60,
    ""
])


final_lines = (
    header_lines
    + combined_lines
)


output_file.write_text(
    "\n".join(final_lines) + "\n",
    encoding="utf-8"
)


# Do not archive anything unless the final transcript
# was successfully created.

if not output_file.exists():
    raise RuntimeError(
        "No se pudo crear la transcripción final."
    )


if output_file.stat().st_size == 0:
    raise RuntimeError(
        "La transcripción final está vacía."
    )


moved_files = archive_input_files(
    archive_dir
)


print("=" * 60)
print("COMPLETADO")
print("=" * 60)

print(
    f"Pistas transcritas: {len(tracks)}"
)

print(
    f"Segmentos combinados: {len(merged_entries)}"
)

print(
    f"Archivos archivados: {len(moved_files)}"
)

print(
    f"Carpeta de archivo: {archive_dir}"
)

print(
    f"Transcripción final: {output_file}"
)