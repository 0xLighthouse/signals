import { useNetworkStore } from '@/stores/useNetworkStore'

export const useNetwork = () =>
  useNetworkStore((state) => ({
    selected: state.selected,
    config: state.config,
    setNetwork: state.setNetwork,
  }))
