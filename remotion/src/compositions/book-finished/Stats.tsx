import React from 'react';
import { useCurrentFrame, interpolate, Easing } from 'remotion';
import { FONTS } from '../../shared/fonts';

interface StatsProps {
  readingTime: string;
  pagesRead: number;
  sessions: number;
  startDate: string;
  endDate: string;
  dominantColor: string;
  secondaryColor: string;
  heroStartFrame: number;
  gridStartFrame: number;
}

function anim(
  frame: number,
  from: number,
  to: number,
  outputRange: [number, number] = [0, 1],
) {
  return interpolate(frame, [from, to], outputRange, {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
}

export const Stats: React.FC<StatsProps> = ({
  readingTime,
  pagesRead,
  sessions,
  startDate,
  endDate,
  dominantColor,
  secondaryColor,
  heroStartFrame,
  gridStartFrame,
}) => {
  const frame = useCurrentFrame();

  // Hero stat (reading time)
  const heroOpacity = anim(frame, heroStartFrame, heroStartFrame + 18);
  const heroY = anim(frame, heroStartFrame, heroStartFrame + 18, [12, 0]);

  // Grid stats - staggered
  const s1 = anim(frame, gridStartFrame, gridStartFrame + 15);
  const s2 = anim(frame, gridStartFrame + 10, gridStartFrame + 25);
  const s3 = anim(frame, gridStartFrame + 20, gridStartFrame + 35);

  // Count-up for numbers
  const counterProgress = anim(frame, gridStartFrame, gridStartFrame + 30);
  const animPages = Math.round(pagesRead * counterProgress);
  const animSessions = Math.round(sessions * counterProgress);

  return (
    <div style={{ width: '100%' }}>
      {/* Hero stat: reading time */}
      <div
        style={{
          opacity: heroOpacity,
          transform: `translateY(${heroY}px)`,
          textAlign: 'center',
          marginBottom: 14,
        }}
      >
        <div
          style={{
            fontFamily: FONTS.inter,
            fontSize: 19,
            fontWeight: 800,
            background: `linear-gradient(135deg, ${dominantColor}, ${lighten(dominantColor, 0.3)})`,
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            backgroundClip: 'text',
            letterSpacing: -0.5,
          }}
        >
          {readingTime}
        </div>
        <div
          style={{
            fontFamily: FONTS.inter,
            fontSize: 6,
            fontWeight: 600,
            color: 'rgba(255,255,255,0.35)',
            textTransform: 'uppercase',
            letterSpacing: 2,
            marginTop: 2,
          }}
        >
          TEMPS DE LECTURE
        </div>
      </div>

      {/* Stats grid: 3 cells */}
      <div style={{ display: 'flex', gap: 8 }}>
        <StatCell
          icon={<PagesIcon />}
          value={`${animPages}`}
          label="PAGES"
          opacity={s1}
        />
        <StatCell
          icon={<SessionsIcon />}
          value={`${animSessions}`}
          label="SESSIONS"
          opacity={s2}
        />
        <StatCell
          icon={<CalendarIcon />}
          value={`${startDate} → ${endDate}`}
          label="PÉRIODE"
          opacity={s3}
          small
        />
      </div>
    </div>
  );
};

// ─── Stat Cell ──────────────────────────────────────────────────────

const StatCell: React.FC<{
  icon: React.ReactNode;
  value: string;
  label: string;
  opacity: number;
  small?: boolean;
}> = ({ icon, value, label, opacity, small }) => (
  <div
    style={{
      flex: 1,
      opacity,
      transform: `translateY(${(1 - opacity) * 8}px)`,
      padding: '10px 4px',
      backgroundColor: 'rgba(255,255,255,0.06)',
      borderRadius: 12,
      border: '1px solid rgba(255,255,255,0.06)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 3,
      boxSizing: 'border-box',
    }}
  >
    <div style={{ width: 14, height: 14, color: 'rgba(255,255,255,0.4)' }}>{icon}</div>
    <span
      style={{
        fontFamily: FONTS.inter,
        fontSize: small ? 10 : 14,
        fontWeight: 700,
        color: '#FFFFFF',
        textAlign: 'center',
        whiteSpace: 'nowrap',
      }}
    >
      {value}
    </span>
    <span
      style={{
        fontFamily: FONTS.inter,
        fontSize: 5,
        fontWeight: 600,
        color: 'rgba(255,255,255,0.3)',
        textTransform: 'uppercase',
        letterSpacing: 1,
      }}
    >
      {label}
    </span>
  </div>
);

// ─── SVG Icons ──────────────────────────────────────────────────────

const PagesIcon: React.FC = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
    <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
    <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
  </svg>
);

const SessionsIcon: React.FC = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="10" />
    <polyline points="12 6 12 12 16 14" />
  </svg>
);

const CalendarIcon: React.FC = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
    <line x1="16" y1="2" x2="16" y2="6" />
    <line x1="8" y1="2" x2="8" y2="6" />
    <line x1="3" y1="10" x2="21" y2="10" />
  </svg>
);

// ─── Helpers ────────────────────────────────────────────────────────

function lighten(hex: string, amount: number): string {
  const r = Math.min(255, parseInt(hex.slice(1, 3), 16) + Math.round(255 * amount));
  const g = Math.min(255, parseInt(hex.slice(3, 5), 16) + Math.round(255 * amount));
  const b = Math.min(255, parseInt(hex.slice(5, 7), 16) + Math.round(255 * amount));
  return `rgb(${r}, ${g}, ${b})`;
}
