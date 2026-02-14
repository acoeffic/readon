import React from 'react';
import { useCurrentFrame, interpolate } from 'remotion';

interface TypewriterProps {
  text: string;
  /** Frame at which typing starts */
  startFrame?: number;
  /** Frames per character */
  speed?: number;
  style?: React.CSSProperties;
  className?: string;
}

export const Typewriter: React.FC<TypewriterProps> = ({
  text,
  startFrame = 0,
  speed = 2,
  style,
  className,
}) => {
  const frame = useCurrentFrame();
  const totalDuration = text.length * speed;

  const charCount = Math.floor(
    interpolate(
      frame,
      [startFrame, startFrame + totalDuration],
      [0, text.length],
      {
        extrapolateLeft: 'clamp',
        extrapolateRight: 'clamp',
      }
    )
  );

  return (
    <span style={style} className={className}>
      {text.slice(0, charCount)}
    </span>
  );
};
