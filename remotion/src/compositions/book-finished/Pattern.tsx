import React from 'react';
import { useCurrentFrame } from 'remotion';

interface PatternProps {
  seed: number;
  color: string;
  width: number;
  height: number;
}

export const Pattern: React.FC<PatternProps> = ({ seed, color, width, height }) => {
  const frame = useCurrentFrame();
  const patternIndex = seed % 6;

  return (
    <svg
      style={{ position: 'absolute', inset: 0 }}
      viewBox={`0 0 ${width} ${height}`}
      xmlns="http://www.w3.org/2000/svg"
    >
      {patternIndex === 0 && <ConcentricCircles frame={frame} color={color} cx={width / 2} cy={height * 0.35} />}
      {patternIndex === 1 && <DiagonalLines frame={frame} color={color} width={width} height={height} />}
      {patternIndex === 2 && <DotsGrid frame={frame} color={color} width={width} height={height} seed={seed} />}
      {patternIndex === 3 && <Waves frame={frame} color={color} width={width} height={height} />}
      {patternIndex === 4 && <Geometric frame={frame} color={color} cx={width / 2} cy={height * 0.4} />}
      {patternIndex === 5 && <Particles frame={frame} color={color} width={width} height={height} seed={seed} />}
    </svg>
  );
};

// ─── Pattern 0: Concentric Circles ──────────────────────────────────

const ConcentricCircles: React.FC<{ frame: number; color: string; cx: number; cy: number }> = ({
  frame, color, cx, cy,
}) => {
  const rings = [60, 100, 140, 180, 220];
  return (
    <>
      {rings.map((baseR, i) => {
        const pulse = Math.sin(frame * 0.03 + i * 1.2) * 8;
        const r = baseR + pulse;
        const opacity = 0.04 + Math.sin(frame * 0.025 + i * 0.8) * 0.02;
        return (
          <circle
            key={i}
            cx={cx}
            cy={cy}
            r={r}
            fill="none"
            stroke={color}
            strokeWidth={0.5}
            opacity={opacity}
          />
        );
      })}
    </>
  );
};

// ─── Pattern 1: Diagonal Lines ──────────────────────────────────────

const DiagonalLines: React.FC<{ frame: number; color: string; width: number; height: number }> = ({
  frame, color, width, height,
}) => {
  const lines = Array.from({ length: 12 }, (_, i) => i);
  const offset = frame * 0.3;
  return (
    <>
      {lines.map((i) => {
        const spacing = 50;
        const x = -height + i * spacing + offset;
        return (
          <line
            key={i}
            x1={x}
            y1={0}
            x2={x + height}
            y2={height}
            stroke={color}
            strokeWidth={0.5}
            opacity={0.06}
          />
        );
      })}
    </>
  );
};

// ─── Pattern 2: Dots Grid ───────────────────────────────────────────

const DotsGrid: React.FC<{ frame: number; color: string; width: number; height: number; seed: number }> = ({
  frame, color, width, height, seed,
}) => {
  const cols = 8;
  const rows = 14;
  const gapX = width / (cols + 1);
  const gapY = height / (rows + 1);
  return (
    <>
      {Array.from({ length: rows }, (_, row) =>
        Array.from({ length: cols }, (_, col) => {
          const idx = row * cols + col;
          const cascadeDelay = idx * 0.8;
          const localFrame = frame - cascadeDelay;
          if (localFrame < 0) return null;
          const fadeIn = Math.min(localFrame / 10, 1);
          const pulse = 0.04 + Math.sin(frame * 0.04 + idx * 0.5) * 0.02;
          return (
            <circle
              key={`${row}-${col}`}
              cx={gapX * (col + 1)}
              cy={gapY * (row + 1)}
              r={1.5}
              fill={color}
              opacity={pulse * fadeIn}
            />
          );
        })
      )}
    </>
  );
};

// ─── Pattern 3: Waves ───────────────────────────────────────────────

const Waves: React.FC<{ frame: number; color: string; width: number; height: number }> = ({
  frame, color, width, height,
}) => {
  const waveCount = 5;
  return (
    <>
      {Array.from({ length: waveCount }, (_, i) => {
        const baseY = height * 0.2 + i * (height * 0.15);
        const phase = frame * 0.02 + i * 1.5;
        const points: string[] = [];
        for (let x = 0; x <= width; x += 4) {
          const y = baseY + Math.sin(x * 0.025 + phase) * 15 + Math.sin(x * 0.01 + phase * 0.7) * 8;
          points.push(`${x},${y}`);
        }
        return (
          <polyline
            key={i}
            points={points.join(' ')}
            fill="none"
            stroke={color}
            strokeWidth={0.5}
            opacity={0.06 + Math.sin(frame * 0.02 + i) * 0.02}
          />
        );
      })}
    </>
  );
};

// ─── Pattern 4: Geometric (hexagons) ────────────────────────────────

const Geometric: React.FC<{ frame: number; color: string; cx: number; cy: number }> = ({
  frame, color, cx, cy,
}) => {
  const sizes = [40, 80, 120];
  return (
    <>
      {sizes.map((size, i) => {
        const rotation = frame * 0.15 * (i % 2 === 0 ? 1 : -1);
        const opacity = 0.05 + Math.sin(frame * 0.03 + i) * 0.02;
        const points = hexPoints(cx, cy, size);
        return (
          <polygon
            key={i}
            points={points}
            fill="none"
            stroke={color}
            strokeWidth={0.5}
            opacity={opacity}
            transform={`rotate(${rotation} ${cx} ${cy})`}
          />
        );
      })}
    </>
  );
};

function hexPoints(cx: number, cy: number, r: number): string {
  return Array.from({ length: 6 }, (_, i) => {
    const angle = (Math.PI / 3) * i - Math.PI / 6;
    return `${cx + r * Math.cos(angle)},${cy + r * Math.sin(angle)}`;
  }).join(' ');
}

// ─── Pattern 5: Floating Particles ──────────────────────────────────

const Particles: React.FC<{ frame: number; color: string; width: number; height: number; seed: number }> = ({
  frame, color, width, height, seed,
}) => {
  const particles = React.useMemo(() => {
    const rng = seededRng(seed);
    return Array.from({ length: 20 }, () => ({
      x: rng() * width,
      y: rng() * height,
      r: 0.8 + rng() * 1.5,
      speedX: (rng() - 0.5) * 0.15,
      speedY: (rng() - 0.5) * 0.12,
      phase: rng() * Math.PI * 2,
    }));
  }, [seed, width, height]);

  return (
    <>
      {particles.map((p, i) => {
        const x = p.x + Math.sin(frame * 0.02 + p.phase) * 15 + frame * p.speedX;
        const y = p.y + Math.cos(frame * 0.015 + p.phase) * 10 + frame * p.speedY;
        const twinkle = 0.05 + Math.sin(frame * 0.06 + p.phase) * 0.04;
        return (
          <circle
            key={i}
            cx={((x % width) + width) % width}
            cy={((y % height) + height) % height}
            r={p.r}
            fill={color}
            opacity={twinkle}
          />
        );
      })}
    </>
  );
};

function seededRng(seed: number) {
  let s = seed;
  return () => {
    s = (s * 16807 + 0) % 2147483647;
    return (s - 1) / 2147483646;
  };
}
