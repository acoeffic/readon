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
import { Outro, Caption } from '../ad-streak30/AdStreak30';
import { ParticleField } from '../../shared/animations/particle-field';

// ─── « Pacte de rentrée : la rédemption » — 70 min lues ───────────
// 15 s (450 frames), zéro tournage. Suite d'AdPacteS1 (bilan 0 min).
export const AD_PACTE_S2_DURATION = 450;

const DARK_BG = 'radial-gradient(circle at 50% 35%, #123329 0%, #0A1F1A 65%)';
const GREEN = '#7FA497';
const AMBER = '#FFB347';
const RED = '#EB5757';
const OK_GREEN = '#2ECC71';

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
          fontSize: 80,
          lineHeight: 1.28,
          color: '#FFFFFF',
          transform: `scale(${0.92 + 0.08 * s})`,
        }}
      >
        Vous vous souvenez
        <br />
        <span style={{ color: AMBER }}>de mon zéro ?</span>
      </div>
    </Center>
  );
};

/** S2 — Roulement */
const DrumScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 14, stiffness: 190 } });
  return (
    <Center>
      <div
        style={{
          fontFamily: AD_FONTS.poppins,
          fontWeight: 900,
          fontSize: 92,
          lineHeight: 1.25,
          color: '#FFFFFF',
          transform: `scale(${0.9 + 0.1 * s})`,
        }}
      >
        Nouveau bilan
        <br />
        <span style={{ color: AMBER }}>du pacte :</span>
      </div>
    </Center>
  );
};

/** S3 — Le zéro */
const ZeroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame: frame - 4, fps, config: { damping: 9, stiffness: 140 } });
  const subIn = spring({ frame: frame - 30, fps, config: { damping: 14, stiffness: 180 } });
  const flash = interpolate(frame, [4, 6, 12], [0, 0.6, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // Léger tremblement du zéro à l'impact
  const shake = frame > 4 && frame < 16 ? Math.sin(frame * 3.1) * (16 - frame) : 0;
  return (
    <>
      <Center>
        <div
          style={{
            fontFamily: AD_FONTS.poppins,
            fontWeight: 900,
            fontSize: 300,
            lineHeight: 1,
            color: OK_GREEN,
            transform: `scale(${pop}) translateX(${shake}px)`,
            textShadow: `0 0 100px ${OK_GREEN}44`,
          }}
        >
          70<span style={{ fontSize: 130 }}> min</span>
        </div>
        <div
          style={{
            marginTop: 34,
            fontFamily: AD_FONTS.poppins,
            fontWeight: 700,
            fontSize: 56,
            color: 'rgba(255,255,255,0.8)',
            opacity: subIn,
            transform: `translateY(${(1 - subIn) * 24}px)`,
          }}
        >
          Pile les 70 promises 😅
        </div>
      </Center>
      <AbsoluteFill style={{ background: '#FFFFFF', opacity: flash, pointerEvents: 'none' }} />
    </>
  );
};

/** S4 — L'aveu */
const AveuScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 15, stiffness: 180 } });
  return (
    <Center>
      <div
        style={{
          fontFamily: AD_FONTS.poppins,
          fontWeight: 900,
          fontSize: 76,
          lineHeight: 1.3,
          color: '#FFFFFF',
          opacity: s,
          transform: `translateY(${(1 - s) * 24}px)`,
        }}
      >
        Coupable : « Le Casse du siècle ».
        <br />
        <span style={{ color: AMBER }}>Impossible à lâcher.</span>
      </div>
    </Center>
  );
};

/** S5 — La relance */
const RelanceScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const line1 = spring({ frame, fps, config: { damping: 14, stiffness: 180 } });
  const punch = spring({ frame: frame - 35, fps, config: { damping: 10, stiffness: 220 } });
  return (
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
        Prochain objectif :
        <br />
        7 soirs d'affilée.
      </div>
      {frame >= 35 && (
        <div
          style={{
            display: 'inline-block',
            marginTop: 56,
            fontFamily: AD_FONTS.poppins,
            fontWeight: 800,
            fontSize: 58,
            color: '#0A1F1A',
            background: AMBER,
            borderRadius: 24,
            padding: '22px 50px',
            transform: `scale(${punch}) rotate(-2deg)`,
            boxShadow: '0 14px 44px rgba(0,0,0,0.4)',
          }}
        >
          Le streak est lancé. 🔥
        </div>
      )}
    </Center>
  );
};

export const AdPacteS2: React.FC = () => {
  ensureAdFonts();
  const { width, height } = useVideoConfig();
  return (
    <AbsoluteFill style={{ background: '#0A1F1A' }}>
      <AbsoluteFill style={{ background: DARK_BG }} />
      <ParticleField count={40} color={GREEN} seed={23} width={width} height={height} />

      {/* S1 Hook 0–75 */}
      <Sequence durationInFrames={75} name="Hook">
        <HookScene />
      </Sequence>

      {/* S2 Roulement 75–135 */}
      <Sequence from={75} durationInFrames={60} name="Bilan semaine 1">
        <DrumScene />
      </Sequence>

      {/* S3 Zéro 135–240 */}
      <Sequence from={135} durationInFrames={105} name="0 min">
        <ZeroScene />
      </Sequence>

      {/* S4 Aveu 240–310 */}
      <Sequence from={240} durationInFrames={70} name="L'app le sait">
        <AveuScene />
      </Sequence>

      {/* S5 Relance 310–390 */}
      <Sequence from={310} durationInFrames={80} name="Semaine 2">
        <RelanceScene />
      </Sequence>

      {/* S6 Outro 390–450 */}
      <Sequence from={390} durationInFrames={60} name="Outro">
        <Outro />
      </Sequence>
    </AbsoluteFill>
  );
};
