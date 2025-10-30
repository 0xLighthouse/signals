## Contracts and owners

- ExperimentTokenFactory
Deployer will become owner of factory. Specify the allowance signer as the constructor argument.
All token contracts deployed by the factory will be owned by the deployer, and recognize the specidfied allowance signer (our server).

- ExperimentToken
Deployed via the factory, currently only owner of factory can deploy a new token contract.

- CreateFactory
Anyone can deploy this contract. Once deployed, anyone can use it to create their own board.

- CreateBoard
Anyone can deploy a board via CreateFactory. Whoever does the deployment will be the owner of the board.

## Private Keys

Populate private keys via your .envrc file, or use these defaults.

Roles used by `dev.sh`:

### Deployer
Will own the `ExperimentTokenFactory`, `ExperimentToken`, and any Signals boards created. 

### Signer
Will be registered as the `allowanceSigner` for the token contract. Load the private key into our api to issue allowances.

### Alice, Bob, Charlie
Issued tokens for testing.

## Default keys

When using Anvil, we use the Anvil default keys:

Deployer
Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Private key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

Signer
Address: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
Private key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

Alice
Address: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
Private key: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

Bob
Address: 0x90F79bf6EB2c4f870365E785982E1f101E93b906
Private key: 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6

Charlie
Address: 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
Private key: 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a







