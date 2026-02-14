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
import { YearlyWrappedInput } from '../../shared/types';
import { YearlyColors } from '../../shared/colors';
import { ParticleField } from '../../shared/animations/particle-field';
import { loadFonts, FONTS } from '../../shared/fonts';

// ──────────────────────────────────────────────────────────────────────
// YearlyWrapped – Single animated card reproducing the Flutter
// WrappedShareCard (yearly) with gold/dark theme and progressive
// element reveal.
//
// 450 frames (15s @ 30fps). Animation timeline:
//   0-20:   Card fades in
//   5-25:   "LEXDAY WRAPPED" header fades in
//  15-55:   Year number reveals with gold gradient
//  55-70:   Gold line grows
//  70-90:   Name fades up
//  85-110:  Reader badge slides in (spring)
// 115-180:  Stats 2x2 grid (staggered)
// 185-215:  Top book card
// 220-250:  Footer
// 250-420:  Hold
// 420-450:  Glow pulse
// ──────────────────────────────────────────────────────────────────────

const GOLD = YearlyColors.gold;
const CREAM = YearlyColors.cream;
const WINE = YearlyColors.bordeaux;
const DEEP = YearlyColors.deepBg;
const GLOW = YearlyColors.glowCenter;

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

function formatNumber(n: number): string {
  if (n < 1000) return `${n}`;
  const k = Math.floor(n / 1000);
  const r = Math.floor((n % 1000) / 100);
  if (r === 0) return `${k}k`;
  return `${k}\u202F${String(n % 1000).padStart(3, '0')}`;
}

function shortBadge(badge: string): string {
  const words = badge.split(' ');
  if (words.length > 2) return words.slice(0, 2).join(' ');
  return badge;
}

