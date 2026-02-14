import React from 'react';
import { useCurrentFrame, interpolate, Easing } from 'remotion';

interface AnimatedCounterProps {
  /** Target value to count to */
  value: number;
  /** Frame at which counting starts */
  startFrame?: number;
  /** Duration of counting animation in frames */
  duration?: number;
  /** Suffix after the number (e.g. "h", "min", "p") */
  suffix?: string;
  /** Prefix before the number */
  prefix?: string;
  /** Format function for the number */
  formatFn?: (n: number) => string;
  style?: React.CSSProperties;
  className?: string;
}

export const AnimatedCounter: React.FC<AnimatedCounterProps> = ({
  value,
  startFrame = 0,
  duration = 30,
  suffix = '',
  prefix = '',
  formatFn,
  style,
  className,
}) => {
  const frame = useCurrentFrame();

  const progress = interpolate(
    frame,
    [startFrame, startFrame + duration],
    [0, 1],
    {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
      easing: Easing.out(Easing.cubic),
    }
  );

  const currentValue = Math.round(value * progress);
  const display = formatFn ? formatFn(currentValue) : String(currentValue);

  return (
    <span style={style} className={className}>
      {prefix}{display}{suffix}
    </span>
  );
};

/** Format minutes as "Xh" or "XhYY" */
export function formatTime(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m}min`;
  if (m === 0) return `${h}h`;
  return `${h}h${String(m).padStart(2, '0')}`;
}

/** Format duration as "X min" or "Xh Ymin" */
export function formatDuration(minutes: number): string {
  if (minutes < 60) return `${minutes} min`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${h}h${m > 0 ? ` ${m}min` : ''}`;
}
