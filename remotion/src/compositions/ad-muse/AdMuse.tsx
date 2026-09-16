import React from 'react';
import {
  AbsoluteFill,
  Sequence,
  OffthreadVideo,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  spring,
} from 'remotion';
import { ensureAdFonts, AD_FONTS } from '../ad-streak30/fonts-local';
import { Outro, Caption, FloatingPhone, RushView } from '../ad-streak30/AdStreak30';
import { ParticleField } from '../../shared/animations/particle-field';

// ─── « J'ai laissé une IA choisir mon prochain livre » — Muse ──────
// 15 s (450 frames). Rush unique muse.mp4 (40 s), frappe accélérée ×5.
export const AD_MUSE_DURATION = 450;

const DARK_BG = 'radial-gradient(circle at 50% 32%, #123329 0%, #0A1F1A 62%)';
const GREEN = '#7FA497';
const AMBER = '#FFB347';

const MuseClip: React.FC<{ fromSec: number; rate?: number }> = ({ fromSec, rate = 1 }) => {
  const { fps } = useVideoConfig();
  return (
    <OffthreadVideo
      src={staticFile('rushes/muse.mp4')}
      startFrom={Math.round(fromSec * fps)}
      playbackRate={rate}
      muted
      style={{ width: '100%', height: '100%', objectFit: 'cover' }}
    />
  );
};

/** Hook plein écran */
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
        J'ai laissé une IA choisir
        <br />
        <span style={{ color: AMBER }}>mon prochain livre. ✨</span>
      </div>
    </AbsoluteFill>
  );
};

export const AdMuse: React.FC = () => {
  ensureAdFonts();
  const { width, height } = useVideoConfig();
  return (
    <AbsoluteFill style={{ background: '#0A1F1A' }}>
      <AbsoluteFill style={{ background: DARK_BG }} />
      <ParticleField count={35} color={GREEN} seed={29} width={width} height={height} />

      {/* S1 Hook 0–70 */}
      <Sequence durationInFrames={70} name="Hook">
        <HookScene />
      </Sequence>

      {/* S2 La question, frappe accélérée ×5 (70–160) — raw 8→23 s */}
      <Sequence from={70} durationInFrames={90} name="Question x5">
        <FloatingPhone baseScale={0.95} rotate={-2} yOffset={40}>
          <MuseClip fromSec={8} rate={5} />
        </FloatingPhone>
        <Caption text="Étape 1 : je lui dis ce que j'ai aimé." appearAt={6} bottom={180} />
      </Sequence>

      {/* S3 Envoi + réflexion (160–205) — raw 23.2→24.7 s */}
      <Sequence from={160} durationInFrames={45} name="Réflexion">
        <FloatingPhone baseScale={0.95} rotate={2} yOffset={40}>
          <MuseClip fromSec={23.2} />
        </FloatingPhone>
        <Caption text="Étape 2 : Muse réfléchit…" appearAt={6} bottom={180} />
      </Sequence>

      {/* S4 Le verdict (205–320) — raw 28.5→32.3 s */}
      <Sequence from={205} durationInFrames={115} name="Verdict">
        <FloatingPhone baseScale={0.98} punchAt={4} yOffset={40}>
          <MuseClip fromSec={28.5} />
        </FloatingPhone>
        <Caption text="Étape 3 : verdict — un Thilliez que j'avais raté 🎯" appearAt={10} bottom={170} />
      </Sequence>

      {/* S5 La fiche livre (320–390) — image figée à 38.2 s (couverture chargée) */}
      <Sequence from={320} durationInFrames={70} name="Fiche livre">
        <FloatingPhone baseScale={0.95} yOffset={40}>
          <RushView src="muse_fiche.png" focus="50% 42%" zoomFrom={1.04} zoomTo={1.12} fallback={null} />
        </FloatingPhone>
        <Caption text="Vendu. Direct dans ma PAL." appearAt={5} bottom={180} accent />
      </Sequence>

      {/* S6 Outro 390–450 */}
      <Sequence from={390} durationInFrames={60} name="Outro">
        <Outro />
      </Sequence>
    </AbsoluteFill>
  );
};
