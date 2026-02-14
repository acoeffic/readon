import React from 'react';
import { useCurrentFrame, interpolate, Easing } from 'remotion';
import { FONTS } from '../../shared/fonts';

interface BookInfoProps {
  title: string;
  author: string;
  titleStartFrame: number;
  authorStartFrame: number;
}

export const BookInfo: React.FC<BookInfoProps> = ({
  title,
  author,
  titleStartFrame,
  authorStartFrame,
}) => {
  const frame = useCurrentFrame();

  const titleOpacity = interpolate(frame, [titleStartFrame, titleStartFrame + 18], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  const titleY = interpolate(frame, [titleStartFrame, titleStartFrame + 18], [10, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  const authorOpacity = interpolate(frame, [authorStartFrame, authorStartFrame + 15], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  // Adaptive font size: shorter titles get bigger text
  const titleLen = title.length;
  const fontSize = titleLen <= 12 ? 26 : titleLen <= 25 ? 22 : 18;

  return (
    <div style={{ textAlign: 'center', width: '100%' }}>
      <div
        style={{
          opacity: titleOpacity,
          transform: `translateY(${titleY}px)`,
          fontFamily: FONTS.inter,
          fontSize,
          fontWeight: 800,
          color: '#FFFFFF',
          letterSpacing: -0.7,
          lineHeight: 1.15,
          maxWidth: 300,
          margin: '0 auto',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          display: '-webkit-box',
          WebkitLineClamp: 2,
          WebkitBoxOrient: 'vertical',
        }}
      >
        {title}
      </div>
      <div style={{ height: 5 }} />
      <div
        style={{
          opacity: authorOpacity,
          fontFamily: FONTS.inter,
          fontSize: 10,
          fontWeight: 500,
          fontStyle: 'italic',
          color: 'rgba(255,255,255,0.5)',
        }}
      >
        {author}
      </div>
    </div>
  );
};
