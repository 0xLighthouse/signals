export const signalsFactoryAbi = [
  {
    type: 'function',
    name: 'create',
    inputs: [
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct ISignals.SignalsConfig',
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
    type: 'event',
    name: 'SignalsCreated',
    inputs: [
      {
        name: 'newSignals',
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
] as const
