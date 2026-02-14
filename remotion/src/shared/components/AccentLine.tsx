import React from 'react';
import { useCurrentFrame, interpolate, Easing } from 'remotion';

interface AccentLineProps {
  width?: number;
  color?: string;
  /** If set, the line grows from center on this frame */
  animateFrom?: number;
  /** Duration of grow animation in frames */
  animateDuration?: number;
}

export const AccentLine: React.FC<AccentLineProps> = ({
  width = 60,
  color = '#7FA497',
  animateFrom,
  animateDuration = 20,
}) => {
  const frame = useCurrentFrame();

  let currentWidth = width;
  if (animateFrom !== undefined) {
    currentWidth = interpolate(
      frame,
      [animateFrom, animateFrom + animateDuration],
      [0, width],
      {
        extrapolateLeft: 'clamp',
        extrapolateRight: 'clamp',
        easing: Easing.out(Easing.cubic),
      }
    );
  }

  return (
    <div
      style={{
        width: currentWidth,
        height: 1,
        margin: '0 auto',
        background: `linear-gradient(to right, transparent, ${color}80, transparent)`,
      }}
    />
  );
};
