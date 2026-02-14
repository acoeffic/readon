import React from 'react';
import { FONTS } from '../fonts';
import { FadeUp } from '../animations/fade-up';

interface StatCellProps {
  emoji: string;
  value: string;
  label: string;
  /** Frame offset for stagger animation */
  startFrame?: number;
  accentColor?: string;
}

export const StatCell: React.FC<StatCellProps> = ({
  emoji,
  value,
  label,
  startFrame = 0,
  accentColor,
}) => {
  return (
    <FadeUp startFrame={startFrame} duration={15} offsetY={20}>
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 3,
        }}
      >
        <span style={{ fontSize: 16 }}>{emoji}</span>
        <span
          style={{
            fontFamily: FONTS.jetBrainsMono,
            fontSize: 14,
            fontWeight: 700,
            color: '#FFFFFF',
          }}
        >
          {value}
        </span>
        <span
          style={{
            fontFamily: FONTS.jetBrainsMono,
            fontSize: 9,
            color: 'rgba(255, 255, 255, 0.35)',
          }}
        >
          {label}
        </span>
      </div>
    </FadeUp>
  );
};
