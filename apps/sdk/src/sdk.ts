import { listBoards } from './actions'
import type { Network } from './constants'

interface SignalsSDKOptions {
  network: Network
}

export class SignalsSDK {
  constructor(private readonly options: SignalsSDKOptions) {}

  async paginateBoards() {
    console.log('paginateBoards()')
    const boards = await listBoards(this.options.network)
    return boards
  }
}
