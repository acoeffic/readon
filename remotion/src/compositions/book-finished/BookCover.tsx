import React, { useState } from 'react';
import { Img, spring, useCurrentFrame, useVideoConfig, delayRender, continueRender } from 'remotion';
import { FONTS } from '../../shared/fonts';

interface BookCoverProps {
  coverUrl: string;
  title: string;
  author: string;
  dominantColor: string;
  startFrame: number;
}

export const BookCover: React.FC<BookCoverProps> = ({
  coverUrl,
  title,
  author,
  dominantColor,
  startFrame,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const [loaded, setLoaded] = useState(!coverUrl);
  const [error, setError] = useState(false);
  const [handle] = useState(() =>
    coverUrl ? delayRender('Loading cover') : null,
  );

  const onLoad = () => {
    setLoaded(true);
    if (handle !== null) continueRender(handle);
  };
  const onError = () => {
    setError(true);
    if (handle !== null) continueRender(handle);
  };

  // Spring scale from 0.8 to 1
  const scale = spring({
    frame: frame - startFrame,
    fps,
    config: { damping: 14, stiffness: 120, mass: 0.9 },
    from: 0.8,
    to: 1,
  });

  const opacity = spring({
    frame: frame - startFrame,
    fps,
    config: { damping: 20, stiffness: 150 },
  });

  const COVER_W = 110;
  const COVER_H = 160;

  return (
    <div
      style={{
        opacity: Math.min(opacity, 1),
        transform: `scale(${scale})`,
        transformOrigin: 'center center',
        position: 'relative',
      }}
    >
      {/* Soft glow behind cover */}
      <div
        style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          width: COVER_W + 30,
          height: COVER_H + 30,
          transform: 'translate(-50%, -50%)',
          borderRadius: 18,
          background: `${dominantColor}30`,
          filter: 'blur(20px)',
        }}
      />
      {!error && coverUrl ? (
        <div
          style={{
            width: COVER_W,
            height: COVER_H,
            borderRadius: 12,
            overflow: 'hidden',
            boxShadow: `0 12px 40px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.08)`,
            position: 'relative',
          }}
        >
          <Img
            src={coverUrl}
            style={{ width: COVER_W, height: COVER_H, objectFit: 'cover' }}
            onLoad={onLoad}
            onError={onError}
          />
        </div>
      ) : (
        <CoverFallback
          title={title}
          author={author}
          dominantColor={dominantColor}
          width={COVER_W}
          height={COVER_H}
        />
      )}
    </div>
  );
};

const CoverFallback: React.FC<{
  title: string;
  author: string;
  dominantColor: string;
  width: number;
  height: number;
}> = ({ title, author, dominantColor, width, height }) => (
  <div
    style={{
      width,
      height,
      borderRadius: 12,
      background: `linear-gradient(145deg, ${dominantColor}40, ${dominantColor}15)`,
      border: '1px solid rgba(255,255,255,0.1)',
      boxShadow: '0 12px 40px rgba(0,0,0,0.5)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '16px 12px',
      boxSizing: 'border-box',
    }}
  >
    <div
      style={{
        fontFamily: FONTS.inter,
        fontSize: 14,
        fontWeight: 800,
        color: 'rgba(255,255,255,0.85)',
        textAlign: 'center',
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        display: '-webkit-box',
        WebkitLineClamp: 3,
        WebkitBoxOrient: 'vertical',
        lineHeight: 1.2,
        letterSpacing: -0.5,
      }}
    >
      {title}
    </div>
    <div style={{ height: 8 }} />
    <div style={{ width: 20, height: 1, backgroundColor: 'rgba(255,255,255,0.2)' }} />
    <div style={{ height: 8 }} />
    <div
      style={{
        fontFamily: FONTS.inter,
        fontSize: 9,
        fontWeight: 500,
        color: 'rgba(255,255,255,0.4)',
        textAlign: 'center',
        textTransform: 'uppercase',
        letterSpacing: 1,
      }}
    >
      {author}
    </div>
  </div>
);
