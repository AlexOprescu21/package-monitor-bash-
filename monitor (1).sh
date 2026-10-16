#!/bin/bash


root_dir="$HOME/Desktop/Proiect_ITBI/package_monitor_data"
log_sursa="/var/log/dpkg.log" 
conf_limit="$root_dir/config/undo_limit.conf"
total_size_db="$root_dir/state/total_size.txt"
undo_cache="$root_dir/cache/undo_list.txt"
zile=${1:-1}
data_start=$(date -d "$zile days ago" +"%Y-%m-%d %H:%M:%S")



mkdir -p "$root_dir/state" "$root_dir/cache" "$root_dir/config" "$root_dir/packages"
[ ! -f "$total_size_db" ] && echo "0" > "$total_size_db"
[ ! -f "$undo_cache" ] && touch "$undo_cache"
[ ! -f "$conf_limit" ] && echo "5" > "$conf_limit"

max_undo=$(cat "$conf_limit")

echo "Pornire de la: $data_start "

awk -v start="$data_start" '$1 " " $2 >= start' "$log_sursa" | while read -r zi ora actiune rest; do
    

    if [[ "$actiune" == "status" ]]; then
        stare=$(echo "$rest" | awk '{print $1}')
        pachet=$(echo "$rest" | awk '{print $2}')
        ver=$(echo "$rest" | awk '{print $3}')
    else
        stare="$actiune" 
        pachet=$(echo "$rest" | awk '{print $1}')
        ver=$(echo "$rest" | awk '{print $2}')
    fi

    [[ -z "$pachet" || "$actiune" == "startup" || "$actiune" == "trigproc" ]] && continue

    pkg_path="$root_dir/packages/$pachet"
    history_file="$pkg_path/history.log"
    size_file="$pkg_path/size.txt"

    if [ ! -d "$pkg_path" ]; then
        mkdir -p "$pkg_path"
        echo "Pachet detectat prima data la: $zi $ora" > "$history_file"
    fi
    echo "$zi $ora $actiune $stare $ver" >> "$history_file"

    if [[ "$stare" == "half-installed" ]]; then
        echo "Stare partiala detectata la $zi $ora" >> "$history_file"
    fi

    if [[ "$stare" == "installed" ]]; then
        pkg_size=$(dpkg-query -W -f='${Installed-Size}' "$pachet" 2>/dev/null || echo "0")
        echo "$pkg_size" > "$size_file"

        vechiul_total=$(cat "$total_size_db")
        echo $((vechiul_total + pkg_size)) > "$total_size_db"
    fi

    if [[ "$actiune" == "remove" || "$actiune" == "purge" ]]; then
        marime_pachet=$(cat "$size_file" 2>/dev/null || echo "0")
        total_acum=$(cat "$total_size_db")
        nou_total=$((total_acum - marime_pachet))
        [ $nou_total -lt 0 ] && nou_total=0
        echo "$nou_total" > "$total_size_db"

        grep -v "^$pachet$" "$undo_cache" > "$undo_cache.tmp" 2>/dev/null
        echo "$pachet" | cat - "$undo_cache.tmp" > "$undo_cache"
        head -n "$max_undo" "$undo_cache" > "$undo_cache.tmp"
        mv "$undo_cache.tmp" "$undo_cache"
    fi

done

echo "Gata!"