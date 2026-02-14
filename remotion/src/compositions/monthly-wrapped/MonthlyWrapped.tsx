import React, { useEffect, useState } from 'react';
import {
  AbsoluteFill,
  Audio,
  useCurrentFrame,
  interpolate,
  Easing,
  spring,
  useVideoConfig,
  staticFile,
  delayRender,
  continueRender,
} from 'remotion';
import { MonthlyWrappedInput } from '../../shared/types';
import { ParticleField } from '../../shared/animations/particle-field';
import { loadFonts, FONTS } from '../../shared/fonts';
import { getMonthTheme, getMonthName } from '../../shared/month-themes';

// ──────────────────────────────────────────────────────────────────────
// MonthlyWrapped – Single animated card reproducing the Flutter
// MonthlyWrappedShareCard with month-specific themes and progressive
// element reveal.
//
// 450 frames (15s @ 30fps). Animation timeline:
//   0-20:   Card container fades in
//   5-25:   "LEXDAY WRAPPED" header fades in
//  15-35:   Emoji bounces in (spring)
//  25-55:   Month name reveals
//  35-55:   Year fades in
//  55-65:   Accent line grows
//  70-130:  Stats 2x2 grid (staggered)
// 140-175:  Top book card slides in
// 180-210:  VS last month fades in
// 220-250:  Footer
// 250-420:  Hold
// 420-450:  Glow pulse
// ──────────────────────────────────────────────────────────────────────

function formatTime(minutes: number): string {
  if (minutes < 60) return `${minutes}min`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m > 0 ? `${h}h${m}` : `${h}h`;
}

function anim(
  frame: number,
  from: number,
  to: number,
  outputRange: [number, number] = [0, 1],
  easing = Easing.out(Easing.cubic),
) {
  return interpolate(frame, [from, to], outputRange, {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing,
  });
}

const previousMonthNames = [
  '', 'décembre', 'janvier', 'février', 'mars', 'avril', 'mai',
  'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre',
];

