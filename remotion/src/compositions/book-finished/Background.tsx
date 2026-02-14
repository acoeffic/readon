import React from 'react';
import { useCurrentFrame, interpolate } from 'remotion';

interface BackgroundProps {
  dominantColor: string;
  secondaryColor: string;
  width: number;
  height: number;
}

export const Background: React.FC<BackgroundProps> = ({
  dominantColor,
  secondaryColor,
  width,
  height,
}) => {
  const frame = useCurrentFrame();

  // Animated blob positions (slow, organic movement)
  const blob1X = 30 + Math.sin(frame * 0.012) * 18;
  const blob1Y = 25 + Math.cos(frame * 0.008) * 12;

  const blob2X = 70 + Math.sin(frame * 0.01 + 2) * 15;
  const blob2Y = 60 + Math.cos(frame * 0.014 + 1) * 20;

  const blob3X = 50 + Math.sin(frame * 0.009 + 4) * 22;
  const blob3Y = 85 + Math.cos(frame * 0.011 + 3) * 10;

  // Fade in the background
  const opacity = interpolate(frame, [0, 15], [0, 1], {
    extrapolateRight: 'clamp',
  });

  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        opacity,
        overflow: 'hidden',
        borderRadius: 24,
      }}
    >
      {/* Base gradient */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `linear-gradient(145deg, ${darken(dominantColor, 0.7)}, ${darken(secondaryColor, 0.75)}, ${darken(dominantColor, 0.8)})`,
        }}
      />

      {/* Radial glow from top-center */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(ellipse 100% 70% at 50% 15%, ${dominantColor}35, transparent 70%)`,
        }}
      />

      {/* Blob 1 - dominant color, large */}
      <div
        style={{
          position: 'absolute',
          left: `${blob1X}%`,
          top: `${blob1Y}%`,
          width: width * 0.6,
          height: width * 0.6,
          borderRadius: '50%',
          background: `radial-gradient(circle, ${dominantColor}20, transparent 70%)`,
          filter: 'blur(40px)',
          transform: 'translate(-50%, -50%)',
        }}
      />

      {/* Blob 2 - secondary color, medium */}
      <div
        style={{
          position: 'absolute',
          left: `${blob2X}%`,
          top: `${blob2Y}%`,
          width: width * 0.45,
          height: width * 0.45,
          borderRadius: '50%',
          background: `radial-gradient(circle, ${secondaryColor}25, transparent 70%)`,
          filter: 'blur(35px)',
          transform: 'translate(-50%, -50%)',
        }}
      />

      {/* Blob 3 - mix, small */}
      <div
        style={{
          position: 'absolute',
          left: `${blob3X}%`,
          top: `${blob3Y}%`,
          width: width * 0.35,
          height: width * 0.35,
          borderRadius: '50%',
          background: `radial-gradient(circle, ${dominantColor}18, transparent 70%)`,
          filter: 'blur(30px)',
          transform: 'translate(-50%, -50%)',
        }}
      />

      {/* Subtle vignette */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: 'radial-gradient(ellipse 80% 80% at 50% 50%, transparent 40%, rgba(0,0,0,0.4) 100%)',
        }}
      />
    </div>
  );
};

// Darken a hex color by a factor (0 = black, 1 = original)
function darken(hex: string, factor: number): string {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `rgb(${Math.round(r * factor)}, ${Math.round(g * factor)}, ${Math.round(b * factor)})`;
}
