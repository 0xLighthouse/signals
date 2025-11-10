//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Signals
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const signalsAbi = [
  { type: 'constructor', inputs: [], stateMutability: 'nonpayable' },
  {
    type: 'function',
    inputs: [
      { name: 'initiativeId', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'acceptInitiative',
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'lockAmount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'accountCanPropose',
    outputs: [{ name: 'result', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'lockAmount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'accountCanSupport',
    outputs: [{ name: 'result', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'approve',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'authorizationToken',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'boardCancelled',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'boardClosedAt',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'boardOpenAt',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'cancelBoard',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'closeBoard',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    name: 'decayCurveParameters',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'decayCurveType',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'initiativeId', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'expireInitiative',
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getAcceptanceCriteria',
    outputs: [
      {
        name: '',
        internalType: 'struct ISignals.AcceptanceCriteria',
        type: 'tuple',
        components: [
          { name: 'anyoneCanAccept', internalType: 'bool', type: 'bool' },
          {
            name: 'ownerMustFollowThreshold',
            internalType: 'bool',
            type: 'bool',
          },
          {
            name: 'percentageThresholdWAD',
            internalType: 'uint256',
            type: 'uint256',
          },
          { name: 'fixedThreshold', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getAcceptanceThreshold',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'getApproved',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'initiativeId', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'getInitiative',
    outputs: [
      {
        name: '',
        internalType: 'struct ISignals.Initiative',
        type: 'tuple',
        components: [
          {
            name: 'state',
            internalType: 'enum ISignals.InitiativeState',
            type: 'uint8',
          },
          { name: 'proposer', internalType: 'address', type: 'address' },
          { name: 'timestamp', internalType: 'uint256', type: 'uint256' },
          { name: 'lastActivity', internalType: 'uint256', type: 'uint256' },
          {
            name: 'acceptanceTimestamp',
            internalType: 'uint256',
            type: 'uint256',
          },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'getLockData',
    outputs: [
      {
        name: '',
        internalType: 'struct ISignalsLock.LockData',
        type: 'tuple',
        components: [
          { name: 'referenceId', internalType: 'uint256', type: 'uint256' },
          { name: 'nominalValue', internalType: 'uint256', type: 'uint256' },
          { name: 'expires', internalType: 'uint256', type: 'uint256' },
          { name: 'created', internalType: 'uint256', type: 'uint256' },
          { name: 'claimed', internalType: 'bool', type: 'bool' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getParticipantRequirements',
    outputs: [
      {
        name: '',
        internalType: 'struct IAuthorizer.ParticipantRequirements',
        type: 'tuple',
        components: [
          {
            name: 'eligibilityType',
            internalType: 'enum IAuthorizer.EligibilityType',
            type: 'uint8',
          },
          { name: 'minBalance', internalType: 'uint256', type: 'uint256' },
          {
            name: 'minHoldingDuration',
            internalType: 'uint256',
            type: 'uint256',
          },
          { name: 'minLockAmount', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getProposerRequirements',
    outputs: [
      {
        name: '',
        internalType: 'struct IAuthorizer.ParticipantRequirements',
        type: 'tuple',
        components: [
          {
            name: 'eligibilityType',
            internalType: 'enum IAuthorizer.EligibilityType',
            type: 'uint8',
          },
          { name: 'minBalance', internalType: 'uint256', type: 'uint256' },
          {
            name: 'minHoldingDuration',
            internalType: 'uint256',
            type: 'uint256',
          },
          { name: 'minLockAmount', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'getTokenLock',
    outputs: [
      {
        name: '',
        internalType: 'struct ISignals.TokenLock',
        type: 'tuple',
        components: [
          { name: 'initiativeId', internalType: 'uint256', type: 'uint256' },
          { name: 'supporter', internalType: 'address', type: 'address' },
          { name: 'tokenAmount', internalType: 'uint256', type: 'uint256' },
          { name: 'lockDuration', internalType: 'uint256', type: 'uint256' },
          { name: 'created', internalType: 'uint256', type: 'uint256' },
          { name: 'withdrawn', internalType: 'bool', type: 'bool' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'initiativeId', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'getWeight',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'initiativeId', internalType: 'uint256', type: 'uint256' },
      { name: 'timestamp', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'getWeightAt',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'initiativeId', internalType: 'uint256', type: 'uint256' },
      { name: 'supporter', internalType: 'address', type: 'address' },
      { name: 'timestamp', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'getWeightForSupporterAt',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'inactivityTimeout',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'incentivesPool',
    outputs: [
      { name: '', internalType: 'contract IIncentivesPool', type: 'address' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'config',
        internalType: 'struct ISignals.BoardConfig',
        type: 'tuple',
        components: [
          { name: 'version', internalType: 'string', type: 'string' },
          {
            name: 'boardMetadata',
            internalType: 'struct ISignals.Metadata',
            type: 'tuple',
            components: [
              { name: 'title', internalType: 'string', type: 'string' },
              { name: 'body', internalType: 'string', type: 'string' },
              {
                name: 'attachments',
                internalType: 'struct ISignals.Attachment[]',
                type: 'tuple[]',
                components: [
                  { name: 'uri', internalType: 'string', type: 'string' },
                  { name: 'mimeType', internalType: 'string', type: 'string' },
                  {
                    name: 'description',
                    internalType: 'string',
                    type: 'string',
                  },
                ],
              },
            ],
          },
          { name: 'owner', internalType: 'address', type: 'address' },
          { name: 'underlyingToken', internalType: 'address', type: 'address' },
          {
            name: 'acceptanceCriteria',
            internalType: 'struct ISignals.AcceptanceCriteria',
            type: 'tuple',
            components: [
              { name: 'anyoneCanAccept', internalType: 'bool', type: 'bool' },
              {
                name: 'ownerMustFollowThreshold',
                internalType: 'bool',
                type: 'bool',
              },
              {
                name: 'percentageThresholdWAD',
                internalType: 'uint256',
                type: 'uint256',
              },
              {
                name: 'fixedThreshold',
                internalType: 'uint256',
                type: 'uint256',
              },
            ],
          },
          {
            name: 'maxLockIntervals',
            internalType: 'uint256',
            type: 'uint256',
          },
          { name: 'lockInterval', internalType: 'uint256', type: 'uint256' },
          { name: 'decayCurveType', internalType: 'uint256', type: 'uint256' },
          {
            name: 'decayCurveParameters',
            internalType: 'uint256[]',
            type: 'uint256[]',
          },
          {
            name: 'inactivityTimeout',
            internalType: 'uint256',
            type: 'uint256',
          },
          {
            name: 'proposerRequirements',
            internalType: 'struct IAuthorizer.ParticipantRequirements',
            type: 'tuple',
            components: [
              {
                name: 'eligibilityType',
                internalType: 'enum IAuthorizer.EligibilityType',
                type: 'uint8',
              },
              { name: 'minBalance', internalType: 'uint256', type: 'uint256' },
              {
                name: 'minHoldingDuration',
                internalType: 'uint256',
                type: 'uint256',
              },
              {
                name: 'minLockAmount',
                internalType: 'uint256',
                type: 'uint256',
              },
            ],
          },
          {
            name: 'supporterRequirements',
            internalType: 'struct IAuthorizer.ParticipantRequirements',
            type: 'tuple',
            components: [
              {
                name: 'eligibilityType',
                internalType: 'enum IAuthorizer.EligibilityType',
                type: 'uint8',
              },
              { name: 'minBalance', internalType: 'uint256', type: 'uint256' },
              {
                name: 'minHoldingDuration',
                internalType: 'uint256',
                type: 'uint256',
              },
              {
                name: 'minLockAmount',
                internalType: 'uint256',
                type: 'uint256',
              },
            ],
          },
          {
            name: 'releaseLockDuration',
            internalType: 'uint256',
            type: 'uint256',
          },
          { name: 'boardOpenAt', internalType: 'uint256', type: 'uint256' },
          { name: 'boardClosedAt', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    name: 'initialize',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'initiativeCount',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'operator', internalType: 'address', type: 'address' },
    ],
    name: 'isApprovedForAll',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'isBoardClosed',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'isBoardOpen',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'lockCount',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'lockInterval',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'initiativeId', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'locksForInitiative',
    outputs: [{ name: '', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'maxLockIntervals',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'name',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'owner',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'ownerOf',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_metadata',
        internalType: 'struct ISignals.Metadata',
        type: 'tuple',
        components: [
          { name: 'title', internalType: 'string', type: 'string' },
          { name: 'body', internalType: 'string', type: 'string' },
          {
            name: 'attachments',
            internalType: 'struct ISignals.Attachment[]',
            type: 'tuple[]',
            components: [
              { name: 'uri', internalType: 'string', type: 'string' },
              { name: 'mimeType', internalType: 'string', type: 'string' },
              { name: 'description', internalType: 'string', type: 'string' },
            ],
          },
        ],
      },
    ],
    name: 'proposeInitiative',
    outputs: [
      { name: 'initiativeId', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_metadata',
        internalType: 'struct ISignals.Metadata',
        type: 'tuple',
        components: [
          { name: 'title', internalType: 'string', type: 'string' },
          { name: 'body', internalType: 'string', type: 'string' },
          {
            name: 'attachments',
            internalType: 'struct ISignals.Attachment[]',
            type: 'tuple[]',
            components: [
              { name: 'uri', internalType: 'string', type: 'string' },
              { name: 'mimeType', internalType: 'string', type: 'string' },
              { name: 'description', internalType: 'string', type: 'string' },
            ],
          },
        ],
      },
      { name: '_amount', internalType: 'uint256', type: 'uint256' },
      { name: '_lockDuration', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'proposeInitiativeWithLock',
    outputs: [
      { name: 'initiativeId', internalType: 'uint256', type: 'uint256' },
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'proposerRequirements',
    outputs: [
      {
        name: 'eligibilityType',
        internalType: 'enum IAuthorizer.EligibilityType',
        type: 'uint8',
      },
      { name: 'minBalance', internalType: 'uint256', type: 'uint256' },
      { name: 'minHoldingDuration', internalType: 'uint256', type: 'uint256' },
      { name: 'minLockAmount', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'lockId', internalType: 'uint256', type: 'uint256' }],
    name: 'redeemLock',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'initiativeId', internalType: 'uint256', type: 'uint256' },
      { name: 'lockIds', internalType: 'uint256[]', type: 'uint256[]' },
    ],
    name: 'redeemLocksForInitiative',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'releaseLockDuration',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'renounceOwnership',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'safeTransferFrom',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
      { name: 'data', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'safeTransferFrom',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'acceptanceCriteria',
        internalType: 'struct ISignals.AcceptanceCriteria',
        type: 'tuple',
        components: [
          { name: 'anyoneCanAccept', internalType: 'bool', type: 'bool' },
          {
            name: 'ownerMustFollowThreshold',
            internalType: 'bool',
            type: 'bool',
          },
          {
            name: 'percentageThresholdWAD',
            internalType: 'uint256',
            type: 'uint256',
          },
          { name: 'fixedThreshold', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    name: 'setAcceptanceCriteria',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'operator', internalType: 'address', type: 'address' },
      { name: 'approved', internalType: 'bool', type: 'bool' },
    ],
    name: 'setApprovalForAll',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_boardClosedAt', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'setBoardClosedAt',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_boardOpenAt', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'setBoardOpenAt',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_decayCurveType', internalType: 'uint256', type: 'uint256' },
      {
        name: '_decayCurveParameters',
        internalType: 'uint256[]',
        type: 'uint256[]',
      },
    ],
    name: 'setDecayCurve',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'incentivesPool_', internalType: 'address', type: 'address' },
      {
        name: 'incentivesConfig_',
        internalType: 'struct IIncentivizer.IncentivesConfig',
        type: 'tuple',
        components: [
          {
            name: 'incentiveType',
            internalType: 'enum IIncentivizer.IncentiveType',
            type: 'uint8',
          },
          {
            name: 'incentiveParametersWAD',
            internalType: 'uint256[]',
            type: 'uint256[]',
          },
        ],
      },
    ],
    name: 'setIncentivesPool',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'initiativeId', internalType: 'uint256', type: 'uint256' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' },
      { name: 'lockDuration', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'supportInitiative',
    outputs: [{ name: 'tokenId', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'supporterRequirements',
    outputs: [
      {
        name: 'eligibilityType',
        internalType: 'enum IAuthorizer.EligibilityType',
        type: 'uint8',
      },
      { name: 'minBalance', internalType: 'uint256', type: 'uint256' },
      { name: 'minHoldingDuration', internalType: 'uint256', type: 'uint256' },
      { name: 'minLockAmount', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'interfaceId', internalType: 'bytes4', type: 'bytes4' }],
    name: 'supportsInterface',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'index', internalType: 'uint256', type: 'uint256' }],
    name: 'tokenByIndex',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'index', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'tokenOfOwnerByIndex',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    name: 'tokenURI',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'transferFrom',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: 'newOwner', internalType: 'address', type: 'address' }],
    name: 'transferOwnership',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'underlyingToken',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'version',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'approved',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'tokenId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
    ],
    name: 'Approval',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'operator',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      { name: 'approved', internalType: 'bool', type: 'bool', indexed: false },
    ],
    name: 'ApprovalForAll',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'BoardCancelled',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'BoardClosed',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'decayCurveType',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'decayCurveParameters',
        internalType: 'uint256[]',
        type: 'uint256[]',
        indexed: false,
      },
    ],
    name: 'DecayCurveUpdated',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'version',
        internalType: 'uint64',
        type: 'uint64',
        indexed: false,
      },
    ],
    name: 'Initialized',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'initiativeId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'actor',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'InitiativeAccepted',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'initiativeId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'actor',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'InitiativeExpired',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'initiativeId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'proposer',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'metadata',
        internalType: 'struct ISignals.Metadata',
        type: 'tuple',
        components: [
          { name: 'title', internalType: 'string', type: 'string' },
          { name: 'body', internalType: 'string', type: 'string' },
          {
            name: 'attachments',
            internalType: 'struct ISignals.Attachment[]',
            type: 'tuple[]',
            components: [
              { name: 'uri', internalType: 'string', type: 'string' },
              { name: 'mimeType', internalType: 'string', type: 'string' },
              { name: 'description', internalType: 'string', type: 'string' },
            ],
          },
        ],
        indexed: false,
      },
    ],
    name: 'InitiativeProposed',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'initiativeId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'supporter',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'tokenAmount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'lockDuration',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'tokenId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'InitiativeSupported',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'previousOwner',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'newOwner',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'OwnershipTransferred',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'initiativeId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'tokenId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'payee',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'Redeemed',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'initiativeId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'lockId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'claimant',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'percentOfInitiativeRewardsWAD',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'RewardsClaimed',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'tokenId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
    ],
    name: 'Transfer',
  },
  {
    type: 'error',
    inputs: [{ name: 'target', internalType: 'address', type: 'address' }],
    name: 'AddressEmptyCode',
  },
  {
    type: 'error',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'AddressInsufficientBalance',
  },
  { type: 'error', inputs: [], name: 'DecayCurves_InvalidCurveParameters' },
  { type: 'error', inputs: [], name: 'DecayCurves_InvalidInterval' },
  { type: 'error', inputs: [], name: 'ERC721EnumerableForbiddenBatchMint' },
  {
    type: 'error',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
      { name: 'owner', internalType: 'address', type: 'address' },
    ],
    name: 'ERC721IncorrectOwner',
  },
  {
    type: 'error',
    inputs: [
      { name: 'operator', internalType: 'address', type: 'address' },
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'ERC721InsufficientApproval',
  },
  {
    type: 'error',
    inputs: [{ name: 'approver', internalType: 'address', type: 'address' }],
    name: 'ERC721InvalidApprover',
  },
  {
    type: 'error',
    inputs: [{ name: 'operator', internalType: 'address', type: 'address' }],
    name: 'ERC721InvalidOperator',
  },
  {
    type: 'error',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'ERC721InvalidOwner',
  },
  {
    type: 'error',
    inputs: [{ name: 'receiver', internalType: 'address', type: 'address' }],
    name: 'ERC721InvalidReceiver',
  },
  {
    type: 'error',
    inputs: [{ name: 'sender', internalType: 'address', type: 'address' }],
    name: 'ERC721InvalidSender',
  },
  {
    type: 'error',
    inputs: [{ name: 'tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'ERC721NonexistentToken',
  },
  {
    type: 'error',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'index', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'ERC721OutOfBoundsIndex',
  },
  { type: 'error', inputs: [], name: 'FailedInnerCall' },
  { type: 'error', inputs: [], name: 'InvalidInitialization' },
  { type: 'error', inputs: [], name: 'NotInitializing' },
  {
    type: 'error',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'OwnableInvalidOwner',
  },
  {
    type: 'error',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'OwnableUnauthorizedAccount',
  },
  { type: 'error', inputs: [], name: 'Reentrancy' },
  {
    type: 'error',
    inputs: [{ name: 'token', internalType: 'address', type: 'address' }],
    name: 'SafeERC20FailedOperation',
  },
  { type: 'error', inputs: [], name: 'Signals_AttachmentLimitExceeded' },
  { type: 'error', inputs: [], name: 'Signals_EmptyTitleOrBody' },
  { type: 'error', inputs: [], name: 'Signals_IncentivesPoolAlreadySet' },
  { type: 'error', inputs: [], name: 'Signals_IncentivesPoolNotApproved' },
  { type: 'error', inputs: [], name: 'Signals_IncorrectBoardState' },
  { type: 'error', inputs: [], name: 'Signals_IncorrectInitiativeState' },
  { type: 'error', inputs: [], name: 'Signals_InsufficientLockAmount' },
  { type: 'error', inputs: [], name: 'Signals_InsufficientSupport' },
  { type: 'error', inputs: [], name: 'Signals_InsufficientTokenDuration' },
  { type: 'error', inputs: [], name: 'Signals_InsufficientTokens' },
  { type: 'error', inputs: [], name: 'Signals_InvalidArguments' },
  { type: 'error', inputs: [], name: 'Signals_InvalidID' },
  { type: 'error', inputs: [], name: 'Signals_NotOwner' },
  { type: 'error', inputs: [], name: 'Signals_StillTimelocked' },
  {
    type: 'error',
    inputs: [{ name: 'tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'Signals_TokenAlreadyRedeemed',
  },
  { type: 'error', inputs: [], name: 'Signals_TokenHasNoCheckpointSupport' },
  { type: 'error', inputs: [], name: 'Signals_TokenTransferFailed' },
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SignalsFactory
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const signalsFactoryAbi = [
  {
    type: 'constructor',
    inputs: [
      { name: '_implementation', internalType: 'address', type: 'address' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'config',
        internalType: 'struct ISignals.BoardConfig',
        type: 'tuple',
        components: [
          { name: 'version', internalType: 'string', type: 'string' },
          {
            name: 'boardMetadata',
            internalType: 'struct ISignals.Metadata',
            type: 'tuple',
            components: [
              { name: 'title', internalType: 'string', type: 'string' },
              { name: 'body', internalType: 'string', type: 'string' },
              {
                name: 'attachments',
                internalType: 'struct ISignals.Attachment[]',
                type: 'tuple[]',
                components: [
                  { name: 'uri', internalType: 'string', type: 'string' },
                  { name: 'mimeType', internalType: 'string', type: 'string' },
                  {
                    name: 'description',
                    internalType: 'string',
                    type: 'string',
                  },
                ],
              },
            ],
          },
          { name: 'owner', internalType: 'address', type: 'address' },
          { name: 'underlyingToken', internalType: 'address', type: 'address' },
          {
            name: 'acceptanceCriteria',
            internalType: 'struct ISignals.AcceptanceCriteria',
            type: 'tuple',
            components: [
              { name: 'anyoneCanAccept', internalType: 'bool', type: 'bool' },
              {
                name: 'ownerMustFollowThreshold',
                internalType: 'bool',
                type: 'bool',
              },
              {
                name: 'percentageThresholdWAD',
                internalType: 'uint256',
                type: 'uint256',
              },
              {
                name: 'fixedThreshold',
                internalType: 'uint256',
                type: 'uint256',
              },
            ],
          },
          {
            name: 'maxLockIntervals',
            internalType: 'uint256',
            type: 'uint256',
          },
          { name: 'lockInterval', internalType: 'uint256', type: 'uint256' },
          { name: 'decayCurveType', internalType: 'uint256', type: 'uint256' },
          {
            name: 'decayCurveParameters',
            internalType: 'uint256[]',
            type: 'uint256[]',
          },
          {
            name: 'inactivityTimeout',
            internalType: 'uint256',
            type: 'uint256',
          },
          {
            name: 'proposerRequirements',
            internalType: 'struct IAuthorizer.ParticipantRequirements',
            type: 'tuple',
            components: [
              {
                name: 'eligibilityType',
                internalType: 'enum IAuthorizer.EligibilityType',
                type: 'uint8',
              },
              { name: 'minBalance', internalType: 'uint256', type: 'uint256' },
              {
                name: 'minHoldingDuration',
                internalType: 'uint256',
                type: 'uint256',
              },
              {
                name: 'minLockAmount',
                internalType: 'uint256',
                type: 'uint256',
              },
            ],
          },
          {
            name: 'supporterRequirements',
            internalType: 'struct IAuthorizer.ParticipantRequirements',
            type: 'tuple',
            components: [
              {
                name: 'eligibilityType',
                internalType: 'enum IAuthorizer.EligibilityType',
                type: 'uint8',
              },
              { name: 'minBalance', internalType: 'uint256', type: 'uint256' },
              {
                name: 'minHoldingDuration',
                internalType: 'uint256',
                type: 'uint256',
              },
              {
                name: 'minLockAmount',
                internalType: 'uint256',
                type: 'uint256',
              },
            ],
          },
          {
            name: 'releaseLockDuration',
            internalType: 'uint256',
            type: 'uint256',
          },
          { name: 'boardOpenAt', internalType: 'uint256', type: 'uint256' },
          { name: 'boardClosedAt', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    name: 'create',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'implementation',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'version',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'pure',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'board',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'boardMetadata',
        internalType: 'struct ISignals.Metadata',
        type: 'tuple',
        components: [
          { name: 'title', internalType: 'string', type: 'string' },
          { name: 'body', internalType: 'string', type: 'string' },
          {
            name: 'attachments',
            internalType: 'struct ISignals.Attachment[]',
            type: 'tuple[]',
            components: [
              { name: 'uri', internalType: 'string', type: 'string' },
              { name: 'mimeType', internalType: 'string', type: 'string' },
              { name: 'description', internalType: 'string', type: 'string' },
            ],
          },
        ],
        indexed: false,
      },
    ],
    name: 'BoardCreated',
  },
  { type: 'error', inputs: [], name: 'ERC1167FailedCreateClone' },
  { type: 'error', inputs: [], name: 'SignalsFactory_DeploymentFailed' },
  { type: 'error', inputs: [], name: 'SignalsFactory_ZeroAddressOwner' },
  { type: 'error', inputs: [], name: 'Signals_AttachmentLimitExceeded' },
  { type: 'error', inputs: [], name: 'Signals_EmptyTitleOrBody' },
] as const
