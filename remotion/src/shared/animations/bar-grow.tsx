import React from 'react';
import { useCurrentFrame, interpolate, Easing } from 'remotion';

interface BarGrowProps {
  /** Target width as fraction 0-1 */
  fraction: number;
  /** Frame at which growth starts */
  startFrame?: number;
  /** Duration in frames */
  duration?: number;
  /** Bar height in pixels */
  height?: number;
  /** Gradient colors */
  colors?: [string, string];
  /** Background track color */
  trackColor?: string;
  style?: React.CSSProperties;
}

export const BarGrow: React.FC<BarGrowProps> = ({
  fraction,
  startFrame = 0,
  duration = 25,
  height = 3,
  colors = ['rgba(127, 164, 151, 0.3)', '#7FA497'],
  trackColor = 'rgba(255, 255, 255, 0.08)',
  style,
}) => {
  const frame = useCurrentFrame();

  const width = interpolate(
    frame,
    [startFrame, startFrame + duration],
    [0, fraction * 100],
    {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
      easing: Easing.out(Easing.cubic),
    }
  );

  return (
    <div
      style={{
        position: 'relative',
        width: '100%',
        height,
        borderRadius: height / 2,
        backgroundColor: trackColor,
        overflow: 'hidden',
        ...style,
      }}
    >
      <div
        style={{
          width: `${width}%`,
          height: '100%',
          borderRadius: height / 2,
          background: `linear-gradient(to right, ${colors[0]}, ${colors[1]})`,
        }}
      />
    </div>
  );
};
