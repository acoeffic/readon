import React from 'react';
import { useCurrentFrame, interpolate } from 'remotion';

interface ShimmerProps {
  children: React.ReactNode;
  /** Frame at which shimmer starts */
  startFrame?: number;
  /** Duration of shimmer sweep in frames */
  duration?: number;
  /** Shimmer color */
  color?: string;
}

export const Shimmer: React.FC<ShimmerProps> = ({
  children,
  startFrame = 0,
  duration = 30,
  color = 'rgba(255, 255, 255, 0.3)',
}) => {
  const frame = useCurrentFrame();

  const position = interpolate(
    frame,
    [startFrame, startFrame + duration],
    [-100, 200],
    {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    }
  );

  return (
    <div style={{ position: 'relative', overflow: 'hidden', display: 'inline-block' }}>
      {children}
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: `linear-gradient(105deg, transparent 30%, ${color} 50%, transparent 70%)`,
          transform: `translateX(${position}%)`,
          pointerEvents: 'none',
        }}
      />
    </div>
  );
};
