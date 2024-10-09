#!/bin/bash

for file in out/**/*.json; do

    if [[ ! "$file" == *"Signals"* ]]; then
        continue
    fi

    # Only create ABI files matching the pattern Signals*
    abi_file="${file%.json}.abi.json"
    jq '.abi' "$file" >"$abi_file"
    echo "ABI saved to $abi_file"
done
