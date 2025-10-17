#!/bin/bash

# revisar sitios web en linea usando Ping ver0.3 (con verificación de duplicados)

WEBSITES=("apunteimpensado.com" "sitio_test_ejemplo.com")

ping_website() {
    local website="$1"
    local datetime="$(date +"%Y-%m-%d %H:%M:%S")"

    if ping -q -c 1 -W 5 "$website" > /dev/null; then
        echo "$datetime $website se encuentra disponible"
    else
        echo "$datetime $website NO se encuentra disponible"
    fi
}

# Función para verificar si un sitio ya está en la lista (case-insensitive)
existe_sitio() {
    local sitio_a_buscar="${1,,}"  # Convertir a minúsculas directamente
    
    for sitio_en_lista in "${WEBSITES[@]}"; do
        if [[ "${sitio_en_lista,,}" == "$sitio_a_buscar" ]]; then
            return 0  # Verdadero: encontrado
        fi
    done
    return 1  # Falso: no encontrado
}

mostrar_ayuda() {
    cat << EOF
Uso: $0 [OPCIONES]

OPCIONES:
  -u, --url URL   Agregar una URL personalizada para verificar (evita duplicados)
  -h, --help      Mostrar esta ayuda

EJEMPLOS:
  $0                        # Verificar sitios por defecto
  $0 -u google.com          # Verificar google.com además de los sitios por defecto
  $0 -u site1.com -u site2.com  # Verificar múltiples sitios personalizados
  $0 --url ejemplo.com      # Verificar ejemplo.com además de los sitios por defecto

SITIOS POR DEFECTO:
  ${WEBSITES[*]}
EOF
}

# Procesar opciones de línea de comandos
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            if [[ -n "$2" ]]; then
                if existe_sitio "$2"; then
                    echo "Advertencia: '$2' ya está en la lista y se omitirá." >&2
                else
                    WEBSITES+=("$2")
                    echo "Agregado: $2" >&2
                fi
                shift 2
            else
                echo "Error: La opción -u requiere una URL" >&2
                exit 1
            fi
            ;;
        -h|--help)
            mostrar_ayuda
            exit 0
            ;;
        *)
            echo "Error: Opción '$1' no reconocida" >&2
            echo "Use '$0 -h' para ver la ayuda" >&2
            exit 1
            ;;
    esac
done

echo "Verificando ${#WEBSITES[@]} sitios únicos..."
for website in "${WEBSITES[@]}"; do
    ping_website "$website"
done
