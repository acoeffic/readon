import React from 'react';
import { FONTS } from '../fonts';
import { FadeUp } from '../animations/fade-up';

interface BrandFooterProps {
  text?: string;
  color?: string;
  startFrame?: number;
}

export const BrandFooter: React.FC<BrandFooterProps> = ({
  text = 'LEXDAY',
  color = 'rgba(127, 164, 151, 0.25)',
  startFrame = 0,
}) => {
  return (
    <FadeUp startFrame={startFrame} duration={15}>
      <div style={{ textAlign: 'center' }}>
        <span
          style={{
            fontFamily: FONTS.jetBrainsMono,
            fontSize: 9,
            letterSpacing: 3,
            color,
          }}
        >
          {text}
        </span>
      </div>
    </FadeUp>
  );
};
