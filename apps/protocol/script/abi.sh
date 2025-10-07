for file in out/**/*.json; do

    # FIXME: TODO work out which files we want to include
    # FIXME: TODO work out which files we want to include
    # We only want Signals, SignalsFactory
    if [[ "$file" != *"Signals"* && "$file" != *"SignalsFactory"* ]]; then
        continue
    fi

    # Create a holder called abi
    mkdir -p abis/

    # Move it to a holder called abi
    jq '.abi' "$file" >"${file%.json}.abi.json"

    mv "${file%.json}.abi.json" abis/
done
