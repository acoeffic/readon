import React from 'react';
import { AbsoluteFill, Sequence, useCurrentFrame, useVideoConfig, interpolate, spring } from 'remotion';
import { ensureAdFonts, AD_FONTS } from '../ad-streak30/fonts-local';
import { Outro } from '../ad-streak30/AdStreak30';
import { ParticleField } from '../../shared/animations/particle-field';

// ─── « 120 heures de lecture en 30 jours » — chiffres agrégés LexDay ──
// 15 s (450 frames), zéro tournage. Données Supabase du 09/11/2026 (sessions depuis le 10/10,
// hors sessions masquées ou trop longues) : 31 lecteurs, 214 sessions, ~120 h → ~34 min/session.
export const AD_STATS_120_DURATION = 450;

const DARK_BG = 'radial-gradient(circle at 50% 35%, #123329 0%, #0A1F1A 65%)';
const GREEN = '#7FA497';
const AMBER = '#FFB347';
const OK_GREEN = '#2ECC71';

const base = { fontFamily: AD_FONTS.poppins, fontWeight: 900, color: '#FFFFFF' } as const;

const Center: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '0 80px 160px' }}>
    <div>{children}</div>
  </AbsoluteFill>
);

const HookScene: React.FC = () => {
  const frame = useCurrentFrame();
  const shake = frame < 14 ? Math.sin(frame * 2.7) * (14 - frame) * 0.8 : 0;
  const flash = interpolate(frame, [0, 3, 10], [0.5, 0.35, 0], { extrapolateRight: 'clamp' });
  return (
    <>
      <Center>
        <div style={{ ...base, fontSize: 250, lineHeight: 1, color: OK_GREEN, transform: `translateX(${shake}px)`, textShadow: `0 0 100px ${OK_GREEN}55` }}>
          120 h
        </div>
        <div style={{ ...base, fontSize: 72, lineHeight: 1.25, marginTop: 14, whiteSpace: 'nowrap' }}>
          de lecture en 30 jours
          <br />
          <span style={{ color: AMBER }}>sur LexDay.</span>
        </div>
      </Center>
      <AbsoluteFill style={{ background: '#FFFFFF', opacity: flash, pointerEvents: 'none' }} />
    </>
  );
};

const Text: React.FC<{ a: React.ReactNode; b?: React.ReactNode; size?: number }> = ({ a, b, size = 84 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 15, stiffness: 190 } });
  return (
    <Center>
      <div style={{ ...base, fontSize: size, lineHeight: 1.28, opacity: Math.min(1, s * 1.6), transform: `translateY(${(1 - s) * 24}px)` }}>
        {a}
        {b && (<><br /><span style={{ color: AMBER }}>{b}</span></>)}
      </div>
    </Center>
  );
};

const StatRow: React.FC<{ n: string; label: string; start: number }> = ({ n, label, start }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: frame - start, fps, config: { damping: 12, stiffness: 180 } });
  return (
    <div style={{ opacity: Math.min(1, s * 1.6), transform: `scale(${0.8 + 0.2 * s})`, marginBottom: 44 }}>
      <span style={{ ...base, fontSize: 150, color: OK_GREEN }}>{n}</span>
      <span style={{ ...base, fontSize: 64, marginLeft: 26, fontWeight: 700, color: 'rgba(255,255,255,0.9)' }}>{label}</span>
    </div>
  );
};

const Stats: React.FC = () => (
  <Center>
    <StatRow n="31" label="lecteurs" start={0} />
    <StatRow n="214" label="sessions" start={40} />
    <StatRow n="34" label="min par session" start={80} />
  </Center>
);

const Vote: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const l = spring({ frame, fps, config: { damping: 14, stiffness: 180 } });
  const punch = spring({ frame: frame - 22, fps, config: { damping: 10, stiffness: 220 } });
  return (
    <Center>
      <div style={{ ...base, fontSize: 76, lineHeight: 1.3, opacity: l, transform: `translateY(${(1 - l) * 24}px)` }}>
        Et toi, tu lis
        <br />
        combien d'heures
        <br />
        par mois ?
      </div>
      {frame >= 22 && (
        <div style={{ display: 'inline-block', marginTop: 50, fontFamily: AD_FONTS.poppins, fontWeight: 800, fontSize: 58, color: '#0A1F1A', background: AMBER, borderRadius: 24, padding: '22px 50px', transform: `scale(${punch}) rotate(-2deg)`, boxShadow: '0 14px 44px rgba(0,0,0,0.4)' }}>
          Dis-le en commentaire 👇
        </div>
      )}
    </Center>
  );
};

export const AdStats120: React.FC = () => {
  ensureAdFonts();
  const { width, height } = useVideoConfig();
  return (
    <AbsoluteFill style={{ background: '#0A1F1A' }}>
      <AbsoluteFill style={{ background: DARK_BG }} />
      <ParticleField count={40} color={GREEN} seed={37} width={width} height={height} />
      <Sequence durationInFrames={90} name="Hook"><HookScene /></Sequence>
      <Sequence from={90} durationInFrames={85} name="5 jours"><Text a="Soit 5 jours entiers" b="de lecture non-stop" size={80} /></Sequence>
      <Sequence from={175} durationInFrames={155} name="Chiffres"><Stats /></Sequence>
      <Sequence from={330} durationInFrames={60} name="Vote"><Vote /></Sequence>
      <Sequence from={390} durationInFrames={60} name="Outro"><Outro /></Sequence>
    </AbsoluteFill>
  );
};
