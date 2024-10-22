const fs = require('node:fs')
const path = require('node:path')

const FILES = [
  path.resolve('../../apps/contracts/out/Signals.sol/Signals.json'),
  path.resolve('../../apps/contracts/out/Incentives.sol/Incentives.json'),
]

for (const file of FILES) {
  const data = JSON.parse(fs.readFileSync(file, 'utf8'))
  const name = path.basename(file).toLowerCase().replace('.json', '.abi.json')
  fs.writeFileSync(
    path.resolve('../../apps/interface/src/abis', name),
    JSON.stringify(data.abi, null, 2),
  )
}
