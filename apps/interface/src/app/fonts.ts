import localFont from "next/font/local";


export const openSauce = localFont({
  src: [
    {
      path: "../../public/fonts/open-sauce-one-latin-500-normal.woff2",
      weight: "500",
      style: "normal",
    },
    {
      path: "../../public/fonts/open-sauce-one-latin-500-italic.woff2",
      weight: "500",
      style: "italic",
    },
  ],
  variable: "--font-open-sauce",
  display: "swap",
});
