default:
    @just --list --unsorted

config := absolute_path('config')
build := absolute_path('.build')
out := absolute_path('firmware')
draw := absolute_path('draw')

# parse combos.dtsi and adjust settings to not run out of slots
_parse_combos:
    #!/usr/bin/env bash
    set -euo pipefail
    cconf="{{ config / 'combos.dtsi' }}"
    if [[ -f $cconf ]]; then
        # set MAX_COMBOS_PER_KEY to the most frequent combos count
        count=$(
            tail -n +10 $cconf |
                grep -Eo '[LR][TMBH][0-9]' |
                sort | uniq -c | sort -nr |
                awk 'NR==1{print $1}'
        )
        sed -Ei "/CONFIG_ZMK_COMBO_MAX_COMBOS_PER_KEY/s/=.+/=$count/" "{{ config }}"/*.conf
        echo "Setting MAX_COMBOS_PER_KEY to $count"

        # set MAX_KEYS_PER_COMBO to the most frequent key count
        count=$(
            tail -n +10 $cconf |
                grep -o -n '[LR][TMBH][0-9]' |
                cut -d : -f 1 | uniq -c | sort -nr |
                awk 'NR==1{print $1}'
        )
        sed -Ei "/CONFIG_ZMK_COMBO_MAX_KEYS_PER_COMBO/s/=.+/=$count/" "{{ config }}"/*.conf
        echo "Setting MAX_KEYS_PER_COMBO to $count"
    fi

# parse build.yaml and filter targets by expression
_parse_targets $expr:
    #!/usr/bin/env bash
    attrs="[.board, .shield]"
    filter="(($attrs | map(. // [.]) | combinations), ((.include // {})[] | $attrs)) | join(\",\")"
    echo "$(yq -r "$filter" build.yaml | grep -v "^," | grep -i "${expr/#all/.*}")"

# build firmware for single board & shield combination
_build_single $board $shield *west_args:
    #!/usr/bin/env bash
    set -euo pipefail
    artifact="${shield:+${shield// /+}-}${board}"
    build_dir="{{ build / '$artifact' }}"

    echo "Building firmware for $artifact..."
    west build -s zmk/app -d "$build_dir" -b $board {{ west_args }} -- \
        -DZMK_CONFIG="{{ config }}" ${shield:+-DSHIELD="$shield"}

    if [[ -f "$build_dir/zephyr/zmk.uf2" ]]; then
        mkdir -p "{{ out }}" && cp "$build_dir/zephyr/zmk.uf2" "{{ out }}/$artifact.uf2"
    else
        mkdir -p "{{ out }}" && cp "$build_dir/zephyr/zmk.bin" "{{ out }}/$artifact.bin"
    fi

# build firmware for matching targets
build expr *west_args: _parse_combos
    #!/usr/bin/env bash
    set -euo pipefail
    targets=$(just _parse_targets {{ expr }})

    [[ -z $targets ]] && echo "No matching targets found. Aborting..." >&2 && exit 1
    echo "$targets" | while IFS=, read -r board shield; do
        just _build_single "$board" "$shield" {{ west_args }}
    done

build_glove80:
    just build glove80

# clear build cache and artifacts
clean:
    rm -rf {{ build }} {{ out }}

# clear all automatically generated files
clean-all: clean
    rm -rf .west zmk

# clear nix cache
clean-nix:
    nix-collect-garbage --delete-old

# parse & plot keymap
draw:
    #!/usr/bin/env bash
    set -euo pipefail
    keymap -c "{{ draw }}/config.yaml" parse -z "{{ config }}/glove80.keymap" >"{{ draw }}/glove80.yaml"
    keymap -c "{{ draw }}/config.yaml" draw "{{ draw }}/glove80.yaml" >"{{ draw }}/glove80.svg"

redraw:
    watchexec -i draw/glove80.svg -i draw/glove80.yaml just draw

flash: build_glove80 draw
    #!/usr/bin/env bash
    set -euo pipefail

    mkdir -p mnt/
    
    sudo echo "need root for next steps"
    echo "Put right half of glove80 in flash mode (boot while holding RGUI+I aka RF5+RT2)"
    
    until [ -e /dev/disk/by-label/GLV80RHBOOT ]; do
      sleep 1
      echo -n "."
    done
    
    echo -e "\nflashing..."
    
    sudo mount /dev/disk/by-label/GLV80RHBOOT mnt
    sudo cp firmware/glove80_rh.uf2 mnt/
    sudo umount mnt
    
    echo "Put left half of glove80 in flash mode (boot while holding LGUI+E aka LF5+LT2)"
    
    until [ -e /dev/disk/by-label/GLV80LHBOOT ]; do
      sleep 1
      echo -n "."
    done
    
    echo "\nflashing..."
    
    sudo mount /dev/disk/by-label/GLV80LHBOOT mnt
    sudo cp firmware/glove80_lh.uf2 mnt/
    sudo umount mnt

# initialize west
init:
    west init -l config
    west update
    west zephyr-export

# list build targets
list:
    @just _parse_targets all | sed 's/,$//' | sort | column

# update west
update:
    west update

# upgrade zephyr-sdk and python dependencies
upgrade-sdk:
    nix flake update --flake .
