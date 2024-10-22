import React from 'react'

// TODO: generic type
export function useAsyncProp(prop?: string | Promise<string | undefined>, initialValue?: string) {
  const [_prop, setTitle] = React.useState<string | undefined>(initialValue)
  React.useEffect(() => {
    if (typeof prop === 'string') return setTitle(prop)
    if (prop?.then) {
      prop.then((val) => setTitle(val))
    }
  }, [prop])

  return _prop
}