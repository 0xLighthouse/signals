//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// StateView
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const stateViewAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_poolManager',
        internalType: 'contract IPoolManager',
        type: 'address',
      },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: 'poolId', internalType: 'PoolId', type: 'bytes32' }],
    name: 'getFeeGrowthGlobals',
    outputs: [
      { name: 'feeGrowthGlobal0', internalType: 'uint256', type: 'uint256' },
      { name: 'feeGrowthGlobal1', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'PoolId', type: 'bytes32' },
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' },
    ],
    name: 'getFeeGrowthInside',
    outputs: [
      {
        name: 'feeGrowthInside0X128',
        internalType: 'uint256',
        type: 'uint256',
      },
      {
        name: 'feeGrowthInside1X128',
        internalType: 'uint256',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'poolId', internalType: 'PoolId', type: 'bytes32' }],
    name: 'getLiquidity',
    outputs: [{ name: 'liquidity', internalType: 'uint128', type: 'uint128' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'PoolId', type: 'bytes32' },
      { name: 'positionId', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'getPositionInfo',
    outputs: [
      { name: 'liquidity', internalType: 'uint128', type: 'uint128' },
      {
        name: 'feeGrowthInside0LastX128',
        internalType: 'uint256',
        type: 'uint256',
      },
      {
        name: 'feeGrowthInside1LastX128',
        internalType: 'uint256',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'PoolId', type: 'bytes32' },
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'tickLower', internalType: 'int24', type: 'int24' },
      { name: 'tickUpper', internalType: 'int24', type: 'int24' },
      { name: 'salt', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'getPositionInfo',
    outputs: [
      { name: 'liquidity', internalType: 'uint128', type: 'uint128' },
      {
        name: 'feeGrowthInside0LastX128',
        internalType: 'uint256',
        type: 'uint256',
      },
      {
        name: 'feeGrowthInside1LastX128',
        internalType: 'uint256',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'PoolId', type: 'bytes32' },
      { name: 'positionId', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'getPositionLiquidity',
    outputs: [{ name: 'liquidity', internalType: 'uint128', type: 'uint128' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'poolId', internalType: 'PoolId', type: 'bytes32' }],
    name: 'getSlot0',
    outputs: [
      { name: 'sqrtPriceX96', internalType: 'uint160', type: 'uint160' },
      { name: 'tick', internalType: 'int24', type: 'int24' },
      { name: 'protocolFee', internalType: 'uint24', type: 'uint24' },
      { name: 'lpFee', internalType: 'uint24', type: 'uint24' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'PoolId', type: 'bytes32' },
      { name: 'tick', internalType: 'int16', type: 'int16' },
    ],
    name: 'getTickBitmap',
    outputs: [{ name: 'tickBitmap', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'PoolId', type: 'bytes32' },
      { name: 'tick', internalType: 'int24', type: 'int24' },
    ],
    name: 'getTickFeeGrowthOutside',
    outputs: [
      {
        name: 'feeGrowthOutside0X128',
        internalType: 'uint256',
        type: 'uint256',
      },
      {
        name: 'feeGrowthOutside1X128',
        internalType: 'uint256',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'PoolId', type: 'bytes32' },
      { name: 'tick', internalType: 'int24', type: 'int24' },
    ],
    name: 'getTickInfo',
    outputs: [
      { name: 'liquidityGross', internalType: 'uint128', type: 'uint128' },
      { name: 'liquidityNet', internalType: 'int128', type: 'int128' },
      {
        name: 'feeGrowthOutside0X128',
        internalType: 'uint256',
        type: 'uint256',
      },
      {
        name: 'feeGrowthOutside1X128',
        internalType: 'uint256',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'poolId', internalType: 'PoolId', type: 'bytes32' },
      { name: 'tick', internalType: 'int24', type: 'int24' },
    ],
    name: 'getTickLiquidity',
    outputs: [
      { name: 'liquidityGross', internalType: 'uint128', type: 'uint128' },
      { name: 'liquidityNet', internalType: 'int128', type: 'int128' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'poolManager',
    outputs: [
      { name: '', internalType: 'contract IPoolManager', type: 'address' },
    ],
    stateMutability: 'view',
  },
  { type: 'error', inputs: [], name: 'NotPoolManager' },
] as const
