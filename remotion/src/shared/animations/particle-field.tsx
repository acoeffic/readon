import React, { useMemo } from 'react';
import { useCurrentFrame, interpolate } from 'remotion';

interface Particle {
  x: number;
  y: number;
  radius: number;
  baseOpacity: number;
  twinkleSpeed: number;
  twinklePhase: number;
}

interface ParticleFieldProps {
  /** Number of particles */
  count?: number;
  /** Particle color (CSS) */
  color?: string;
  /** Seed for deterministic placement */
  seed?: number;
  width: number;
  height: number;
}

// Simple seeded random number generator
function seededRandom(seed: number) {
  let s = seed;
  return () => {
    s = (s * 16807 + 0) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

export const ParticleField: React.FC<ParticleFieldProps> = ({
  count = 35,
  color = '#7FA497',
  seed = 42,
  width,
  height,
}) => {
  const frame = useCurrentFrame();

  const particles = useMemo<Particle[]>(() => {
    const rng = seededRandom(seed);
    return Array.from({ length: count }, () => ({
      x: rng() * width,
      y: rng() * height,
      radius: 0.6 + rng() * 1.0,
      baseOpacity: 0.1 + rng() * 0.25,
      twinkleSpeed: 0.02 + rng() * 0.04,
      twinklePhase: rng() * Math.PI * 2,
    }));
  }, [count, seed, width, height]);

  return (
    <svg
      width={width}
      height={height}
      style={{ position: 'absolute', top: 0, left: 0 }}
    >
      {particles.map((p, i) => {
        const twinkle = Math.sin(frame * p.twinkleSpeed + p.twinklePhase);
        const opacity = p.baseOpacity + twinkle * 0.1;
        return (
          <circle
            key={i}
            cx={p.x}
            cy={p.y}
            r={p.radius}
            fill={color}
            opacity={Math.max(0, opacity)}
          />
        );
      })}
    </svg>
  );
};
