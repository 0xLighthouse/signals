export enum ContractType {
  UniswapV4PoolManager = 'UniswapV4PoolManager',
  SignalsFactory = 'SignalsFactory',
  Signals = 'Signals',
}

export enum Network {
  ArbitrumSepolia = 421614,
}

export const ContractAddresses = {
  [Network.ArbitrumSepolia]: {
    [ContractType.UniswapV4PoolManager]: '0x0000000000000000000000000000000000000000',
    [ContractType.SignalsFactory]: '0x0000000000000000000000000000000000000000',
    [ContractType.Signals]: '0x0000000000000000000000000000000000000000',
  },
}
