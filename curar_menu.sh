#!/bin/bash

INPUT="${1:-cultura_crudo.m3u}"
OUTPUT="${2:-cultura_final.m3u}"

if [ ! -f "$INPUT" ]; then
    echo "Error: No existe el archivo $INPUT"
    exit 1
fi

if [ ! -f "$OUTPUT" ]; then
    echo "#EXTM3U" > "$OUTPUT"
fi

# Cargar canales en memoria
declare -a NOMBRES
declare -a EXTINFS
declare -a URLS
declare -a ESTADOS

total=0
while IFS= read -r extinf && IFS= read -r url; do
    [[ "$extinf" =~ ^#EXTINF ]] || continue
    nombre=$(echo "$extinf" | sed 's/.*,//')
    NOMBRES+=("$nombre")
    EXTINFS+=("$extinf")
    URLS+=("$url")
    ESTADOS+=("[  ]")
    ((total++))
done < "$INPUT"

detener_vlc() {
    if [ -n "$VLC_PID" ]; then
        kill -9 "$VLC_PID" 2>/dev/null
        wait "$VLC_PID" 2>/dev/null
        VLC_PID=""
    fi
}

trap 'detener_vlc; exit 0' INT TERM EXIT

mostrar_menu() {
    clear
    echo "=========================================================="
    echo " CANALES EN $INPUT (Total: $total)"
    echo " [OK]=Guardado  [ X]=Descartado  [  ]=Sin probar"
    echo "=========================================================="
    for i in "${!NOMBRES[@]}"; do
        num=$((i + 1))
        printf "%3d) %s %s\n" "$num" "${ESTADOS[$i]}" "${NOMBRES[$i]}"
    done
    echo "=========================================================="
    echo " Ingresa el NÚMERO del canal a probar (o '0'/'q' para salir):"
}

VLC_PID=""

while true; do
    mostrar_menu
    read -p ">> Opción: " opcion

    case "$opcion" in
        0|q|Q)
            echo "Finalizando sesión..."
            break
            ;;
        ''|*[!0-9]*)
            echo "Número no válido. Presiona Enter para continuar..."
            read
            continue
            ;;
    esac

    idx=$((opcion - 1))
    if [ "$idx" -lt 0 ] || [ "$idx" -ge "$total" ]; then
        echo "Número fuera de rango. Presiona Enter para continuar..."
        read
        continue
    fi

    canal_nombre="${NOMBRES[$idx]}"
    canal_extinf="${EXTINFS[$idx]}"
    canal_url="${URLS[$idx]}"

    detener_vlc
    vlc --no-video-title-show --loop --network-caching=2500 "$canal_url" >/dev/null 2>&1 &
    VLC_PID=$!

    while true; do
        echo ""
        echo ">> Reproduciendo: $canal_nombre"
        echo "[s] Guardar  |  [n] Descartar  |  [v] Volver al menú (sin cambios)"
        read -n 1 -p "Decisión: " dec < /dev/tty
        echo ""
        case "$dec" in
            s|S)
                echo "$canal_extinf" >> "$OUTPUT"
                echo "$canal_url" >> "$OUTPUT"
                ESTADOS[$idx]="[OK]"
                echo "[+] Guardado en $OUTPUT"
                sleep 0.8
                break
                ;;
            n|N)
                ESTADOS[$idx]="[ X]"
                echo "[-] Descartado"
                sleep 0.8
                break
                ;;
            v|V)
                echo "Volviendo al menú..."
                break
                ;;
            *)
                echo "Opción no válida. Usa s, n o v."
                ;;
        esac
    done

    detener_vlc
done

echo ""
echo "=== SESIÓN FINALIZADA ==="
echo "Canales guardados en: $OUTPUT"
