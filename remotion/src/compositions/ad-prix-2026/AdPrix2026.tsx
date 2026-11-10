import React from 'react';
import { AbsoluteFill, Sequence, useCurrentFrame, useVideoConfig, interpolate, spring } from 'remotion';
import { ensureAdFonts, AD_FONTS } from '../ad-streak30/fonts-local';
import { Outro } from '../ad-streak30/AdStreak30';
import { ParticleField } from '../../shared/animations/particle-field';

// ─── « Grands prix littéraires 2026 : 0/6 lus » ──────────────────────
// 15 s (450 frames), zéro tournage. Score affiché dès la frame 0.
// Lauréats : Fnac L'Éclaireur (04/11/2026) + Livres Hebdo.
export const AD_PRIX_2026_DURATION = 450;

const DARK_BG = 'radial-gradient(circle at 50% 35%, #2B1D0E 0%, #140E07 65%)';
const GOLD = '#E8B64C';
const AMBER = '#FFB347';
const RED = '#EB5757';

const PRIZES: { prize: string; title: string; author: string }[] = [
  { prize: 'Goncourt', title: "L'inconnue du Quai de Javel", author: 'Philippe Jaenada' },
  { prize: 'Renaudot', title: 'Le Palais', author: 'François-Henri Désérable' },
  { prize: 'Femina', title: 'La Solitude des professeurs est infinie', author: 'Yannick Haenel' },
  { prize: 'Médicis', title: 'Dans les grandes lignes', author: 'Philippe Vasset' },
  { prize: 'Académie française', title: 'Le Rappel des oiseaux', author: 'Sébastien Lapaque' },
  { prize: 'Roman Fnac', title: "C'était ça ou mourir", author: 'Thélyson Orélien' },
];

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
        <div style={{ ...base, fontSize: 300, lineHeight: 1, color: RED, transform: `translateX(${shake}px)`, textShadow: `0 0 100px ${RED}55` }}>
          0/6
        </div>
        <div style={{ ...base, fontSize: 84, lineHeight: 1.2, marginTop: 12 }}>
          Grands prix 2026
          <br />
          <span style={{ color: AMBER }}>lus par moi.</span>
        </div>
      </Center>
      <AbsoluteFill style={{ background: '#FFFFFF', opacity: flash, pointerEvents: 'none' }} />
    </>
  );
};

const Row: React.FC<{ i: number; p: (typeof PRIZES)[number] }> = ({ i, p }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const start = i * 26;
  const s = spring({ frame: frame - start, fps, config: { damping: 15, stiffness: 200 } });
  const cross = spring({ frame: frame - start - 14, fps, config: { damping: 12, stiffness: 220 } });
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 28, textAlign: 'left', opacity: Math.min(1, s * 1.6), transform: `translateX(${(1 - s) * -60}px)`, marginBottom: 34 }}>
      <div style={{ fontSize: 70, width: 90, textAlign: 'center', transform: `scale(${cross})`, opacity: frame - start >= 14 ? 1 : 0 }}>❌</div>
      <div>
        <div style={{ ...base, fontSize: 34, color: GOLD, textTransform: 'uppercase', letterSpacing: 2 }}>{p.prize}</div>
        <div style={{ ...base, fontSize: 46, lineHeight: 1.15 }}>{p.title}</div>
        <div style={{ fontFamily: AD_FONTS.poppins, fontWeight: 600, fontSize: 34, color: 'rgba(255,255,255,0.7)' }}>{p.author}</div>
      </div>
    </div>
  );
};

const ListScene: React.FC = () => (
  <AbsoluteFill style={{ justifyContent: 'center', padding: '0 70px 170px 90px' }}>
    <div style={{ ...base, fontSize: 64, color: RED, textAlign: 'center', marginBottom: 46 }}>0/6</div>
    {PRIZES.map((p, i) => (<Row key={p.prize} i={i} p={p} />))}
  </AbsoluteFill>
);

const Text: React.FC<{ a: React.ReactNode; b?: React.ReactNode; size?: number }> = ({ a, b, size = 80 }) => {
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

const Vote: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const l = spring({ frame, fps, config: { damping: 14, stiffness: 180 } });
  const punch = spring({ frame: frame - 22, fps, config: { damping: 10, stiffness: 220 } });
  return (
    <Center>
      <div style={{ ...base, fontSize: 76, lineHeight: 1.3, opacity: l, transform: `translateY(${(1 - l) * 24}px)` }}>
        Et toi, ton score
        <br />
        sur 6 ?
      </div>
      {frame >= 22 && (
        <div style={{ display: 'inline-block', marginTop: 50, fontFamily: AD_FONTS.poppins, fontWeight: 800, fontSize: 58, color: '#140E07', background: AMBER, borderRadius: 24, padding: '22px 50px', transform: `scale(${punch}) rotate(-2deg)`, boxShadow: '0 14px 44px rgba(0,0,0,0.4)' }}>
          Dis-le en commentaire 👇
        </div>
      )}
    </Center>
  );
};

export const AdPrix2026: React.FC = () => {
  ensureAdFonts();
  const { width, height } = useVideoConfig();
  return (
    <AbsoluteFill style={{ background: '#140E07' }}>
      <AbsoluteFill style={{ background: DARK_BG }} />
      <ParticleField count={40} color={GOLD} seed={31} width={width} height={height} />
      <Sequence durationInFrames={75} name="Hook"><HookScene /></Sequence>
      <Sequence from={75} durationInFrames={190} name="Les 6 lauréats"><ListScene /></Sequence>
      <Sequence from={265} durationInFrames={55} name="Bilan"><Text a="Bilan : 0/6." b="Tout dans ma PAL 😅" size={76} /></Sequence>
      <Sequence from={320} durationInFrames={70} name="Relance"><Vote /></Sequence>
      <Sequence from={390} durationInFrames={60} name="Outro"><Outro /></Sequence>
    </AbsoluteFill>
  );
};
