#!/bin/bash

INPUT="directv_crudo.m3u"
OUTPUT="directv_final.m3u"

# Inicializar archivo de salida si no existe
if [ ! -f "$OUTPUT" ]; then
    echo "#EXTM3U" > "$OUTPUT"
fi

echo "=== CURADURÍA DIRECTV SPORTS (REPRODUCCIÓN CONTINUA) ==="
echo "Controles: [s] Guardar | [n] Descartar | [q] Salir"
echo "--------------------------------------------------------"

guardados=0
descartados=0

while IFS= read -r extinf <&3 && IFS= read -r url <&3; do
    [[ "$extinf" =~ ^#EXTINF ]] || continue

    nombre=$(echo "$extinf" | sed 's/.*,//')
    echo ""
    echo ">> Canal: $nombre"
    echo ">> URL: $url"

    # Abrir VLC en bucle continuo y con buffer de red para que no se cierre solo
    vlc --no-video-title-show --loop --network-caching=2500 "$url" >/dev/null 2>&1 &
    VLC_PID=$!

    while true; do
        read -n 1 -p "¿Guardar canal? [s/n/q]: " opcion < /dev/tty
        echo ""
        case "$opcion" in
            s|S|y|Y)
                echo "$extinf" >> "$OUTPUT"
                echo "$url" >> "$OUTPUT"
                ((guardados++))
                echo "[+] Guardado en $OUTPUT"
                break
                ;;
            n|N)
                ((descartados++))
                echo "[-] Descartado"
                break
                ;;
            q|Q)
                kill -9 $VLC_PID 2>/dev/null
                echo ""
                echo "=== SESIÓN PAUSADA ==="
                echo "Guardados: $guardados | Descartados: $descartados"
                exit 0
                ;;
            *)
                echo "Opción no válida. Presiona 's', 'n' o 'q'."
                ;;
        esac
    done

    # Detener VLC únicamente tras la confirmación
    kill -9 $VLC_PID 2>/dev/null
    wait $VLC_PID 2>/dev/null

done 3< "$INPUT"

echo ""
echo "=== CURADURÍA COMPLETADA ==="
echo "Total guardados: $guardados"
echo "Total descartados: $descartados"
echo "Archivo final: $OUTPUT"
