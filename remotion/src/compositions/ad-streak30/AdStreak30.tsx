import React from 'react';
import {
  AbsoluteFill,
  Sequence,
  OffthreadVideo,
  Img,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
  Easing,
} from 'remotion';
import { ensureAdFonts, AD_FONTS } from './fonts-local';
import { PhoneMockup } from './PhoneMockup';
import { Confetti } from './Confetti';
import { Flame } from './Flame';
import { StreakHome, TimerScreen, FeedScreen, StatsScreen } from './placeholders';

// ─── Timeline (30 fps) ──────────────────────────────────────────────
// S1 Hook          0–45     phone home (streak 29)
// S2 "ce soir"     45–150   session timer
// S3 THE MOMENT    150–270  streak passes 30, confetti
// S4 Friends       270–390  feed reactions
// S5 Feature flash 390–480  stats/PAL sweep + word pops
// S6 Outro         480–540  logo card
export const AD_DURATION = 540;

export interface AdStreak30Input {
  hookLine1?: string;
  hookLine2?: string;
  hookAccent?: string;
  /** Screen recordings (files under public/rushes). Null → animated placeholder. */
  rushHome?: string | null;
  rushSession?: string | null;
  rushMoment?: string | null;
  rushFeed?: string | null;
  rushSweep?: string | null;
  /** Seconds to skip at the start of each rush */
  trimHome?: number;
  trimSession?: number;
  trimMoment?: number;
  trimFeed?: number;
  trimSweep?: number;
}

const DARK_BG = 'radial-gradient(circle at 50% 32%, #123329 0%, #0A1F1A 62%)';
const CREAM = '#F5E6C8';
const GREEN = '#7FA497';

// ─── Small building blocks ─────────────────────────────────────────

const IMAGE_RE = /\.(png|jpe?g|webp)$/i;

/** Static screenshot with a slow Ken Burns zoom to keep motion */
const KenBurnsImage: React.FC<{
  src: string;
  focus?: string;
  zoomFrom?: number;
  zoomTo?: number;
}> = ({ src, focus = '50% 50%', zoomFrom = 1.02, zoomTo = 1.1 }) => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, 120], [zoomFrom, zoomTo], {
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.quad),
  });
  return (
    <Img
      src={staticFile(`rushes/${src}`)}
      style={{
        width: '100%',
        height: '100%',
        objectFit: 'cover',
        objectPosition: focus,
        transform: `scale(${scale})`,
        transformOrigin: focus,
      }}
    />
  );
};

export const RushView: React.FC<{
  src?: string | null;
  trim?: number;
  fallback: React.ReactNode;
  /** For static images: crop focus + zoom range */
  focus?: string;
  zoomFrom?: number;
  zoomTo?: number;
}> = ({ src, trim = 0, fallback, focus, zoomFrom, zoomTo }) => {
  const { fps } = useVideoConfig();
  if (!src) return <>{fallback}</>;
  if (IMAGE_RE.test(src)) {
    return <KenBurnsImage src={src} focus={focus} zoomFrom={zoomFrom} zoomTo={zoomTo} />;
  }
  return (
    <OffthreadVideo
      src={staticFile(`rushes/${src}`)}
      startFrom={Math.round(trim * fps)}
      muted
      style={{ width: '100%', height: '100%', objectFit: 'cover' }}
    />
  );
};

/** TikTok-style caption pill */
export const Caption: React.FC<{
  text: string;
  appearAt?: number;
  bottom?: number;
  accent?: boolean;
}> = ({ text, appearAt = 0, bottom = 210, accent = false }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({
    frame: frame - appearAt,
    fps,
    config: { damping: 14, stiffness: 180 },
  });
  if (frame < appearAt) return null;
  return (
    <div
      style={{
        position: 'absolute',
        bottom,
        left: 0,
        right: 0,
        display: 'flex',
        justifyContent: 'center',
        transform: `scale(${0.8 + 0.2 * s})`,
        opacity: s,
      }}
    >
      <div
        style={{
          fontFamily: AD_FONTS.poppins,
          fontWeight: 700,
          fontSize: 58,
          color: accent ? '#0A1F1A' : '#FFFFFF',
          background: accent ? CREAM : 'rgba(0,0,0,0.72)',
          padding: '22px 44px',
          borderRadius: 22,
          maxWidth: 900,
          textAlign: 'center',
          lineHeight: 1.25,
          boxShadow: '0 12px 40px rgba(0,0,0,0.35)',
        }}
      >
        {text}
      </div>
    </div>
  );
};

