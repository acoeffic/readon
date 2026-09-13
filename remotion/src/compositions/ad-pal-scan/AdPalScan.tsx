import React from 'react';
import {
  AbsoluteFill,
  Sequence,
  OffthreadVideo,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
} from 'remotion';
import { ensureAdFonts, AD_FONTS } from '../ad-streak30/fonts-local';
import { Caption, FloatingPhone, Outro } from '../ad-streak30/AdStreak30';

// ─── Concept C — « La PAL la plus satisfaisante du monde » ─────────
// 15 s, 9:16. Un seul rush (pal_scan.mp4), découpé en 5 scans + closer.
export const AD_PAL_DURATION = 450;

export interface AdPalScanInput {
  /** Rush file under public/rushes */
  rush?: string;
  hookLine1?: string;
  hookAccent?: string;
  /** [startSec] of each cut in the raw recording */
  scanStarts?: number[];
  closerStart?: number;
}

const DARK_BG = 'radial-gradient(circle at 50% 32%, #123329 0%, #0A1F1A 62%)';
const CREAM = '#F5E6C8';

// Scene boundaries (frames): 5 scans then closer then outro
const CUTS = [0, 90, 150, 210, 270, 330, 390]; // scan1..scan5, closer, outro

const RushClip: React.FC<{ src: string; fromSec: number }> = ({ src, fromSec }) => {
  const { fps } = useVideoConfig();
  return (
    <OffthreadVideo
      src={staticFile(`rushes/${src}`)}
      startFrom={Math.round(fromSec * fps)}
      muted
      style={{ width: '100%', height: '100%', objectFit: 'cover' }}
    />
  );
};

/** Hook text pinned during the scan chain */
const HookPal: React.FC<{ line1: string; accent: string }> = ({ line1, accent }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 16, stiffness: 200 } });
  return (
    <div
      style={{
        position: 'absolute',
        top: 120,
        left: 0,
        right: 0,
        textAlign: 'center',
        transform: `scale(${0.92 + 0.08 * s})`,
        fontFamily: AD_FONTS.poppins,
        fontWeight: 900,
        color: '#FFFFFF',
        fontSize: 66,
        lineHeight: 1.2,
        textShadow: '0 8px 30px rgba(0,0,0,0.5)',
        padding: '0 70px',
      }}
    >
      {line1}{' '}
      <span style={{ color: '#FFB347' }}>{accent}</span>
    </div>
  );
};

/** Book counter pill that pops at each new scan */
const BookCounter: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  // Count = number of scan boundaries passed
  const boundaries = CUTS.slice(0, 5);
  const count = boundaries.filter((b) => frame >= b).length;
  const lastBoundary = boundaries.filter((b) => frame >= b).pop() ?? 0;
  const pop = spring({
    frame: frame - lastBoundary,
    fps,
    config: { damping: 10, stiffness: 220 },
  });
  return (
    <div
      style={{
        position: 'absolute',
        bottom: 170,
        left: 0,
        right: 0,
        display: 'flex',
        justifyContent: 'center',
      }}
    >
      <div
        style={{
          fontFamily: AD_FONTS.poppins,
          fontWeight: 800,
          fontSize: 56,
          color: '#0A1F1A',
          background: CREAM,
          borderRadius: 60,
          padding: '18px 46px',
          transform: `scale(${0.9 + 0.25 * pop})`,
          boxShadow: '0 12px 40px rgba(0,0,0,0.4)',
        }}
      >
        📚 {count} / 5
      </div>
    </div>
  );
};

/** Quick white flash at scene cuts for rhythm */
const CutFlash: React.FC = () => {
  const frame = useCurrentFrame();
  let opacity = 0;
  for (const cut of CUTS.slice(1, 6)) {
    opacity = Math.max(
      opacity,
      interpolate(frame, [cut, cut + 2, cut + 7], [0, 0.55, 0], {
        extrapolateLeft: 'clamp',
        extrapolateRight: 'clamp',
      })
    );
  }
  if (opacity <= 0) return null;
  return <AbsoluteFill style={{ background: '#FFFFFF', opacity, pointerEvents: 'none' }} />;
};

export const AdPalScan: React.FC<AdPalScanInput> = (props) => {
  ensureAdFonts();
  const {
    rush = 'pal_scan.mp4',
    hookLine1 = "je range ma PAL de l'été dans",
    hookAccent = "l'app la plus satisfaisante du monde",
    scanStarts = [5.0, 18.8, 28.4, 37.0, 51.0],
    closerStart = 55.0,
  } = props;

  const rotations = [-3, 2, -2, 3, -2];

  return (
    <AbsoluteFill style={{ background: '#0A1F1A' }}>
      <AbsoluteFill style={{ background: DARK_BG }} />

      {/* 5 scans */}
      {scanStarts.map((start, i) => (
        <Sequence
          key={i}
          from={CUTS[i]}
          durationInFrames={CUTS[i + 1] - CUTS[i]}
          name={`Scan ${i + 1}`}
        >
          <FloatingPhone baseScale={0.95} rotate={rotations[i]} yOffset={40}>
            <RushClip src={rush} fromSec={start} />
          </FloatingPhone>
        </Sequence>
      ))}

      {/* Closer — bibliothèque/accueil */}
      <Sequence from={CUTS[5]} durationInFrames={CUTS[6] - CUTS[5]} name="Closer">
        <FloatingPhone baseScale={0.95} yOffset={40}>
          <RushClip src={rush} fromSec={closerStart} />
        </FloatingPhone>
        <Caption text="5 livres. 1 app. 0 excuse." appearAt={6} bottom={190} />
      </Sequence>

      {/* Overlays pendant les scans */}
      <Sequence durationInFrames={CUTS[5]} name="Hook + Counter">
        <HookPal line1={hookLine1} accent={hookAccent} />
        <BookCounter />
      </Sequence>

      <Sequence durationInFrames={CUTS[6]} name="Flashes">
        <CutFlash />
      </Sequence>

      {/* Outro logo */}
      <Sequence from={CUTS[6]} durationInFrames={AD_PAL_DURATION - CUTS[6]} name="Outro">
        <Outro />
      </Sequence>
    </AbsoluteFill>
  );
};