export const YearlyWrapped: React.FC<YearlyWrappedInput> = (props) => {
  const {
    format,
    year,
    userName,
    totalMinutes,
    totalSessions,
    booksFinished,
    readerType,
    readerEmoji,
    bestFlow,
    percentileRank,
    topBooks,
  } = props;
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const [fontHandle] = useState(() => delayRender('Loading fonts'));
  useEffect(() => {
    loadFonts().then(() => continueRender(fontHandle));
  }, [fontHandle]);

  const name = userName || 'Lecteur';
  const isStory = format === 'story';
  const SCALE = 3;
  const W = 360;
  const H = isStory ? 640 : 360;
  const seed = name.split('').reduce((a, c) => a + c.charCodeAt(0), 0);
  const topBook = topBooks.length > 0 ? topBooks[0] : null;
  const totalHours = Math.floor(totalMinutes / 60);

  // Badge spring
  const badgeSpring = spring({
    frame: frame - 85,
    fps,
    config: { damping: 12, stiffness: 180 },
  });

  // Animated counters
  const counterProgress = anim(frame, 120, 175);
  const animatedHours = Math.round(totalHours * counterProgress);
  const animatedBooks = Math.round(booksFinished * counterProgress);
  const animatedFlow = Math.round(bestFlow * counterProgress);
  const animatedSessions = Math.round(totalSessions * counterProgress);

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
            background: `radial-gradient(ellipse 120% 120% at 50% ${isStory ? '20%' : '30%'}, ${GLOW}, ${DEEP})`,
            border: `1px solid ${GOLD}0F`,
            boxSizing: 'border-box',
          }}
        >
          {/* Gold starfield */}
          <ParticleField
            count={isStory ? 40 : 25}
            color={GOLD}
            seed={seed}
            width={W}
            height={H}
          />

          {/* Wine glow at top */}
          <div
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              right: 0,
              height: isStory ? 200 : 120,
              background: `radial-gradient(circle at 50% 0%, ${WINE}${isStory ? '26' : '1F'}, transparent)`,
            }}
          />

          {/* End glow overlay */}
          {endGlow > 0 && (
            <div
              style={{
                position: 'absolute',
                inset: 0,
                background: GOLD,
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
              year={year}
              name={name}
              readerEmoji={readerEmoji}
              readerType={readerType}
              totalHours={totalHours}
              animatedHours={animatedHours}
              booksFinished={booksFinished}
              animatedBooks={animatedBooks}
              bestFlow={bestFlow}
              animatedFlow={animatedFlow}
              percentileRank={percentileRank}
              topBook={topBook}
              badgeSpring={badgeSpring}
              counterProgress={counterProgress}
            />
          ) : (
            <SquareContent
              frame={frame}
              fps={fps}
              year={year}
              name={name}
              readerEmoji={readerEmoji}
              readerType={readerType}
              totalHours={totalHours}
              animatedHours={animatedHours}
              booksFinished={booksFinished}
              animatedBooks={animatedBooks}
              bestFlow={bestFlow}
              animatedFlow={animatedFlow}
              percentileRank={percentileRank}
              totalSessions={totalSessions}
              animatedSessions={animatedSessions}
              topBook={topBook}
              counterProgress={counterProgress}
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
  year: number;
  name: string;
  readerEmoji: string;
  readerType: string;
  totalHours: number;
  animatedHours: number;
  booksFinished: number;
  animatedBooks: number;
  bestFlow: number;
  animatedFlow: number;
  percentileRank: number;
  topBook: { title: string; author: string } | null;
  badgeSpring: number;
  counterProgress: number;
}

const StoryContent: React.FC<StoryProps> = ({
  frame,
  fps,
  year,
  name,
  readerEmoji,
  readerType,
  totalHours,
  animatedHours,
  booksFinished,
  animatedBooks,
  bestFlow,
  animatedFlow,
  percentileRank,
  topBook,
  badgeSpring,
  counterProgress,
}) => {
  const headerOpacity = anim(frame, 5, 25);
  const yearOpacity = anim(frame, 15, 45);
  const yearScale = anim(frame, 15, 45, [0.85, 1]);
  const lineWidth = anim(frame, 55, 70, [0, 60]);
  const nameOpacity = anim(frame, 70, 90);
  const nameY = anim(frame, 70, 90, [10, 0]);
  const stat1 = anim(frame, 115, 140);
  const stat2 = anim(frame, 125, 150);
  const stat3 = anim(frame, 135, 160);
  const stat4 = anim(frame, 145, 170);
  const bookOpacity = anim(frame, 185, 210);
  const bookY = anim(frame, 185, 210, [12, 0]);
  const footerLineWidth = anim(frame, 220, 240, [0, 30]);
  const footerOpacity = anim(frame, 230, 250);

  // Animated percentile
  const animatedRank = Math.round(percentileRank * counterProgress);

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
          fontFamily: FONTS.jetBrainsMono,
          fontSize: 9,
          letterSpacing: 5,
          color: `${GOLD}66`,
        }}
      >
        LEXDAY WRAPPED
      </div>
      <div style={{ height: 10 }} />

      {/* Year - gold gradient text */}
      <div
        style={{
          opacity: yearOpacity,
          transform: `scale(${yearScale})`,
          fontFamily: FONTS.libreBaskerville,
          fontSize: 56,
          fontWeight: 700,
          lineHeight: 0.9,
          background: `linear-gradient(to bottom, ${CREAM}, ${GOLD})`,
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
          backgroundClip: 'text',
        }}
      >
        {year}
      </div>
      <div style={{ height: 16 }} />

      {/* Gold line */}
      <div
        style={{
          width: lineWidth,
          height: 1,
          background: `linear-gradient(to right, transparent, ${GOLD}80, transparent)`,
        }}
      />
      <div style={{ height: 20 }} />

      {/* Name */}
      <div
        style={{
          opacity: nameOpacity,
          transform: `translateY(${nameY}px)`,
          fontFamily: FONTS.libreBaskerville,
          fontSize: 22,
          fontWeight: 700,
          color: '#FFFFFF',
        }}
      >
        {name}
      </div>
      <div style={{ height: 10 }} />

      {/* Reader badge */}
      <div
        style={{
          opacity: Math.min(badgeSpring, 1),
          transform: `scale(${badgeSpring})`,
          padding: '8px 16px',
          borderRadius: 50,
          background: `linear-gradient(to right, ${WINE}38, ${GOLD}1A)`,
          border: `1px solid ${GOLD}1F`,
          display: 'flex',
          alignItems: 'center',
          gap: 8,
        }}
      >
        <span style={{ fontSize: 16 }}>{readerEmoji}</span>
        <span
          style={{
            fontFamily: FONTS.jetBrainsMono,
            fontSize: 11,
            color: GOLD,
          }}
        >
          {readerType}
        </span>
      </div>
      <div style={{ height: 22 }} />

      {/* Stats 2x2 */}
      <div style={{ width: '100%' }}>
        <div style={{ display: 'flex', gap: 10 }}>
          <GoldStatCell emoji="⏱️" value={`${animatedHours}h`} label="LECTURE" opacity={stat1} />
          <GoldStatCell emoji="📚" value={`${animatedBooks}`} label="LIVRES" opacity={stat2} />
        </div>
        <div style={{ height: 10 }} />
        <div style={{ display: 'flex', gap: 10 }}>
          <GoldStatCell emoji="🔥" value={`${animatedFlow}j`} label="FLOW" opacity={stat3} />
          <GoldStatCell emoji="🏆" value={`Top ${animatedRank}%`} label="CLASSEMENT" opacity={stat4} />
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
            background: `linear-gradient(to right, ${GOLD}0D, transparent)`,
            border: `1px solid ${GOLD}12`,
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            boxSizing: 'border-box',
          }}
        >
          <span style={{ fontSize: 28 }}>📖</span>
          <div style={{ flex: 1, overflow: 'hidden' }}>
            <div
              style={{
                fontFamily: FONTS.jetBrainsMono,
                fontSize: 7,
                letterSpacing: 2,
                color: 'rgba(255,255,255,0.3)',
              }}
            >
              LIVRE DE L&apos;ANNEE
            </div>
            <div style={{ height: 4 }} />
            <div
              style={{
                fontFamily: FONTS.libreBaskerville,
                fontSize: 16,
                fontWeight: 700,
                color: GOLD,
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
            >
              {topBook.title}
            </div>
            <div
              style={{
                fontFamily: FONTS.jetBrainsMono,
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
      )}

      <div style={{ flex: 1 }} />

      {/* Footer */}
      <div
        style={{
          width: footerLineWidth,
          height: 1,
          background: `linear-gradient(to right, transparent, ${GOLD}80, transparent)`,
        }}
      />
      <div style={{ height: 14 }} />
      <div
        style={{
          opacity: footerOpacity,
          fontFamily: FONTS.jetBrainsMono,
          fontSize: 9,
          letterSpacing: 3,
          color: `${GOLD}40`,
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
  year: number;
  name: string;
  readerEmoji: string;
  readerType: string;
  totalHours: number;
  animatedHours: number;
  booksFinished: number;
  animatedBooks: number;
  bestFlow: number;
  animatedFlow: number;
  percentileRank: number;
  totalSessions: number;
  animatedSessions: number;
  topBook: { title: string; author: string } | null;
  counterProgress: number;
}

const SquareContent: React.FC<SquareProps> = ({
  frame,
  fps,
  year,
  name,
  readerEmoji,
  readerType,
  totalHours,
  animatedHours,
  booksFinished,
  animatedBooks,
  bestFlow,
  animatedFlow,
  percentileRank,
  totalSessions,
  animatedSessions,
  topBook,
  counterProgress,
}) => {
  const headerOpacity = anim(frame, 5, 25);
  const stat1 = anim(frame, 50, 70);
  const stat2 = anim(frame, 58, 78);
  const stat3 = anim(frame, 66, 86);
  const stat4 = anim(frame, 74, 94);
  const bookOpacity = anim(frame, 110, 135);
  const sessionsOpacity = anim(frame, 120, 145);
  const footerOpacity = anim(frame, 160, 180);

  const animatedRank = Math.round(percentileRank * counterProgress);

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
              fontFamily: FONTS.jetBrainsMono,
              fontSize: 8,
              letterSpacing: 4,
              color: `${GOLD}59`,
            }}
          >
            WRAPPED
          </div>
          <div
            style={{
              fontFamily: FONTS.libreBaskerville,
              fontSize: 40,
              fontWeight: 700,
              lineHeight: 1,
              background: `linear-gradient(to bottom, ${CREAM}, ${GOLD})`,
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              backgroundClip: 'text',
            }}
          >
            {year}
          </div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div
            style={{
              fontFamily: FONTS.libreBaskerville,
              fontSize: 18,
              fontWeight: 700,
              color: '#FFFFFF',
            }}
          >
            {name}
          </div>
          <div style={{ height: 4 }} />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 4 }}>
            <span style={{ fontSize: 12 }}>{readerEmoji}</span>
            <span
              style={{
                fontFamily: FONTS.jetBrainsMono,
                fontSize: 9,
                color: `${GOLD}80`,
              }}
            >
              {shortBadge(readerType)}
            </span>
          </div>
        </div>
      </div>
      <div style={{ height: 18 }} />

      {/* Horizontal stats */}
      <div style={{ display: 'flex' }}>
        {[
          { emoji: '⏱️', value: `${animatedHours}h`, label: 'LECTURE', o: stat1 },
          { emoji: '📚', value: `${animatedBooks}`, label: 'LIVRES', o: stat2 },
          { emoji: '🔥', value: `${animatedFlow}j`, label: 'FLOW', o: stat3 },
          { emoji: '🏆', value: `Top ${animatedRank}%`, label: 'TOP', o: stat4 },
        ].map((item, i) => (
          <div
            key={i}
            style={{
              flex: 1,
              margin: '0 4px',
              opacity: item.o,
              transform: `translateY(${(1 - item.o) * 8}px)`,
              padding: '10px 0',
              backgroundColor: 'rgba(255,255,255,0.03)',
              border: '1px solid rgba(255,255,255,0.05)',
              borderRadius: 12,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              boxSizing: 'border-box',
            }}
          >
            <span style={{ fontSize: 16 }}>{item.emoji}</span>
            <div style={{ height: 4 }} />
            <span
              style={{
                fontFamily: FONTS.libreBaskerville,
                fontSize: 16,
                fontWeight: 700,
                color: GOLD,
              }}
            >
              {item.value}
            </span>
            <div style={{ height: 2 }} />
            <span
              style={{
                fontFamily: FONTS.jetBrainsMono,
                fontSize: 7,
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

      {/* Book + Sessions row */}
      <div style={{ display: 'flex', gap: 10, flex: 1 }}>
        {topBook && (
          <div
            style={{
              flex: 3,
              opacity: bookOpacity,
              transform: `translateY(${(1 - bookOpacity) * 10}px)`,
              padding: 14,
              borderRadius: 14,
              background: `linear-gradient(135deg, ${GOLD}0D, transparent)`,
              border: `1px solid ${GOLD}12`,
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'center',
              boxSizing: 'border-box',
            }}
          >
            <div
              style={{
                fontFamily: FONTS.jetBrainsMono,
                fontSize: 7,
                letterSpacing: 2,
                color: 'rgba(255,255,255,0.3)',
              }}
            >
              LIVRE DE L&apos;ANNEE
            </div>
            <div style={{ height: 8 }} />
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ fontSize: 24 }}>📖</span>
              <div style={{ flex: 1, overflow: 'hidden' }}>
                <div
                  style={{
                    fontFamily: FONTS.libreBaskerville,
                    fontSize: 15,
                    fontWeight: 700,
                    color: GOLD,
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                  }}
                >
                  {topBook.title}
                </div>
                <div
                  style={{
                    fontFamily: FONTS.jetBrainsMono,
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
            opacity: sessionsOpacity,
            transform: `translateY(${(1 - sessionsOpacity) * 10}px)`,
            padding: 14,
            backgroundColor: 'rgba(255,255,255,0.02)',
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
              fontFamily: FONTS.libreBaskerville,
              fontSize: 28,
              fontWeight: 700,
              color: '#FFFFFF',
            }}
          >
            {formatNumber(animatedSessions)}
          </span>
          <div style={{ height: 4 }} />
          <span
            style={{
              fontFamily: FONTS.jetBrainsMono,
              fontSize: 8,
              letterSpacing: 1,
              color: 'rgba(255,255,255,0.3)',
            }}
          >
            SESSIONS
          </span>
        </div>
      </div>
      <div style={{ height: 14 }} />

      {/* Footer */}
      <div
        style={{
          opacity: footerOpacity,
          paddingTop: 12,
          borderTop: '1px solid rgba(255,255,255,0.05)',
          textAlign: 'center',
          fontFamily: FONTS.jetBrainsMono,
          fontSize: 8,
          letterSpacing: 4,
          color: `${GOLD}38`,
        }}
      >
        LEXDAY &mdash; STRAVA FOR BOOKS
      </div>
    </div>
  );
};

// ══════════════════════════════════════════════════════════════════════
// GoldStatCell (2x2 grid for story) – gold gradient values
// ══════════════════════════════════════════════════════════════════════

const GoldStatCell: React.FC<{
  emoji: string;
  value: string;
  label: string;
  opacity: number;
}> = ({ emoji, value, label, opacity }) => (
  <div
    style={{
      flex: 1,
      opacity,
      transform: `translateY(${(1 - opacity) * 10}px)`,
      padding: '14px 10px',
      backgroundColor: 'rgba(255,255,255,0.03)',
      border: '1px solid rgba(255,255,255,0.05)',
      borderRadius: 14,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      boxSizing: 'border-box',
    }}
  >
    <span style={{ fontSize: 20 }}>{emoji}</span>
    <div style={{ height: 6 }} />
    <span
      style={{
        fontFamily: FONTS.libreBaskerville,
        fontSize: 20,
        fontWeight: 700,
        background: `linear-gradient(to bottom, ${CREAM}, ${GOLD})`,
        WebkitBackgroundClip: 'text',
        WebkitTextFillColor: 'transparent',
        backgroundClip: 'text',
      }}
    >
      {value}
    </span>
    <div style={{ height: 4 }} />
    <span
      style={{
        fontFamily: FONTS.jetBrainsMono,
        fontSize: 8,
        letterSpacing: 1,
        color: 'rgba(255,255,255,0.3)',
      }}
    >
      {label}
    </span>
  </div>
);
