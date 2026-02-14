import React from 'react';
import { useCurrentFrame, interpolate, spring, useVideoConfig, Easing } from 'remotion';
import { FONTS } from '../../shared/fonts';

interface BrandingProps {
  startFrame: number;
  color?: string;
}

export const HeaderBranding: React.FC<BrandingProps> = ({ startFrame, color }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [startFrame, startFrame + 15], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  return (
    <div
      style={{
        opacity,
        fontFamily: FONTS.inter,
        fontSize: 8,
        fontWeight: 700,
        letterSpacing: 3,
        color: color || 'rgba(255,255,255,0.5)',
        textTransform: 'uppercase',
      }}
    >
      LexDay
    </div>
  );
};

export const FooterBranding: React.FC<BrandingProps> = ({ startFrame }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const logoScale = spring({
    frame: frame - startFrame,
    fps,
    config: { damping: 14, stiffness: 120 },
  });

  const taglineOpacity = interpolate(frame, [startFrame + 10, startFrame + 25], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  return (
    <div style={{ textAlign: 'center' }}>
      <div
        style={{
          opacity: Math.min(logoScale, 1),
          transform: `scale(${logoScale})`,
          fontFamily: FONTS.inter,
          fontSize: 11,
          fontWeight: 700,
          color: 'rgba(255,255,255,0.8)',
          letterSpacing: 1,
        }}
      >
        LexDay
      </div>
      <div style={{ height: 4 }} />
      <div
        style={{
          opacity: taglineOpacity,
          fontFamily: FONTS.inter,
          fontSize: 6,
          fontWeight: 500,
          color: 'rgba(255,255,255,0.25)',
        }}
      >
        Track your reading journey
      </div>
    </div>
  );
};
