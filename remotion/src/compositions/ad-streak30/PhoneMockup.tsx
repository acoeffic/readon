import React from 'react';

interface PhoneMockupProps {
  children: React.ReactNode;
  /** Total mockup width in px (height follows 19.5:9 iPhone ratio) */
  width?: number;
  rotate?: number;
  scale?: number;
  style?: React.CSSProperties;
}

// iPhone-style frame: bezel + rounded screen + Dynamic Island.
export const PhoneMockup: React.FC<PhoneMockupProps> = ({
  children,
  width = 700,
  rotate = 0,
  scale = 1,
  style,
}) => {
  const height = (width * 19.5) / 9;
  const bezel = width * 0.022;
  const radius = width * 0.155;

  return (
    <div
      style={{
        width,
        height,
        transform: `rotate(${rotate}deg) scale(${scale})`,
        borderRadius: radius,
        background: '#1B1B1D',
        padding: bezel,
        boxShadow:
          '0 60px 120px rgba(0,0,0,0.55), 0 20px 45px rgba(0,0,0,0.4), inset 0 0 0 3px #3A3A3E',
        position: 'relative',
        ...style,
      }}
    >
      <div
        style={{
          width: '100%',
          height: '100%',
          borderRadius: radius - bezel,
          overflow: 'hidden',
          position: 'relative',
          background: '#000',
        }}
      >
        {children}
        {/* Dynamic Island */}
        <div
          style={{
            position: 'absolute',
            top: width * 0.028,
            left: '50%',
            transform: 'translateX(-50%)',
            width: width * 0.28,
            height: width * 0.085,
            borderRadius: width * 0.05,
            background: '#000',
          }}
        />
      </div>
    </div>
  );
};
