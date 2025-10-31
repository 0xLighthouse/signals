import { poolManagerAbi } from './pool-manager'
import { signalsAbi, signalsFactoryAbi } from './signals'
import { experimentTokenAbi, experimentTokenFactoryAbi } from './signals-token-factory'
import { erc20Abi, erc721Abi } from 'viem'
import { stateViewAbi } from './uniswap'

export const SignalsABI = signalsAbi
export const SignalsFactoryABI = signalsFactoryAbi
export const ExperimentTokenABI = experimentTokenAbi
export const ExperimentTokenFactoryABI = experimentTokenFactoryAbi
export const PoolManagerABI = poolManagerAbi
// export const IncentivesABI = incentivesAbi
export const Erc20ABI = erc20Abi
export const Erc721ABI = erc721Abi
export const StateViewABI = stateViewAbi