/** Floating phone with continuous subtle motion */
export const FloatingPhone: React.FC<{
  children: React.ReactNode;
  baseScale?: number;
  rotate?: number;
  punchAt?: number | null;
  yOffset?: number;
}> = ({ children, baseScale = 1, rotate = 0, punchAt = null, yOffset = 0 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const float = Math.sin(frame * 0.045) * 10;
  let punch = 0;
  if (punchAt !== null) {
    punch =
      0.12 *
      spring({ frame: frame - punchAt, fps, config: { damping: 11, stiffness: 150 } });
  }
  return (
    <AbsoluteFill
      style={{ alignItems: 'center', justifyContent: 'center' }}
    >
      <div style={{ transform: `translateY(${float + yOffset}px)` }}>
        <PhoneMockup width={700} rotate={rotate} scale={baseScale + punch}>
          {children}
        </PhoneMockup>
      </div>
    </AbsoluteFill>
  );
};

// ─── Scenes ────────────────────────────────────────────────────────

const HookText: React.FC<{ line1: string; line2: string; accent: string }> = ({ line1, line2, accent }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 16, stiffness: 200 } });
  return (
    <div
      style={{
        position: 'absolute',
        top: 130,
        left: 0,
        right: 0,
        textAlign: 'center',
        transform: `scale(${0.92 + 0.08 * s})`,
        fontFamily: AD_FONTS.poppins,
        fontWeight: 900,
        color: '#FFFFFF',
        fontSize: 72,
        lineHeight: 1.18,
        textShadow: '0 8px 30px rgba(0,0,0,0.5)',
        padding: '0 60px',
      }}
    >
      {line1}
      <br />
      {line2}{' '}
      <span style={{ color: '#FFB347', whiteSpace: 'nowrap' }}>
        {accent}
      </span>
    </div>
  );
};

const MomentOverlay: React.FC<{ showThirty?: boolean }> = ({ showThirty = true }) => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();
  // White flash on cut
  const flash = interpolate(frame, [0, 3, 10], [0, 0.85, 0], {
    extrapolateRight: 'clamp',
  });
  const pop = spring({ frame: frame - 6, fps, config: { damping: 10, stiffness: 120 } });
  return (
    <>
      <Confetti width={width} height={height} startFrame={5} count={110} />
      {showThirty && (
      <div
        style={{
          position: 'absolute',
          top: 30,
          left: 0,
          right: 0,
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          gap: 24,
          transform: `scale(${pop})`,
          opacity: pop,
        }}
      >
        <Flame size={100} />
        <span
          style={{
            fontFamily: AD_FONTS.poppins,
            fontWeight: 900,
            fontSize: 150,
            color: '#FFFFFF',
            textShadow: `0 0 80px ${GREEN}, 0 10px 40px rgba(0,0,0,0.5)`,
            lineHeight: 1,
          }}
        >
          30
        </span>
      </div>
      )}
      <AbsoluteFill style={{ background: '#FFFFFF', opacity: flash, pointerEvents: 'none' }} />
    </>
  );
};

const WORD_POPS = [
  { word: 'streaks', at: 0 },
  { word: 'stats', at: 22 },
  { word: 'PAL', at: 44 },
  { word: 'entre amis', at: 66 },
];

const WordPops: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <div
      style={{
        position: 'absolute',
        bottom: 200,
        left: 0,
        right: 0,
        display: 'flex',
        justifyContent: 'center',
        gap: 20,
        flexWrap: 'wrap',
        padding: '0 40px',
      }}
    >
      {WORD_POPS.map(({ word, at }) => {
        const s = spring({ frame: frame - at, fps, config: { damping: 12, stiffness: 220 } });
        if (frame < at) return null;
        return (
          <div
            key={word}
            style={{
              fontFamily: AD_FONTS.poppins,
              fontWeight: 800,
              fontSize: 54,
              color: '#0A1F1A',
              background: CREAM,
              borderRadius: 18,
              padding: '16px 34px',
              transform: `scale(${s})`,
              boxShadow: '0 10px 30px rgba(0,0,0,0.35)',
            }}
          >
            {word}
          </div>
        );
      })}
    </div>
  );
};

