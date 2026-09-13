import React from 'react';
import {
  AbsoluteFill,
  Sequence,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
} from 'remotion';
import { MonthlyWrapped } from '../monthly-wrapped/MonthlyWrapped';
import { MonthlyWrappedInput } from '../../shared/types';
import { ensureAdFonts, AD_FONTS } from '../ad-streak30/fonts-local';
import { Outro } from '../ad-streak30/AdStreak30';

// ─── Pub « Mon Wrapped du mois » ───────────────────────────────────
// Full-bleed MonthlyWrapped (180 frames) + hook TikTok + outro logo.
export const AD_WRAPPED_DURATION = 240; // 8 s @ 30 fps

export interface AdWrappedInput {
  wrapped: MonthlyWrappedInput;
  hookLine1?: string;
  hookLine2?: string;
}

const HookOverlay: React.FC<{ line1: string; line2: string }> = ({ line1, line2 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 16, stiffness: 200 } });
  const out = interpolate(frame, [100, 120], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  if (frame >= 120) return null;
  return (
    <div
      style={{
        position: 'absolute',
        top: 110,
        left: 0,
        right: 0,
        display: 'flex',
        justifyContent: 'center',
        opacity: out,
        transform: `scale(${0.9 + 0.1 * s})`,
      }}
    >
      <div
        style={{
          fontFamily: AD_FONTS.poppins,
          fontWeight: 700,
          fontSize: 54,
          color: '#FFFFFF',
          background: 'rgba(0,0,0,0.72)',
          padding: '24px 46px',
          borderRadius: 24,
          maxWidth: 880,
          textAlign: 'center',
          lineHeight: 1.3,
          boxShadow: '0 12px 40px rgba(0,0,0,0.45)',
        }}
      >
        {line1} <span style={{ color: '#FFB347' }}>{line2}</span>
      </div>
    </div>
  );
};

export const AdWrapped: React.FC<AdWrappedInput> = ({
  wrapped,
  hookLine1 = "L'app me sort ça chaque mois,",
  hookLine2 = 'sans que je fasse rien 📊',
}) => {
  ensureAdFonts();
  return (
    <AbsoluteFill style={{ background: '#0A1F1A' }}>
      {/* Wrapped plein cadre */}
      <Sequence durationInFrames={180} name="Monthly Wrapped">
        <MonthlyWrapped {...wrapped} />
      </Sequence>

      {/* Hook par-dessus le début */}
      <Sequence durationInFrames={120} name="Hook">
        <HookOverlay line1={hookLine1} line2={hookLine2} />
      </Sequence>

      {/* Outro logo */}
      <Sequence from={180} durationInFrames={AD_WRAPPED_DURATION - 180} name="Outro">
        <Outro />
      </Sequence>
    </AbsoluteFill>
  );
};
