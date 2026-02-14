import React from 'react';
import { useCurrentFrame, interpolate, Easing } from 'remotion';
import { FONTS } from '../../../shared/fonts';
import { SessionColors } from '../../../shared/colors';
import { AccentLine } from '../../../shared/components/AccentLine';
import { BrandFooter } from '../../../shared/components/BrandFooter';

export const SessionOutroScene: React.FC = () => {
  const frame = useCurrentFrame();

  const glowOpacity = interpolate(
    frame,
    [40, 60, 70, 90],
    [0, 0.15, 0.15, 0.08],
    {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    }
  );

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        height: '100%',
        position: 'relative',
      }}
    >
      {/* Subtle glow pulse */}
      <div
        style={{
          position: 'absolute',
          width: 200,
          height: 200,
          borderRadius: '50%',
          background: SessionColors.accent,
          opacity: glowOpacity,
          filter: 'blur(80px)',
        }}
      />

      <AccentLine
        width={30}
        color={SessionColors.accent}
        animateFrom={0}
        animateDuration={20}
      />

      <div style={{ height: 12 }} />

      <BrandFooter
        text="LEXDAY"
        color={`${SessionColors.accent}40`}
        startFrame={10}
      />
    </div>
  );
};
