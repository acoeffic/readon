import { staticFile, continueRender, delayRender } from 'remotion';

// Font families used across compositions
export const FONTS = {
  libreBaskerville: 'Libre Baskerville',
  jetBrainsMono: 'JetBrains Mono',
  poppins: 'Poppins',
  inter: 'Inter',
} as const;

// Load fonts from Google Fonts CDN
const fontUrls = [
  {
    family: FONTS.libreBaskerville,
    urls: [
      'https://fonts.googleapis.com/css2?family=Libre+Baskerville:ital,wght@0,400;0,700;1,400&display=swap',
    ],
  },
  {
    family: FONTS.jetBrainsMono,
    urls: [
      'https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap',
    ],
  },
  {
    family: FONTS.poppins,
    urls: [
      'https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap',
    ],
  },
  {
    family: FONTS.inter,
    urls: [
      'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap',
    ],
  },
];

let fontsLoaded = false;

export async function loadFonts(): Promise<void> {
  if (fontsLoaded) return;

  const promises = fontUrls.flatMap(({ urls }) =>
    urls.map(async (url) => {
      const link = document.createElement('link');
      link.href = url;
      link.rel = 'stylesheet';
      document.head.appendChild(link);
      // Wait for stylesheet to load
      await new Promise<void>((resolve) => {
        link.onload = () => resolve();
        link.onerror = () => resolve(); // Don't block on error
      });
    })
  );

  await Promise.all(promises);
  // Give fonts time to apply
  await document.fonts.ready;
  fontsLoaded = true;
}
