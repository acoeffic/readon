import React from 'react';
import {
  AbsoluteFill,
  Sequence,
  useCurrentFrame,
  useVideoConfig,
  spring,
} from 'remotion';
import { ensureAdFonts, AD_FONTS } from '../ad-streak30/fonts-local';
import {
  Caption,
  FloatingPhone,
  Outro,
  RushView,
} from '../ad-streak30/AdStreak30';
import { Confetti } from '../ad-streak30/Confetti';

// ─── « L'app m'a démasqué » — auto-dérision heatmap ────────────────
// 14 s (420 frames). Zéro tournage : stats.png + badge.png existants.
export const AD_NIGHT_DURATION = 420;

const DARK_BG = 'radial-gradient(circle at 50% 32%, #123329 0%, #0A1F1A 62%)';
const AMBER = '#FFB347';

const HookScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 15, stiffness: 190 } });
  return (
    <AbsoluteFill
      style={{ alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '0 80px' }}
    >
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
        Cette app m'a fait réaliser
        <br />
        <span style={{ color: AMBER }}>un truc gênant 😳</span>
      </div>
    </AbsoluteFill>
  );
};

export const AdNightReader: React.FC = () => {
  ensureAdFonts();
  const { width, height } = useVideoConfig();
  return (
    <AbsoluteFill style={{ background: '#0A1F1A' }}>
      <AbsoluteFill style={{ background: DARK_BG }} />

      {/* S1 Hook 0–75 */}
      <Sequence durationInFrames={75} name="Hook">
        <HookScene />
      </Sequence>

      {/* S2 Heatmap — jamais le matin (75–165) */}
      <Sequence from={75} durationInFrames={90} name="Jamais le matin">
        <FloatingPhone baseScale={0.95} rotate={-2}>
          <RushView
            src="stats.png"
            focus="50% 85%"
            zoomFrom={1.12}
            zoomTo={1.2}
            fallback={null}
          />
        </FloatingPhone>
        <Caption text="Je lis jamais le matin." appearAt={6} bottom={190} />
      </Sequence>

      {/* S3 Heatmap — le soir par contre (165–255) */}
      <Sequence from={165} durationInFrames={90} name="Le soir par contre">
        <FloatingPhone baseScale={0.95} rotate={2}>
          <RushView
            src="stats.png"
            focus="50% 96%"
            zoomFrom={1.3}
            zoomTo={1.45}
            fallback={null}
          />
        </FloatingPhone>
        <Caption text="Mais le soir et la nuit… tous les jours 🌙" appearAt={6} bottom={190} />
      </Sequence>

      {/* S4 Punchline badge (255–360) */}
      <Sequence from={255} durationInFrames={105} name="Badge punchline">
        <FloatingPhone baseScale={0.95} punchAt={4} yOffset={60}>
          <RushView
            src="badge.png"
            focus="50% 40%"
            zoomFrom={1.0}
            zoomTo={1.08}
            fallback={null}
          />
        </FloatingPhone>
        <Confetti width={width} height={height} startFrame={8} count={70} />
        <Caption
          text="L'app m'a carrément décerné un badge pour ça 🏆"
          appearAt={10}
          bottom={170}
        />
      </Sequence>

      {/* S5 Outro (360–420) */}
      <Sequence from={360} durationInFrames={60} name="Outro">
        <Outro />
      </Sequence>
    </AbsoluteFill>
  );
};