export const MonthlyWrapped: React.FC<MonthlyWrappedInput> = (props) => {
  const {
    format,
    month,
    year,
    totalMinutes,
    sessions,
    booksFinished,
    longestFlow,
    topBook,
    vsLastMonthPercent,
  } = props;
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Load fonts
  const [fontHandle] = useState(() => delayRender('Loading fonts'));
  useEffect(() => {
    loadFonts().then(() => continueRender(fontHandle));
  }, [fontHandle]);

  const theme = getMonthTheme(month);
  const accent = theme.accent;
  const monthName = getMonthName(month);
  const isStory = format === 'story';
  const SCALE = 3;
  const W = 360;
  const H = isStory ? 640 : 360;
  const seed = month * 1000 + year;

  // Emoji spring
  const emojiSpring = spring({
    frame: frame - 15,
    fps,
    config: { damping: 12, stiffness: 200 },
  });

  // Animated counters
  const counterProgress = anim(frame, 75, 125);
  const animatedMinutes = Math.round(totalMinutes * counterProgress);
  const animatedSessions = Math.round(sessions * counterProgress);
  const animatedBooks = Math.round(booksFinished * counterProgress);
  const animatedFlow = Math.round(longestFlow * counterProgress);

  // End glow
  const endGlow =
    frame > 420 ? 0.04 + Math.sin((frame - 420) * 0.15) * 0.03 : 0;

  // Audio volume: fade-in 0→0.3 over first 30 frames, fade-out 0.3→0 over last 30 frames
  const musicVolume = (f: number) => {
    const fadeIn = interpolate(f, [0, 30], [0, 0.3], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
    const fadeOut = interpolate(f, [420, 450], [0.3, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
    return Math.min(fadeIn, fadeOut);
  };

  return (
    <AbsoluteFill style={{ backgroundColor: '#000' }}>
      <Audio src={staticFile('audio/wrapped_melody.wav')} volume={musicVolume} />
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: W,
          height: H,
          transform: `scale(${SCALE})`,
          transformOrigin: 'top left',
        }}
      >
        {/* Card container */}
        <div
          style={{
            width: W,
            height: H,
            borderRadius: 24,
            overflow: 'hidden',
            position: 'relative',
            opacity: anim(frame, 0, 20),
            background: `radial-gradient(ellipse 120% 120% at 50% ${isStory ? '25%' : '35%'}, ${theme.gradientColors[1]}, ${theme.gradientColors[0]})`,
            border: `1px solid ${accent}14`,
            boxSizing: 'border-box',
          }}
        >
          {/* Starfield */}
          <ParticleField
            count={isStory ? 30 : 20}
            color={accent}
            seed={seed}
            width={W}
            height={H}
          />

          {/* Top glow */}
          <div
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              right: 0,
              height: isStory ? 180 : 100,
              background: `radial-gradient(circle at 50% 0%, ${accent}1A, transparent)`,
            }}
          />

          {/* End glow overlay */}
          {endGlow > 0 && (
            <div
              style={{
                position: 'absolute',
                inset: 0,
                background: accent,
                opacity: endGlow,
                borderRadius: 24,
              }}
            />
          )}

          {/* Content */}
          {isStory ? (
            <StoryContent
              frame={frame}
              fps={fps}
              accent={accent}
              emoji={theme.emoji}
              monthName={monthName}
              year={year}
              totalMinutes={totalMinutes}
              animatedMinutes={animatedMinutes}
              sessions={sessions}
              animatedSessions={animatedSessions}
              booksFinished={booksFinished}
              animatedBooks={animatedBooks}
              longestFlow={longestFlow}
              animatedFlow={animatedFlow}
              topBook={topBook}
              vsLastMonthPercent={vsLastMonthPercent}
              previousMonthName={previousMonthNames[month] || ''}
              emojiSpring={emojiSpring}
            />
          ) : (
            <SquareContent
              frame={frame}
              fps={fps}
              accent={accent}
              emoji={theme.emoji}
              monthName={monthName}
              year={year}
              totalMinutes={totalMinutes}
              animatedMinutes={animatedMinutes}
              sessions={sessions}
              animatedSessions={animatedSessions}
              booksFinished={booksFinished}
              animatedBooks={animatedBooks}
              longestFlow={longestFlow}
              animatedFlow={animatedFlow}
              topBook={topBook}
              emojiSpring={emojiSpring}
            />
          )}
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ══════════════════════════════════════════════════════════════════════
// STORY CONTENT (360 x 640)
// ══════════════════════════════════════════════════════════════════════

interface StoryProps {
  frame: number;
  fps: number;
  accent: string;
  emoji: string;
  monthName: string;
  year: number;
  totalMinutes: number;
  animatedMinutes: number;
  sessions: number;
  animatedSessions: number;
  booksFinished: number;
  animatedBooks: number;
  longestFlow: number;
  animatedFlow: number;
  topBook?: { title: string; author: string; totalMinutes: number };
  vsLastMonthPercent: number;
  previousMonthName: string;
  emojiSpring: number;
}

const StoryContent: React.FC<StoryProps> = ({
  frame,
  fps,
  accent,
  emoji,
  monthName,
  year,
  totalMinutes,
  animatedMinutes,
  sessions,
  animatedSessions,
  booksFinished,
  animatedBooks,
  longestFlow,
  animatedFlow,
  topBook,
  vsLastMonthPercent,
  previousMonthName,
  emojiSpring,
}) => {
  const headerOpacity = anim(frame, 5, 25);
  const monthOpacity = anim(frame, 25, 45);
  const monthScale = anim(frame, 25, 45, [0.8, 1]);
  const yearOpacity = anim(frame, 35, 55);
  const lineWidth = anim(frame, 55, 70, [0, 50]);
  const stat1 = anim(frame, 70, 90);
  const stat2 = anim(frame, 80, 100);
  const stat3 = anim(frame, 90, 110);
  const stat4 = anim(frame, 100, 120);
  const bookOpacity = anim(frame, 140, 165);
  const bookY = anim(frame, 140, 165, [15, 0]);
  const vsOpacity = anim(frame, 180, 205);
  const footerLineWidth = anim(frame, 220, 240, [0, 30]);
  const footerOpacity = anim(frame, 230, 250);

  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        padding: '36px 24px',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      {/* Header */}
      <div
        style={{
          opacity: headerOpacity,
          fontFamily: FONTS.inter,
          fontSize: 9,
          fontWeight: 500,
          letterSpacing: 5,
          color: `${accent}80`,
        }}
      >
        LEXDAY WRAPPED
      </div>
      <div style={{ height: 8 }} />

      {/* Emoji */}
      <div
        style={{
          fontSize: 36,
          transform: `scale(${emojiSpring})`,
        }}
      >
        {emoji}
      </div>
      <div style={{ height: 8 }} />

      {/* Month name */}
      <div
        style={{
          opacity: monthOpacity,
          transform: `scale(${monthScale})`,
          fontFamily: FONTS.poppins,
          fontSize: 40,
          fontWeight: 700,
          color: accent,
          lineHeight: 1,
        }}
      >
        {monthName}
      </div>
      <div
        style={{
          opacity: yearOpacity,
          fontFamily: FONTS.inter,
          fontSize: 14,
          color: 'rgba(255,255,255,0.3)',
        }}
      >
        {year}
      </div>
      <div style={{ height: 16 }} />

      {/* Accent line */}
      <div
        style={{
          width: lineWidth,
          height: 1,
          background: `linear-gradient(to right, transparent, ${accent}80, transparent)`,
        }}
      />
      <div style={{ height: 24 }} />

      {/* Stats 2x2 grid */}
      <div style={{ width: '100%' }}>
        <div style={{ display: 'flex', gap: 10 }}>
          <StatCell emoji="⏱️" value={formatTime(animatedMinutes)} label="LECTURE" accent={accent} opacity={stat1} />
          <StatCell emoji="📚" value={`${animatedBooks}`} label="LIVRES" accent={accent} opacity={stat2} />
        </div>
        <div style={{ height: 10 }} />
        <div style={{ display: 'flex', gap: 10 }}>
          <StatCell emoji="🔥" value={`${animatedFlow}j`} label="FLOW" accent={accent} opacity={stat3} />
          <StatCell emoji="🎯" value={`${animatedSessions}`} label="SESSIONS" accent={accent} opacity={stat4} />
        </div>
      </div>
      <div style={{ height: 16 }} />

      {/* Top book */}
      {topBook && (
        <div
          style={{
            opacity: bookOpacity,
            transform: `translateY(${bookY}px)`,
            width: '100%',
            padding: '14px 16px',
            borderRadius: 14,
            background: `linear-gradient(to right, ${accent}0F, transparent)`,
            border: `1px solid ${accent}14`,
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            boxSizing: 'border-box',
          }}
        >
          <span style={{ fontSize: 26 }}>📖</span>
          <div style={{ flex: 1, overflow: 'hidden' }}>
            <div
              style={{
                fontFamily: FONTS.inter,
                fontSize: 7,
                fontWeight: 500,
                letterSpacing: 2,
                color: 'rgba(255,255,255,0.3)',
              }}
            >
              LIVRE DU MOIS
            </div>
            <div style={{ height: 4 }} />
            <div
              style={{
                fontFamily: FONTS.poppins,
                fontSize: 15,
                fontWeight: 700,
                color: accent,
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
            >
              {topBook.title}
            </div>
            <div
              style={{
                fontFamily: FONTS.inter,
                fontSize: 9,
                color: 'rgba(255,255,255,0.35)',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
            >
              {topBook.author} &bull; {formatTime(topBook.totalMinutes)}
            </div>
          </div>
        </div>
      )}

      {/* VS last month */}
      {vsLastMonthPercent !== 0 && (
        <>
          <div style={{ height: 14 }} />
          <div
            style={{
              opacity: vsOpacity,
              padding: '10px 14px',
              backgroundColor: 'rgba(255,255,255,0.03)',
              borderRadius: 12,
              display: 'flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            <span
              style={{
                fontFamily: FONTS.poppins,
                fontSize: 14,
                fontWeight: 700,
                color: vsLastMonthPercent > 0 ? accent : 'rgba(255,255,255,0.4)',
              }}
            >
              {vsLastMonthPercent > 0 ? '↑' : '↓'} {Math.abs(vsLastMonthPercent)}%
            </span>
            <span
              style={{
                fontFamily: FONTS.inter,
                fontSize: 11,
                color: 'rgba(255,255,255,0.3)',
              }}
            >
              vs {previousMonthName}
            </span>
          </div>
        </>
      )}

      <div style={{ flex: 1 }} />

      {/* Footer */}
      <div
        style={{
          width: footerLineWidth,
          height: 1,
          background: `linear-gradient(to right, transparent, ${accent}80, transparent)`,
        }}
      />
      <div style={{ height: 12 }} />
      <div
        style={{
          opacity: footerOpacity,
          fontFamily: FONTS.inter,
          fontSize: 9,
          fontWeight: 500,
          letterSpacing: 3,
          color: `${accent}40`,
        }}
      >
        LEXDAY
      </div>
    </div>
  );
};

// ══════════════════════════════════════════════════════════════════════
// SQUARE CONTENT (360 x 360)
// ══════════════════════════════════════════════════════════════════════

interface SquareProps {
  frame: number;
  fps: number;
  accent: string;
  emoji: string;
  monthName: string;
  year: number;
  totalMinutes: number;
  animatedMinutes: number;
  sessions: number;
  animatedSessions: number;
  booksFinished: number;
  animatedBooks: number;
  longestFlow: number;
  animatedFlow: number;
  topBook?: { title: string; author: string; totalMinutes: number };
  emojiSpring: number;
}

const SquareContent: React.FC<SquareProps> = ({
  frame,
  fps,
  accent,
  emoji,
  monthName,
  year,
  totalMinutes,
  animatedMinutes,
  sessions,
  animatedSessions,
  booksFinished,
  animatedBooks,
  longestFlow,
  animatedFlow,
  topBook,
  emojiSpring,
}) => {
  const headerOpacity = anim(frame, 5, 25);
  const stat1 = anim(frame, 40, 60);
  const stat2 = anim(frame, 48, 68);
  const stat3 = anim(frame, 56, 76);
  const stat4 = anim(frame, 64, 84);
  const bookOpacity = anim(frame, 100, 125);
  const flowOpacity = anim(frame, 110, 135);
  const footerOpacity = anim(frame, 150, 170);

  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        padding: 24,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {/* Header row */}
      <div
        style={{
          opacity: headerOpacity,
          display: 'flex',
          alignItems: 'flex-start',
        }}
      >
        <div style={{ flex: 1 }}>
          <div
            style={{
              fontFamily: FONTS.inter,
              fontSize: 8,
              fontWeight: 500,
              letterSpacing: 4,
              color: `${accent}66`,
            }}
          >
            WRAPPED
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 24, transform: `scale(${emojiSpring})`, display: 'inline-block' }}>
              {emoji}
            </span>
            <span
              style={{
                fontFamily: FONTS.poppins,
                fontSize: 28,
                fontWeight: 700,
                color: accent,
                lineHeight: 1,
              }}
            >
              {monthName}
            </span>
          </div>
        </div>
        <span
          style={{
            fontFamily: FONTS.inter,
            fontSize: 14,
            color: 'rgba(255,255,255,0.3)',
          }}
        >
          {year}
        </span>
      </div>
      <div style={{ height: 18 }} />

      {/* Horizontal stats row */}
      <div style={{ display: 'flex' }}>
        {[
          { emoji: '⏱️', value: formatTime(animatedMinutes), label: 'LECTURE', o: stat1 },
          { emoji: '📚', value: `${animatedBooks}`, label: 'LIVRES', o: stat2 },
          { emoji: '🔥', value: `${animatedFlow}j`, label: 'FLOW', o: stat3 },
          { emoji: '🎯', value: `${animatedSessions}`, label: 'SESSIONS', o: stat4 },
        ].map((item, i) => (
          <div
            key={i}
            style={{
              flex: 1,
              margin: '0 3px',
              opacity: item.o,
              transform: `translateY(${(1 - item.o) * 8}px)`,
              padding: '10px 0',
              backgroundColor: 'rgba(255,255,255,0.04)',
              border: '1px solid rgba(255,255,255,0.06)',
              borderRadius: 12,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              boxSizing: 'border-box',
            }}
          >
            <span style={{ fontSize: 14 }}>{item.emoji}</span>
            <div style={{ height: 2 }} />
            <span
              style={{
                fontFamily: FONTS.poppins,
                fontSize: 15,
                fontWeight: 700,
                color: accent,
              }}
            >
              {item.value}
            </span>
            <div style={{ height: 2 }} />
            <span
              style={{
                fontFamily: FONTS.inter,
                fontSize: 7,
                fontWeight: 500,
                letterSpacing: 1,
                color: 'rgba(255,255,255,0.25)',
              }}
            >
              {item.label}
            </span>
          </div>
        ))}
      </div>
      <div style={{ height: 14 }} />

      {/* Book + Flow row */}
      <div style={{ display: 'flex', gap: 10, flex: 1 }}>
        {topBook && (
          <div
            style={{
              flex: 3,
              opacity: bookOpacity,
              transform: `translateY(${(1 - bookOpacity) * 10}px)`,
              padding: 14,
              borderRadius: 14,
              background: `linear-gradient(135deg, ${accent}0F, transparent)`,
              border: `1px solid ${accent}14`,
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'center',
              boxSizing: 'border-box',
            }}
          >
            <div
              style={{
                fontFamily: FONTS.inter,
                fontSize: 7,
                fontWeight: 500,
                letterSpacing: 2,
                color: 'rgba(255,255,255,0.3)',
              }}
            >
              LIVRE DU MOIS
            </div>
            <div style={{ height: 6 }} />
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ fontSize: 22 }}>📖</span>
              <div style={{ flex: 1, overflow: 'hidden' }}>
                <div
                  style={{
                    fontFamily: FONTS.poppins,
                    fontSize: 14,
                    fontWeight: 700,
                    color: accent,
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                  }}
                >
                  {topBook.title}
                </div>
                <div
                  style={{
                    fontFamily: FONTS.inter,
                    fontSize: 9,
                    color: 'rgba(255,255,255,0.35)',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                  }}
                >
                  {topBook.author}
                </div>
              </div>
            </div>
          </div>
        )}
        <div
          style={{
            flex: 2,
            opacity: flowOpacity,
            transform: `translateY(${(1 - flowOpacity) * 10}px)`,
            padding: 14,
            backgroundColor: 'rgba(255,255,255,0.03)',
            borderRadius: 14,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            boxSizing: 'border-box',
          }}
        >
          <span
            style={{
              fontFamily: FONTS.poppins,
              fontSize: 28,
              fontWeight: 700,
              color: accent,
            }}
          >
            {animatedFlow}j
          </span>
          <div style={{ height: 4 }} />
          <div
            style={{
              fontFamily: FONTS.inter,
              fontSize: 8,
              fontWeight: 500,
              letterSpacing: 1,
              color: 'rgba(255,255,255,0.3)',
              textAlign: 'center',
              lineHeight: 1.3,
            }}
          >
            MEILLEUR{'\n'}FLOW
          </div>
        </div>
      </div>
      <div style={{ height: 14 }} />

      {/* Footer */}
      <div
        style={{
          opacity: footerOpacity,
          paddingTop: 10,
          borderTop: '1px solid rgba(255,255,255,0.05)',
          textAlign: 'center',
          fontFamily: FONTS.inter,
          fontSize: 8,
          fontWeight: 500,
          letterSpacing: 4,
          color: `${accent}40`,
        }}
      >
        LEXDAY &mdash; STRAVA FOR BOOKS
      </div>
    </div>
  );
};

// ══════════════════════════════════════════════════════════════════════
// StatCell (2x2 grid for story)
// ══════════════════════════════════════════════════════════════════════

const StatCell: React.FC<{
  emoji: string;
  value: string;
  label: string;
  accent: string;
  opacity: number;
}> = ({ emoji, value, label, accent, opacity }) => (
  <div
    style={{
      flex: 1,
      opacity,
      transform: `translateY(${(1 - opacity) * 10}px)`,
      padding: '12px 10px',
      backgroundColor: 'rgba(255,255,255,0.04)',
      border: '1px solid rgba(255,255,255,0.06)',
      borderRadius: 14,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      boxSizing: 'border-box',
    }}
  >
    <span style={{ fontSize: 18 }}>{emoji}</span>
    <div style={{ height: 4 }} />
    <span
      style={{
        fontFamily: FONTS.poppins,
        fontSize: 20,
        fontWeight: 700,
        color: accent,
      }}
    >
      {value}
    </span>
    <div style={{ height: 2 }} />
    <span
      style={{
        fontFamily: FONTS.inter,
        fontSize: 8,
        fontWeight: 500,
        letterSpacing: 1,
        color: 'rgba(255,255,255,0.3)',
      }}
    >
      {label}
    </span>
  </div>
);
