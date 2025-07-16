import { getContractInstance } from '../clients'
import { ContractType } from '../constants'

export const getBoard = async (chainId: number, address: string) => {
  const instance = getContractInstance(chainId, ContractType.Signals)

  const result = await instance.read.name()
  console.log(result)
}
