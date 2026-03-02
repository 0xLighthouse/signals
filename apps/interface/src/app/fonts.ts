import localFont from "next/font/local";

export const apercu = localFont({
  src: [
    {
      path: "../../public/fonts/apercu-regular.woff2",
      weight: "200",
      style: "normal",
    },
    {
      path: "../../public/fonts/apercu-medium.woff2",
      weight: "200",
      style: "normal",
    },
  ],
  variable: "--font-apercu",
  display: "swap",
});
