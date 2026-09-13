import React, { useMemo } from 'react';
import { useCurrentFrame, interpolate } from 'remotion';

interface ConfettiProps {
  width: number;
  height: number;
  count?: number;
  seed?: number;
  /** Frame (relative to sequence) at which the burst starts */
  startFrame?: number;
  colors?: string[];
}

function seededRandom(seed: number) {
  let s = seed;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

export const Confetti: React.FC<ConfettiProps> = ({
  width,
  height,
  count = 90,
  seed = 7,
  startFrame = 0,
  colors = ['#7FA497', '#D4A853', '#EB5757', '#F5E6C8', '#5B8DEF', '#FF7A2F'],
}) => {
  const frame = useCurrentFrame();
  const t = Math.max(0, frame - startFrame);

  const pieces = useMemo(() => {
    const rng = seededRandom(seed + 1);
    return Array.from({ length: count }, () => ({
      x0: rng() * width,
      vx: (rng() - 0.5) * 6,
      delay: rng() * 12,
      speed: 9 + rng() * 9,
      size: 12 + rng() * 16,
      color: colors[Math.floor(rng() * colors.length)],
      rot: rng() * 360,
      rotSpeed: (rng() - 0.5) * 20,
      wobble: rng() * Math.PI * 2,
      isRect: rng() > 0.4,
    }));
  }, [count, seed, width, colors]);

  if (t <= 0) return null;

  return (
    <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
      {pieces.map((p, i) => {
        const local = Math.max(0, t - p.delay);
        const y = -60 + local * p.speed;
        if (y > height + 60) return null;
        const x = p.x0 + p.vx * local + Math.sin(local * 0.15 + p.wobble) * 30;
        const opacity = interpolate(local, [0, 6], [0, 1], {
          extrapolateRight: 'clamp',
        });
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x,
              top: y,
              width: p.size,
              height: p.isRect ? p.size * 0.55 : p.size,
              borderRadius: p.isRect ? 3 : '50%',
              background: p.color,
              opacity,
              transform: `rotate(${p.rot + local * p.rotSpeed}deg)`,
            }}
          />
        );
      })}
    </div>
  );
};
