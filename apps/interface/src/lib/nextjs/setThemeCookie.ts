const _setThemeCookie = (theme: 'dark' | 'light') => {
  document.cookie = `theme=${theme}; path=/; max-age=31536000` // Cookie expires in 1 year
}

export const setThemeCookie = (theme: 'dark' | 'light') => {
  if (theme === 'dark') {
    document.documentElement.classList.remove('light')
    document.documentElement.classList.add('dark')
    _setThemeCookie('dark')
  } else {
    document.documentElement.classList.remove('dark')
    document.documentElement.classList.add('light')
    _setThemeCookie('light')
  }
}