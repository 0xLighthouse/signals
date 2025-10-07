import { poolManagerAbi } from './pool-manager'
import { signalsAbi, signalsFactoryAbi, incentivesAbi } from './signals'
import { erc20Abi, erc721Abi } from 'viem'
import { stateViewAbi } from './uniswap'

export const SignalsABI = signalsAbi
export const SignalsFactoryABI = signalsFactoryAbi
export const PoolManagerABI = poolManagerAbi
export const IncentivesABI = incentivesAbi
export const Erc20ABI = erc20Abi
export const Erc721ABI = erc721Abi
export const StateViewABI = stateViewAbi
