import React from 'react';
import { useCurrentFrame, interpolate, Easing } from 'remotion';

interface FadeUpProps {
  children: React.ReactNode;
  /** Frame at which animation starts (relative to sequence) */
  startFrame?: number;
  /** Duration in frames */
  duration?: number;
  /** Y-axis offset in pixels */
  offsetY?: number;
  style?: React.CSSProperties;
}

export const FadeUp: React.FC<FadeUpProps> = ({
  children,
  startFrame = 0,
  duration = 20,
  offsetY = 30,
  style,
}) => {
  const frame = useCurrentFrame();

  const opacity = interpolate(frame, [startFrame, startFrame + duration], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  const translateY = interpolate(
    frame,
    [startFrame, startFrame + duration],
    [offsetY, 0],
    {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
      easing: Easing.out(Easing.cubic),
    }
  );

  return (
    <div
      style={{
        opacity,
        transform: `translateY(${translateY}px)`,
        ...style,
      }}
    >
      {children}
    </div>
  );
};