export const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 13, stiffness: 140 } });
  const textIn = spring({ frame: frame - 8, fps, config: { damping: 14, stiffness: 160 } });
  return (
    <AbsoluteFill
      style={{
        background: CREAM,
        alignItems: 'center',
        justifyContent: 'center',
        gap: 40,
      }}
    >
      <Img
        src={staticFile('brand/app_icon.png')}
        style={{
          width: 320,
          height: 320,
          borderRadius: 72,
          transform: `scale(${s})`,
          boxShadow: '0 30px 80px rgba(31,42,38,0.25)',
        }}
      />
      <div style={{ textAlign: 'center', transform: `translateY(${(1 - textIn) * 30}px)`, opacity: textIn }}>
        <div
          style={{
            fontFamily: AD_FONTS.poppins,
            fontWeight: 900,
            fontSize: 110,
            color: '#0A1F1A',
            letterSpacing: -2,
          }}
        >
          LexDay
        </div>
        <div
          style={{
            fontFamily: AD_FONTS.inter,
            fontWeight: 600,
            fontSize: 42,
            color: '#0A1F1A',
            opacity: 0.65,
            marginTop: 8,
          }}
        >
          Transforme ta lecture en jeu
        </div>
        <div
          style={{
            display: 'inline-block',
            marginTop: 44,
            fontFamily: AD_FONTS.poppins,
            fontWeight: 700,
            fontSize: 44,
            color: CREAM,
            background: '#0A1F1A',
            borderRadius: 60,
            padding: '22px 56px',
          }}
        >
          Gratuit sur iOS & Android
        </div>
        <div
          style={{
            marginTop: 30,
            fontFamily: AD_FONTS.inter,
            fontWeight: 600,
            fontSize: 34,
            color: GREEN,
          }}
        >
          lexday.fr
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ─── Main composition ──────────────────────────────────────────────

export const AdStreak30: React.FC<AdStreak30Input> = (props) => {
  ensureAdFonts();
  const {
    hookLine1 = 'POV : il te manque 10 min',
    hookLine2 = 'de lecture pour débloquer',
    hookAccent = 'un badge 🏆',
    rushHome = null,
    rushSession = null,
    rushMoment = null,
    rushFeed = null,
    rushSweep = null,
    trimHome = 0,
    trimSession = 0,
    trimMoment = 0,
    trimFeed = 0,
    trimSweep = 0,
  } = props;

  return (
    <AbsoluteFill style={{ background: '#0A1F1A' }}>
      <AbsoluteFill style={{ background: DARK_BG }} />

      {/* S1 + S2 — hook & session (0–150) */}
      <Sequence durationInFrames={150} name="Hook + Session">
        <Sequence durationInFrames={45} name="Home streak 29">
          <FloatingPhone baseScale={0.92} rotate={-3} yOffset={120}>
            <RushView src={rushHome} trim={trimHome} focus="50% 0%" zoomFrom={1.0} zoomTo={1.08} fallback={<StreakHome streak={29} />} />
          </FloatingPhone>
        </Sequence>
        <Sequence from={45} durationInFrames={105} name="Timer">
          <FloatingPhone baseScale={0.92} rotate={0} yOffset={120}>
            <RushView src={rushSession} trim={trimSession} focus="50% 78%" zoomFrom={1.12} zoomTo={1.24} fallback={<TimerScreen />} />
          </FloatingPhone>
          <Caption text="ce soir tu lis. pas le choix." appearAt={15} bottom={170} />
        </Sequence>
        <HookText line1={hookLine1} line2={hookLine2} accent={hookAccent} />
      </Sequence>

      {/* S3 — THE MOMENT (150–270) */}
      <Sequence from={150} durationInFrames={120} name="Streak 30">
        <FloatingPhone baseScale={0.95} punchAt={4} yOffset={200}>
          <RushView
            src={rushMoment}
            trim={trimMoment}
            focus="50% 40%"
            zoomFrom={1.0}
            zoomTo={1.1}
            fallback={<StreakHome streak={30} celebrate />}
          />
        </FloatingPhone>
        <MomentOverlay showThirty={!rushMoment} />
      </Sequence>

      {/* S4 — Friends (270–390) */}
      <Sequence from={270} durationInFrames={120} name="Feed">
        <FloatingPhone baseScale={0.95} rotate={2}>
          <RushView src={rushFeed} trim={trimFeed} focus="50% 22%" zoomFrom={1.06} zoomTo={1.16} fallback={<FeedScreen />} />
        </FloatingPhone>
        <Caption text="et tes stats le prouvent 📊" appearAt={10} bottom={190} />
      </Sequence>

      {/* S5 — Feature flash (390–480) */}
      <Sequence from={390} durationInFrames={90} name="Sweep">
        <FloatingPhone baseScale={0.95} rotate={-2}>
          <RushView src={rushSweep} trim={trimSweep} focus="50% 92%" zoomFrom={1.18} zoomTo={1.3} fallback={<StatsScreen />} />
        </FloatingPhone>
        <WordPops />
      </Sequence>

      {/* S6 — Outro (480–540) */}
      <Sequence from={480} durationInFrames={60} name="Outro">
        <Outro />
      </Sequence>
    </AbsoluteFill>
  );
};
