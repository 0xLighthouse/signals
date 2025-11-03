import { UITheme } from "@/config/theme"
import { cookies } from "next/headers"

// Available SSR only
export const getThemeCookie = async () => {
  const cookieStore = await cookies()
  return cookieStore.get('theme')?.value as UITheme || UITheme.LIGHT
}
