import React from 'react';
import { useCurrentFrame } from 'remotion';
import { FONTS } from '../../../shared/fonts';
import { SessionColors } from '../../../shared/colors';
import { AnimatedCounter, formatDuration } from '../../../shared/animations/counter';
import { FadeUp } from '../../../shared/animations/fade-up';

interface SessionStatsSceneProps {
  pagesRead: number;
  durationMinutes: number;
  startPage: number;
  endPage: number;
}

function formatPace(pagesRead: number, durationMinutes: number): string {
  if (pagesRead === 0 || durationMinutes === 0) return '-';
  const ppm = pagesRead / durationMinutes;
  if (ppm >= 1) return `${ppm.toFixed(1)} p/min`;
  const mpp = durationMinutes / pagesRead;
  return `${mpp.toFixed(1)} min/p`;
}

interface StatItemProps {
  emoji: string;
  value: React.ReactNode;
  label: string;
  startFrame: number;
}

const StatItem: React.FC<StatItemProps> = ({ emoji, value, label, startFrame }) => (
  <FadeUp startFrame={startFrame} duration={15} offsetY={20}>
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 3,
      }}
    >
      <span style={{ fontSize: 16 }}>{emoji}</span>
      <div
        style={{
          fontFamily: FONTS.jetBrainsMono,
          fontSize: 14,
          fontWeight: 700,
          color: '#FFFFFF',
          textAlign: 'center',
        }}
      >
        {value}
      </div>
      <span
        style={{
          fontFamily: FONTS.jetBrainsMono,
          fontSize: 9,
          color: 'rgba(255, 255, 255, 0.35)',
        }}
      >
        {label}
      </span>
    </div>
  </FadeUp>
);

export const SessionStatsScene: React.FC<SessionStatsSceneProps> = ({
  pagesRead,
  durationMinutes,
  startPage,
  endPage,
}) => {
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
      {/* 2x2 Stats Grid */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: '20px 0',
          width: '100%',
          maxWidth: 280,
        }}
      >
        {/* Pages */}
        <StatItem
          emoji={'\uD83D\uDCD6'}
          value={
            <AnimatedCounter
              value={pagesRead}
              startFrame={5}
              duration={25}
            />
          }
          label="pages"
          startFrame={0}
        />

        {/* Duration */}
        <StatItem
          emoji={'\u23F1\uFE0F'}
          value={formatDuration(durationMinutes)}
          label="de lecture"
          startFrame={5}
        />

        {/* Pace */}
        <StatItem
          emoji={'\u26A1'}
          value={formatPace(pagesRead, durationMinutes)}
          label="rythme"
          startFrame={10}
        />

        {/* Progression */}
        <StatItem
          emoji={'\uD83D\uDCCC'}
          value={`p.${startPage}\u2192${endPage}`}
          label="progression"
          startFrame={15}
        />
      </div>
    </div>
  );
};
