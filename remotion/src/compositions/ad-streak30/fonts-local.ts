import { continueRender, delayRender, staticFile } from 'remotion';

// Load brand fonts from local TTFs (public/fonts) — no network needed at render time.
export const AD_FONTS = {
  poppins: 'PoppinsLocal',
  inter: 'InterLocal',
} as const;

let loaded = false;

export function ensureAdFonts(): void {
  if (loaded || typeof document === 'undefined') return;
  loaded = true;
  const handle = delayRender('Loading local ad fonts');

  const faces: Array<[string, string, string]> = [
    [AD_FONTS.poppins, 'fonts/Poppins-Medium.ttf', '500'],
    [AD_FONTS.poppins, 'fonts/Poppins-SemiBold.ttf', '600'],
    [AD_FONTS.poppins, 'fonts/Poppins-Bold.ttf', '700'],
    [AD_FONTS.poppins, 'fonts/Poppins-Black.ttf', '900'],
    [AD_FONTS.inter, 'fonts/Inter_24pt-Regular.ttf', '400'],
    [AD_FONTS.inter, 'fonts/Inter_24pt-SemiBold.ttf', '600'],
    [AD_FONTS.inter, 'fonts/Inter_24pt-Bold.ttf', '700'],
  ];

  Promise.all(
    faces.map(([family, file, weight]) => {
      const face = new FontFace(family, `url('${staticFile(file)}')`, {
        weight,
      });
      return face.load().then((f) => {
        document.fonts.add(f);
      });
    })
  )
    .then(() => continueRender(handle))
    .catch(() => continueRender(handle));
}
