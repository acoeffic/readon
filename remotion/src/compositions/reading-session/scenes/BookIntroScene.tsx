import React from 'react';
import { useCurrentFrame, interpolate, Easing } from 'remotion';
import { FONTS } from '../../../shared/fonts';
import { SessionColors } from '../../../shared/colors';
import { FadeUp } from '../../../shared/animations/fade-up';
import { AccentLine } from '../../../shared/components/AccentLine';

interface BookIntroSceneProps {
  bookTitle: string;
  bookAuthor?: string;
}

export const BookIntroScene: React.FC<BookIntroSceneProps> = ({
  bookTitle,
  bookAuthor,
}) => {
  const frame = useCurrentFrame();

  // Header fade in
  const headerOpacity = interpolate(frame, [0, 20], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  // Book icon scale bounce
  const iconScale = interpolate(frame, [15, 35], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.back(1.5)),
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
      {/* Header */}
      <div
        style={{
          opacity: headerOpacity,
          fontFamily: FONTS.jetBrainsMono,
          fontSize: 9,
          letterSpacing: 5,
          color: `${SessionColors.accent}80`,
          textTransform: 'uppercase',
        }}
      >
        Session de lecture
      </div>

      <div style={{ height: 14 }} />

      {/* Book emoji */}
      <div
        style={{
          fontSize: 32,
          transform: `scale(${iconScale})`,
        }}
      >
        {'\uD83D\uDCDA'}
      </div>

      <div style={{ height: 10 }} />

      {/* Accent line */}
      <AccentLine
        width={60}
        color={SessionColors.accent}
        animateFrom={30}
        animateDuration={20}
      />

      <div style={{ height: 14 }} />

      {/* Book title */}
      <FadeUp startFrame={35} duration={20}>
        <div
          style={{
            fontFamily: FONTS.libreBaskerville,
            fontSize: 20,
            fontWeight: 700,
            color: '#FFFFFF',
            textAlign: 'center',
            maxWidth: 300,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            display: '-webkit-box',
            WebkitLineClamp: 2,
            WebkitBoxOrient: 'vertical',
          }}
        >
          {bookTitle}
        </div>
      </FadeUp>

      {/* Author */}
      {bookAuthor && (
        <FadeUp startFrame={45} duration={20}>
          <div
            style={{
              marginTop: 6,
              fontFamily: FONTS.libreBaskerville,
              fontSize: 12,
              fontStyle: 'italic',
              color: 'rgba(255, 255, 255, 0.5)',
              textAlign: 'center',
            }}
          >
            {bookAuthor}
          </div>
        </FadeUp>
      )}
    </div>
  );
};
