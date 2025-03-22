export function transform(obj: any) {
  if (obj === null || obj === undefined) {
    return obj
  }

  if (typeof obj === 'bigint') {
    return obj.toString()
  }

  if (Array.isArray(obj)) {
    return obj.map(transform)
  }

  if (typeof obj === 'object') {
    const result = {}
    for (const key in obj) {
      result[key] = transform(obj[key])
    }
    return result
  }

  return obj
}
