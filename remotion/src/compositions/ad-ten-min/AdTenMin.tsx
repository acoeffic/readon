import React from 'react';
import {
  AbsoluteFill,
  Sequence,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
  Easing,
} from 'remotion';
import { ensureAdFonts, AD_FONTS } from '../ad-streak30/fonts-local';
import { Outro, Caption } from '../ad-streak30/AdStreak30';
import { ParticleField } from '../../shared/animations/particle-field';

// ─── « Ce que 10 minutes par soir deviennent » ─────────────────────
// Motion design pur, 15 s (450 frames), zéro tournage.
export const AD_TENMIN_DURATION = 450;

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

/** Big stat scene: number counts up, label below */
const StatScene: React.FC<{
  target: number;
  suffix: string;
  label: string;
  sub?: string;
  color?: string;
}> = ({ target, suffix, label, sub, color = '#FFFFFF' }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame, fps, config: { damping: 13, stiffness: 160 } });
  const progress = interpolate(frame, [5, 40], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  const value = Math.round(target * progress);
  const labelIn = spring({ frame: frame - 12, fps, config: { damping: 14, stiffness: 180 } });
  return (
    <Center>
      <div
        style={{
          fontFamily: AD_FONTS.poppins,
          fontWeight: 900,
          fontSize: 240,
          lineHeight: 1,
          color,
          transform: `scale(${0.85 + 0.15 * pop})`,
          textShadow: `0 0 90px ${GREEN}55`,
        }}
      >
        {value}
        <span style={{ fontSize: 120 }}> {suffix}</span>
      </div>
      <div
        style={{
          marginTop: 30,
          fontFamily: AD_FONTS.poppins,
          fontWeight: 700,
          fontSize: 66,
          color: 'rgba(255,255,255,0.85)',
          opacity: labelIn,
          transform: `translateY(${(1 - labelIn) * 24}px)`,
        }}
      >
        {label}
      </div>
      {sub && (
        <div
          style={{
            marginTop: 14,
            fontFamily: AD_FONTS.inter,
            fontWeight: 600,
            fontSize: 40,
            color: 'rgba(255,255,255,0.45)',
            opacity: labelIn,
          }}
        >
          {sub}
        </div>
      )}
    </Center>
  );
};

/** Hook scene */
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
        Et si tu lisais juste
        <br />
        <span style={{ color: AMBER }}>10 minutes</span> par soir ?
      </div>
    </Center>
  );
};

/** 12 book spines popping into a shelf grid */
const BooksScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const colors = ['#7FA497', '#D4A853', '#6B1D3A', '#4F6E62', '#B0713A', '#3E5C87'];
  const titleIn = spring({ frame, fps, config: { damping: 13, stiffness: 170 } });
  return (
    <Center>
      <div
        style={{
          fontFamily: AD_FONTS.poppins,
          fontWeight: 900,
          fontSize: 110,
          color: AMBER,
          transform: `scale(${0.85 + 0.15 * titleIn})`,
          marginBottom: 60,
        }}
      >
        ≈ 12 livres
      </div>
      <div
        style={{
          display: 'flex',
          flexWrap: 'wrap',
          justifyContent: 'center',
          gap: 22,
          maxWidth: 800,
        }}
      >
        {Array.from({ length: 12 }, (_, i) => {
          const pop = spring({
            frame: frame - 6 - i * 3,
            fps,
            config: { damping: 11, stiffness: 240 },
          });
          return (
            <div
              key={i}
              style={{
                width: 120,
                height: 175,
                borderRadius: 10,
                background: `linear-gradient(160deg, ${colors[i % colors.length]}, ${colors[(i + 2) % colors.length]}66)`,
                transform: `scale(${pop})`,
                boxShadow: '0 14px 34px rgba(0,0,0,0.4)',
                display: 'flex',
                alignItems: 'flex-end',
                padding: 10,
              }}
            >
              <div
                style={{
                  width: '100%',
                  height: 8,
                  borderRadius: 4,
                  background: 'rgba(255,255,255,0.35)',
                }}
              />
            </div>
          );
        })}
      </div>
      <div
        style={{
          marginTop: 50,
          fontFamily: AD_FONTS.inter,
          fontWeight: 600,
          fontSize: 40,
          color: 'rgba(255,255,255,0.5)',
        }}
      >
        Lus en un an, sans changer ta vie
      </div>
    </Center>
  );
};

export const AdTenMin: React.FC = () => {
  ensureAdFonts();
  const { width, height } = useVideoConfig();
  return (
    <AbsoluteFill style={{ background: '#0A1F1A' }}>
      <AbsoluteFill style={{ background: DARK_BG }} />
      <ParticleField count={40} color={GREEN} seed={11} width={width} height={height} />

      {/* S1 Hook 0–75 */}
      <Sequence durationInFrames={75} name="Hook">
        <HookScene />
      </Sequence>

      {/* S2 10 min 75–150 */}
      <Sequence from={75} durationInFrames={75} name="10 min">
        <StatScene target={10} suffix="min" label="Chaque soir" sub="Avant de dormir" />
      </Sequence>

      {/* S3 5 h / mois 150–225 */}
      <Sequence from={150} durationInFrames={75} name="5h/mois">
        <StatScene target={5} suffix="h" label="Par mois" sub="Sans effort" />
      </Sequence>

      {/* S4 61 h / an 225–300 */}
      <Sequence from={225} durationInFrames={75} name="61h/an">
        <StatScene target={61} suffix="h" label="Par an" sub="Soit ~3 650 pages" color={CREAM} />
      </Sequence>

      {/* S5 12 livres 300–390 */}
      <Sequence from={300} durationInFrames={90} name="12 livres">
        <BooksScene />
        <Caption text="Commence ce soir." appearAt={55} bottom={130} accent />
      </Sequence>

      {/* S6 Outro 390–450 */}
      <Sequence from={390} durationInFrames={60} name="Outro">
        <Outro />
      </Sequence>
    </AbsoluteFill>
  );
};
