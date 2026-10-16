#!/bin/bash

root_dir="$HOME/Desktop/Proiect_ITBI/package_monitor_data"
pkg_dir="$root_dir/packages"
file_total="$root_dir/state/total_size.txt"
lista_undo="$root_dir/cache/undo_list.txt"

afiseaza_ajutor() {
    echo "Monitorizare Pachete - Meniu"
    echo "Optiuni disponibile:"
    echo "  --installed          Pachete instalate acum"
    echo "  --removed            Pachete sterse"
    echo "  --history <nume>     Tot istoricul unui pachet"
    echo "  --period <S> <E>     Modificari intre doua date"
    echo "  --size <nume>        Cat ocupa un pachet"
    echo "  --total-size         Spatiu total ocupat in sistem"
    echo "  --undo-cache         Cache-ul LRU pentru stergere"
    echo "  --check-partial      Pachete instalate partial"
    exit 1
}

[[ $# -eq 0 ]] && afiseaza_ajutor

case "$1" in
    --installed)
        echo -e "Pachet\tData Instalare"
        echo ""
        for p in "$pkg_dir"/*; do
            [ ! -d "$p" ] && continue
            nume=$(basename "$p")
            ultima_linie=$(tail -n 1 "$p/history.log" 2>/dev/null)
            if [[ "$ultima_linie" == *"installed"* || "$ultima_linie" == *"upgrade"* ]]; then
                data_ora=$(echo "$ultima_linie" | awk '{print $1 " " $2}')
                echo -e "$nume\t$data_ora"
            fi
        done | column -t
        ;;

    --removed)
        echo -e "Pachet\tData Stergere"
        echo ""
        for p in "$pkg_dir"/*; do
            [ ! -d "$p" ] && continue
            nume=$(basename "$p")
            ist_file="$p/history.log"
            
            linie_stergere=$(grep -E "remove|purge" "$ist_file" | tail -n 1)
            
            if [ ! -z "$linie_stergere" ]; then
                data_stergere=$(echo "$linie_stergere" | awk '{print $1 " " $2}')
                
                ultima_stare=$(tail -n 1 "$ist_file")
                
                if [[ "$ultima_stare" != *"installed"* && "$ultima_stare" != *"upgrade"* ]]; then
                    echo -e "$nume\t$data_stergere"
                fi
            fi
        done | column -t
        ;;

    --history)
        if [ -z "$2" ]; then
             echo "Eroare"; exit 1
        fi
        f_ist="$pkg_dir/$2/history.log"
        if [ -f "$f_ist" ]; then
            echo "Istoric $2 "
            cat "$f_ist"
        else
            echo "Nu am gasit date pentru pachetul '$2'."
        fi
        ;;

    --period)
        if [[ -z "$2" || -z "$3" ]]; then
            echo "Format incorect"; exit 1
        fi
        echo "Modificari gasite intre $2 si $3:"
        find "$pkg_dir" -name "history.log" | xargs awk -v s="$2" -v e="$3" '
            $1 >= s && $1 <= e {
                split(FILENAME, p, "/");
                nume_pkg = p[length(p)-1];
                print $1 " " $2 " | " nume_pkg " | " $3 " " $4
            }' | sort
        ;;

    --size)
        [ -z "$2" ] && { echo "Specifica pachetul."; exit 1; }
        f_size="$pkg_dir/$2/size.txt"
        if [ -f "$f_size" ]; then
            valoare=$(cat "$f_size")
            echo "Pachetul $2 ocupa: $valoare KB"
        else
            echo "Nu avem date despre $2."
        fi
        ;;

    --total-size)
        total_kb=$(cat "$file_total" 2>/dev/null || echo "0")
        total_mb=$((total_kb / 1024))
        echo "Spatiu total utilizat: $total_kb KB"
        ;;

    --undo-cache)
        echo "Cache Pachete Sterse (LRU)"
        if [ -s "$lista_undo" ]; then
            cat -n "$lista_undo"
            echo "Poti sa le reinstalezi cu: sudo apt install [nume]"
        else
            echo "Cache-ul este gol."
        fi
        ;;

    --check-partial)
        echo "Verificam"
        eroare_gasita=0
        for p in "$pkg_dir"/*; do
            [ ! -d "$p" ] && continue
            if grep -q "half-installed" "$p/history.log" 2>/dev/null; then
                if ! tail -n 1 "$p/history.log" | grep -q "installed"; then
                    echo "Pachetul $(basename "$p") este intr-o stare incerta"
                    eroare_gasita=1
                fi
            fi
        done
        [ $eroare_gasita -eq 0 ] && echo "Nu s-au gasit probleme."
        ;;

    *)
        afiseaza_ajutor
        ;;
esac