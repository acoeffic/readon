import React from 'react';
import { useCurrentFrame, interpolate, Easing } from 'remotion';
import { FONTS } from '../../../shared/fonts';
import { SessionColors } from '../../../shared/colors';
import { FadeUp } from '../../../shared/animations/fade-up';
import { BarGrow } from '../../../shared/animations/bar-grow';

interface ProgressSceneProps {
  startPage: number;
  endPage: number;
}

export const ProgressScene: React.FC<ProgressSceneProps> = ({
  startPage,
  endPage,
}) => {
  const frame = useCurrentFrame();

  const endPageOpacity = interpolate(frame, [30, 45], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        height: '100%',
        padding: '0 24px',
      }}
    >
      {/* Progression bar container */}
      <FadeUp startFrame={0} duration={15}>
        <div
          style={{
            width: 300,
            padding: '16px 20px',
            backgroundColor: 'rgba(255, 255, 255, 0.04)',
            borderRadius: 14,
            border: `1px solid ${SessionColors.accent}14`,
          }}
        >
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 12,
            }}
          >
            {/* Start page */}
            <span
              style={{
                fontFamily: FONTS.jetBrainsMono,
                fontSize: 12,
                color: 'rgba(255, 255, 255, 0.5)',
                whiteSpace: 'nowrap',
              }}
            >
              Page {startPage}
            </span>

            {/* Progress bar */}
            <div style={{ flex: 1 }}>
              <BarGrow
                fraction={1.0}
                startFrame={10}
                duration={30}
                height={3}
                colors={[`${SessionColors.accent}4D`, SessionColors.accent]}
                trackColor="rgba(255, 255, 255, 0.08)"
              />
            </div>

            {/* End page */}
            <span
              style={{
                fontFamily: FONTS.jetBrainsMono,
                fontSize: 12,
                fontWeight: 600,
                color: '#FFFFFF',
                opacity: endPageOpacity,
                whiteSpace: 'nowrap',
              }}
            >
              Page {endPage}
            </span>
          </div>
        </div>
      </FadeUp>
    </div>
  );
};
