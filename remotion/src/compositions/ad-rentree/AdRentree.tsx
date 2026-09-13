import React from 'react';
import {
  AbsoluteFill,
  Sequence,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
} from 'remotion';
import { ensureAdFonts, AD_FONTS } from '../ad-streak30/fonts-local';
import { Outro } from '../ad-streak30/AdStreak30';
import { ParticleField } from '../../shared/animations/particle-field';
import { Flame } from '../ad-streak30/Flame';

// ─── « Le pacte de rentrée » — motion design saisonnier ────────────
// 15 s (450 frames), zéro tournage. À publier autour du 1er septembre.
export const AD_RENTREE_DURATION = 450;

const DARK_BG = 'radial-gradient(circle at 50% 35%, #123329 0%, #0A1F1A 65%)';
const CREAM = '#F5E6C8';
const GREEN = '#7FA497';
const AMBER = '#FFB347';

const Center: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <AbsoluteFill
    style={{
      alignItems: 'center',
      justifyContent: 'center',
      textAlign: 'center',
      padding: '0 80px',
    }}
  >
    <div>{children}</div>
  </AbsoluteFill>
);

/** S1 — Hook */
const HookScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 15, stiffness: 190 } });
  return (
    <Center>
      <div
        style={{
          fontFamily: AD_FONTS.poppins,
          fontWeight: 900,
          fontSize: 84,
          lineHeight: 1.25,
          color: '#FFFFFF',
          transform: `scale(${0.92 + 0.08 * s})`,
        }}
      >
        Chaque année tu dis
        <br />
        <span style={{ color: AMBER }}>que tu vas lire plus.</span>
      </div>
    </Center>
  );
};

/** S2 — Beat */
const BeatScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 12, stiffness: 200 } });
  return (
    <Center>
      <div
        style={{
          fontFamily: AD_FONTS.poppins,
          fontWeight: 900,
          fontSize: 104,
          lineHeight: 1.2,
          color: AMBER,
          transform: `scale(${0.85 + 0.15 * s})`,
          textShadow: `0 0 90px ${GREEN}55`,
        }}
      >
        Cette année,
        <br />
        c'est la bonne.
      </div>
    </Center>
  );
};

const PLAN = [
  { icon: '📖', text: '10 minutes par soir' },
  { icon: '🎯', text: 'Un livre à la fois' },
  { icon: 'flame', text: 'Un streak qui te garde motivé' },
];

/** S3 — Le plan, 3 lignes qui popent */
const PlanScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const titleIn = spring({ frame, fps, config: { damping: 14, stiffness: 180 } });
  return (
    <Center>
      <div
        style={{
          fontFamily: AD_FONTS.poppins,
          fontWeight: 900,
          fontSize: 72,
          color: '#FFFFFF',
          opacity: titleIn,
          transform: `translateY(${(1 - titleIn) * 24}px)`,
          marginBottom: 70,
        }}
      >
        Le plan est simple :
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 36 }}>
        {PLAN.map(({ icon, text }, i) => {
          const pop = spring({
            frame: frame - 25 - i * 30,
            fps,
            config: { damping: 12, stiffness: 200 },
          });
          if (frame < 25 + i * 30) return <div key={i} style={{ height: 110 }} />;
          return (
            <div
              key={i}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 28,
                background: 'rgba(245,230,200,0.08)',
                border: `2px solid rgba(245,230,200,0.18)`,
                borderRadius: 26,
                padding: '30px 48px',
                transform: `scale(${pop})`,
                opacity: pop,
              }}
            >
              <span style={{ fontSize: 64, lineHeight: 1 }}>
                {icon === 'flame' ? <Flame size={64} /> : icon}
              </span>
              <span
                style={{
                  fontFamily: AD_FONTS.poppins,
                  fontWeight: 700,
                  fontSize: 58,
                  color: '#FFFFFF',
                  textAlign: 'left',
                }}
              >
                {text}
              </span>
            </div>
          );
        })}
      </div>
    </Center>
  );
};

/** S4 — Le pacte */
const PacteScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const line1 = spring({ frame, fps, config: { damping: 14, stiffness: 180 } });
  const punch = spring({ frame: frame - 40, fps, config: { damping: 10, stiffness: 220 } });
  const flash = interpolate(frame, [40, 42, 48], [0, 0.5, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <>
      <Center>
        <div
          style={{
            fontFamily: AD_FONTS.poppins,
            fontWeight: 900,
            fontSize: 76,
            lineHeight: 1.3,
            color: '#FFFFFF',
            opacity: line1,
            transform: `translateY(${(1 - line1) * 24}px)`,
          }}
        >
          Ça commence
          <br />
          le 1er septembre.
        </div>
        {frame >= 40 && (
          <div
            style={{
              display: 'inline-block',
              marginTop: 60,
              fontFamily: AD_FONTS.poppins,
              fontWeight: 800,
              fontSize: 64,
              color: '#0A1F1A',
              background: AMBER,
              borderRadius: 24,
              padding: '22px 52px',
              transform: `scale(${punch}) rotate(-2deg)`,
              boxShadow: '0 14px 44px rgba(0,0,0,0.4)',
            }}
          >
            Ou ce soir.
          </div>
        )}
      </Center>
      <AbsoluteFill style={{ background: '#FFFFFF', opacity: flash, pointerEvents: 'none' }} />
    </>
  );
};

export const AdRentree: React.FC = () => {
  ensureAdFonts();
  const { width, height } = useVideoConfig();
  return (
    <AbsoluteFill style={{ background: '#0A1F1A' }}>
      <AbsoluteFill style={{ background: DARK_BG }} />
      <ParticleField count={40} color={GREEN} seed={17} width={width} height={height} />

      {/* S1 Hook 0–70 */}
      <Sequence durationInFrames={70} name="Hook">
        <HookScene />
      </Sequence>

      {/* S2 Beat 70–130 */}
      <Sequence from={70} durationInFrames={60} name="Cette année">
        <BeatScene />
      </Sequence>

      {/* S3 Le plan 130–290 */}
      <Sequence from={130} durationInFrames={160} name="Le plan">
        <PlanScene />
      </Sequence>

      {/* S4 Le pacte 290–390 */}
      <Sequence from={290} durationInFrames={100} name="Le pacte">
        <PacteScene />
      </Sequence>

      {/* S5 Outro 390–450 */}
      <Sequence from={390} durationInFrames={60} name="Outro">
        <Outro />
      </Sequence>
    </AbsoluteFill>
  );
};
