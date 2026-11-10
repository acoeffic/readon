import React from 'react';
import { AbsoluteFill, Sequence, useCurrentFrame, useVideoConfig, interpolate, spring } from 'remotion';
import { ensureAdFonts, AD_FONTS } from '../ad-streak30/fonts-local';
import { Outro } from '../ad-streak30/AdStreak30';
import { ParticleField } from '../../shared/animations/particle-field';

// ─── « Pacte : la série est cassée » — 26 jours sans session ─────────
// 15 s (450 frames), zéro tournage. Hook plein dès la frame 0 (rétention 1-2 s).
// Données : dernière session LexDay le 14/10/2026 (requête Supabase du 09/11/2026).
export const AD_PACTE_S6_DURATION = 450;
const DAYS_WITHOUT_READING = 26;

const DARK_BG = 'radial-gradient(circle at 50% 35%, #123329 0%, #0A1F1A 65%)';
const GREEN = '#7FA497';
const AMBER = '#FFB347';
const RED = '#EB5757';

const Center: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '0 80px 160px' }}>
    <div>{children}</div>
  </AbsoluteFill>
);

const base = { fontFamily: AD_FONTS.poppins, fontWeight: 900, color: '#FFFFFF' } as const;

/** Hook : tout est visible dès la frame 0 */
const HookScene: React.FC = () => {
  const frame = useCurrentFrame();
  const shake = frame < 14 ? Math.sin(frame * 2.7) * (14 - frame) * 0.8 : 0;
  const flash = interpolate(frame, [0, 3, 10], [0.5, 0.35, 0], { extrapolateRight: 'clamp' });
  return (
    <>
      <Center>
        <div style={{ ...base, fontSize: 330, lineHeight: 1, color: RED, transform: `translateX(${shake}px)`, textShadow: `0 0 100px ${RED}55` }}>
          {DAYS_WITHOUT_READING}
        </div>
        <div style={{ ...base, fontSize: 92, lineHeight: 1.2, marginTop: 10 }}>
          jours sans
          <br />
          <span style={{ color: AMBER }}>ouvrir un livre.</span>
        </div>
      </Center>
      <AbsoluteFill style={{ background: '#FFFFFF', opacity: flash, pointerEvents: 'none' }} />
    </>
  );
};

const Line: React.FC<{ a: React.ReactNode; b?: React.ReactNode; size?: number; delay?: number }> = ({ a, b, size = 80, delay = 0 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: frame - delay, fps, config: { damping: 15, stiffness: 190 } });
  return (
    <Center>
      <div style={{ ...base, fontSize: size, lineHeight: 1.28, opacity: Math.min(1, s * 1.6), transform: `translateY(${(1 - s) * 24}px)` }}>
        {a}
        {b && (<><br /><span style={{ color: AMBER }}>{b}</span></>)}
      </div>
    </Center>
  );
};

/** Dernière session : le 14 octobre */
const LastSession: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame: frame - 4, fps, config: { damping: 10, stiffness: 150 } });
  const sub = spring({ frame: frame - 30, fps, config: { damping: 14, stiffness: 180 } });
  return (
    <Center>
      <div style={{ ...base, fontSize: 62, color: 'rgba(255,255,255,0.8)', fontWeight: 700 }}>Ma dernière session :</div>
      <div style={{ ...base, fontSize: 150, lineHeight: 1.05, marginTop: 20, color: AMBER, transform: `scale(${pop})` }}>
        14 octobre
      </div>
      <div style={{ ...base, fontSize: 54, fontWeight: 700, marginTop: 30, color: 'rgba(255,255,255,0.8)', opacity: sub, transform: `translateY(${(1 - sub) * 20}px)` }}>
        L'app, elle, a tout noté 📉
      </div>
    </Center>
  );
};

const Vote: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const line1 = spring({ frame, fps, config: { damping: 14, stiffness: 180 } });
  const punch = spring({ frame: frame - 22, fps, config: { damping: 10, stiffness: 220 } });
  return (
    <Center>
      <div style={{ ...base, fontSize: 76, lineHeight: 1.3, opacity: line1, transform: `translateY(${(1 - line1) * 24}px)` }}>
        Je reprends
        <br />
        ce soir ou pas ?
      </div>
      {frame >= 22 && (
        <div style={{ display: 'inline-block', marginTop: 56, fontFamily: AD_FONTS.poppins, fontWeight: 800, fontSize: 58, color: '#0A1F1A', background: AMBER, borderRadius: 24, padding: '22px 50px', transform: `scale(${punch}) rotate(-2deg)`, boxShadow: '0 14px 44px rgba(0,0,0,0.4)' }}>
          Oui ou non en commentaire 👇
        </div>
      )}
    </Center>
  );
};

export const AdPacteS6: React.FC = () => {
  ensureAdFonts();
  const { width, height } = useVideoConfig();
  return (
    <AbsoluteFill style={{ background: '#0A1F1A' }}>
      <AbsoluteFill style={{ background: DARK_BG }} />
      <ParticleField count={40} color={GREEN} seed={29} width={width} height={height} />
      <Sequence durationInFrames={90} name="Hook"><HookScene /></Sequence>
      <Sequence from={90} durationInFrames={75} name="Pacte"><Line a="Mon pacte :" b="7 jours d'affilée." /></Sequence>
      <Sequence from={165} durationInFrames={105} name="Dernière session"><LastSession /></Sequence>
      <Sequence from={270} durationInFrames={60} name="Aveu"><Line a="Le flow est cassé." b="Et je le sais." /></Sequence>
      <Sequence from={330} durationInFrames={60} name="Vote"><Vote /></Sequence>
      <Sequence from={390} durationInFrames={60} name="Outro"><Outro /></Sequence>
    </AbsoluteFill>
  );
};
