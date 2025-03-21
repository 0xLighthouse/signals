for file in out/**/*.json; do

  # We only want Bond, BondPricing, BondIssuer, PoolManager, etc
  if [[ "$file" != *"Bond"* ]] && [[ "$file" != *"PoolManager"* ]]; then
    continue
  fi

  # Create a holder called abi
  mkdir -p abis/

  # Move it to a holder called abi
  jq '.abi' "$file" >"${file%.json}.abi.json"

  mv "${file%.json}.abi.json" abis/
done

echo "Wrote BondHook abis to abis/"
