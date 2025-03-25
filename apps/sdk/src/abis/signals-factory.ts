import type { Abi } from 'viem'

export const signalsFactoryAbi = [
  {
    type: 'function',
    name: 'VERSION',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'string',
        internalType: 'string',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'create',
    inputs: [
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct ISignalsFactory.FactoryDeployment',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'underlyingToken',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'proposalThreshold',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'acceptanceThreshold',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxLockIntervals',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'proposalCap',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'lockInterval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'decayCurveType',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'decayCurveParameters',
            type: 'uint256[]',
            internalType: 'uint256[]',
          },
        ],
      },
    ],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'version',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'string',
        internalType: 'string',
      },
    ],
    stateMutability: 'pure',
  },
  {
    type: 'event',
    name: 'BoardCreated',
    inputs: [
      {
        name: 'board',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'owner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'error',
    name: 'FactoryDeploymentFailed',
    inputs: [],
  },
  {
    type: 'error',
    name: 'InvalidOwnerAddress',
    inputs: [],
  },
] as const satisfies Abi
