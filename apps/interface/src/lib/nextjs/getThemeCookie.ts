import { UITheme } from "@/config/theme"
import { cookies } from "next/headers"

// Available SSR only
export const getThemeCookie = () => {
  return cookies().get('theme')?.value as UITheme || UITheme.LIGHT
}