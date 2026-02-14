import React, { useEffect, useMemo } from 'react';
import {
  AbsoluteFill,
  Audio,
  useCurrentFrame,
  interpolate,
  Easing,
  spring,
  useVideoConfig,
  staticFile,
} from 'remotion';
import { ReadingSessionInput } from '../../shared/types';
import { SessionColors } from '../../shared/colors';
import { ParticleField } from '../../shared/animations/particle-field';
import { loadFonts, FONTS } from '../../shared/fonts';
import { delayRender, continueRender } from 'remotion';

// ──────────────────────────────────────────────────────────────────────
// ReadingSession – Single animated card that reproduces the Flutter
// SessionShareCard exactly, with progressive element reveal.
//
// 450 frames (15s @ 30fps). Animation timeline:
//   0-20:   Card container fades in (border, gradient, particles)
//  10-30:   "SESSION DE LECTURE" header fades in
//  20-40:   📚 emoji bounces in (spring)
//  30-50:   Accent line grows from center
//  40-70:   Book title fades up
//  50-80:   Author fades in
//  70-130:  Stats grid reveals (staggered counters)
// 130-180:  Progression bar slides in + fills
// 180-210:  Footer fades in
// 210-420:  Hold (everything visible – identical to Flutter card)
// 420-450:  Gentle glow pulse on whole card
// ──────────────────────────────────────────────────────────────────────

const ACCENT = SessionColors.accent;
const DARK = SessionColors.dark;

function formatDuration(minutes: number): string {
  if (minutes < 60) return `${minutes} min`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${h}h${m > 0 ? ` ${m}min` : ''}`;
}

function formatPace(pagesRead: number, durationMinutes: number): string {
  if (pagesRead === 0 || durationMinutes === 0) return '-';
  const ppm = pagesRead / durationMinutes;
  if (ppm >= 1) return `${ppm.toFixed(1)} p/min`;
  const mpp = durationMinutes / pagesRead;
  return `${mpp.toFixed(1)} min/p`;
}

// Animated interpolation helper
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

export const ReadingSession: React.FC<ReadingSessionInput> = (props) => {
  const {
    format,
    bookTitle,
    bookAuthor,
    pagesRead,
    durationMinutes,
    startPage,
    endPage,
  } = props;
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Load fonts
  const [handle] = React.useState(() => delayRender());
  useEffect(() => {
    loadFonts().then(() => continueRender(handle));
  }, [handle]);

  const isStory = format === 'story';
  const SCALE = 3;
  const W = 360;
  const H = isStory ? 640 : 360;
  const seed = bookTitle.split('').reduce((a, c) => a + c.charCodeAt(0), 0);

  // Spring for emoji bounce
  const emojiSpring = spring({ frame: frame - 20, fps, config: { damping: 12, stiffness: 200 } });

  // Animated counters
  const counterProgress = anim(frame, 80, 130);
  const animatedPages = Math.round(pagesRead * counterProgress);
  const animatedDuration = Math.round(durationMinutes * counterProgress);

  // Progress bar fill
  const barFill = anim(frame, 140, 175);

  // Glow pulse at end
  const endGlow = frame > 420
    ? 0.06 + Math.sin((frame - 420) * 0.15) * 0.04
    : 0;

  // Audio volume: fade-in 0→0.3 over first 30 frames, fade-out 0.3→0 over last 30 frames
  const musicVolume = (f: number) => {
    const fadeIn = interpolate(f, [0, 30], [0, 0.3], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
    const fadeOut = interpolate(f, [420, 450], [0.3, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
    return Math.min(fadeIn, fadeOut);
  };

  return (
    <AbsoluteFill style={{ backgroundColor: '#000' }}>
      <Audio src={staticFile('audio/wrapped_melody.wav')} volume={musicVolume} />
      {/* Scaled content container */}
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
        {/* ── Card container ─────────────────────────── */}
        <div
          style={{
            width: W,
            height: H,
            borderRadius: 24,
            overflow: 'hidden',
            position: 'relative',
            opacity: anim(frame, 0, 20),
            // Radial gradient matching Flutter: center(0, -0.6), radius 1.2
            background: `radial-gradient(ellipse 120% 120% at 50% 20%, #0F2A22, ${DARK})`,
            border: `1px solid ${ACCENT}0F`,
            boxSizing: 'border-box',
          }}
        >
          {/* Dots/particles background */}
          <ParticleField
            count={35}
            color={ACCENT}
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
              height: 200,
              background: `radial-gradient(circle at 50% 0%, ${ACCENT}1F, transparent)`,
            }}
          />

          {/* End glow pulse overlay */}
          {endGlow > 0 && (
            <div
              style={{
                position: 'absolute',
                inset: 0,
                background: ACCENT,
                opacity: endGlow,
                borderRadius: 24,
              }}
            />
          )}

          {/* ── Content column (matches Flutter padding) ── */}
          {isStory ? (
            <StoryContent
              frame={frame}
              bookTitle={bookTitle}
              bookAuthor={bookAuthor}
              pagesRead={pagesRead}
              animatedPages={animatedPages}
              durationMinutes={durationMinutes}
              animatedDuration={animatedDuration}
              startPage={startPage}
              endPage={endPage}
              emojiSpring={emojiSpring}
              counterProgress={counterProgress}
              barFill={barFill}
            />
          ) : (
            <SquareContent
              frame={frame}
              bookTitle={bookTitle}
              bookAuthor={bookAuthor}
              pagesRead={pagesRead}
              animatedPages={animatedPages}
              durationMinutes={durationMinutes}
              animatedDuration={animatedDuration}
              startPage={startPage}
              endPage={endPage}
              emojiSpring={emojiSpring}
              counterProgress={counterProgress}
            />
          )}
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ══════════════════════════════════════════════════════════════════════
// STORY CARD CONTENT (360 x 640)
// Reproduces Flutter _StoryCard layout exactly
// ══════════════════════════════════════════════════════════════════════

interface ContentProps {
  frame: number;
  bookTitle: string;
  bookAuthor?: string;
  pagesRead: number;
  animatedPages: number;
  durationMinutes: number;
  animatedDuration: number;
  startPage: number;
  endPage: number;
  emojiSpring: number;
  counterProgress: number;
  barFill?: number;
}

const StoryContent: React.FC<ContentProps> = ({
  frame,
  bookTitle,
  bookAuthor,
  pagesRead,
  animatedPages,
  durationMinutes,
  animatedDuration,
  startPage,
  endPage,
  emojiSpring,
  counterProgress,
  barFill = 0,
}) => {
  // Stagger animations
  const headerOpacity = anim(frame, 10, 30);
  const lineWidth = anim(frame, 30, 50, [0, 60]);
  const titleOpacity = anim(frame, 40, 60);
  const titleY = anim(frame, 40, 60, [15, 0]);
  const authorOpacity = anim(frame, 50, 70);
  const stat1 = anim(frame, 75, 95);
  const stat2 = anim(frame, 80, 100);
  const stat3 = anim(frame, 85, 105);
  const stat4 = anim(frame, 90, 110);
  const dividerOpacity = anim(frame, 75, 95);
  const progressOpacity = anim(frame, 130, 150);
  const footerLineWidth = anim(frame, 180, 200, [0, 30]);
  const footerOpacity = anim(frame, 190, 210);

  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        padding: '28px 24px',
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
          color: `${ACCENT}80`,
        }}
      >
        SESSION DE LECTURE
      </div>
      <div style={{ height: 14 }} />

      {/* Book emoji */}
      <div
        style={{
          fontSize: 32,
          transform: `scale(${emojiSpring})`,
        }}
      >
        📚
      </div>
      <div style={{ height: 10 }} />

      {/* Accent line */}
      <div
        style={{
          width: lineWidth,
          height: 1,
          background: `linear-gradient(to right, transparent, ${ACCENT}80, transparent)`,
        }}
      />
      <div style={{ height: 14 }} />

      {/* Book title */}
      <div
        style={{
          opacity: titleOpacity,
          transform: `translateY(${titleY}px)`,
          fontFamily: FONTS.libreBaskerville,
          fontSize: 20,
          fontWeight: 700,
          color: '#FFFFFF',
          textAlign: 'center',
          maxWidth: 310,
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          display: '-webkit-box',
          WebkitLineClamp: 2,
          WebkitBoxOrient: 'vertical',
          lineHeight: 1.3,
        }}
      >
        {bookTitle}
      </div>
      {bookAuthor && (
        <>
          <div style={{ height: 6 }} />
          <div
            style={{
              opacity: authorOpacity,
              fontFamily: FONTS.libreBaskerville,
              fontSize: 12,
              fontStyle: 'italic',
              color: 'rgba(255,255,255,0.5)',
              textAlign: 'center',
            }}
          >
            {bookAuthor}
          </div>
        </>
      )}
      <div style={{ height: 20 }} />

      {/* ── Stats 2x2 grid ── */}
      <div style={{ display: 'flex', width: '100%' }}>
        {/* Left column */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
          <StatItem emoji="📖" value={`${animatedPages}`} label="pages" opacity={stat1} />
          <StatItem emoji="⚡" value={formatPace(pagesRead, durationMinutes)} label="rythme" opacity={stat3} />
        </div>
        {/* Vertical divider */}
        <div
          style={{
            width: 1,
            height: 80,
            backgroundColor: `${ACCENT}14`,
            opacity: dividerOpacity,
            alignSelf: 'center',
          }}
        />
        {/* Right column */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
          <StatItem emoji="⏱️" value={formatDuration(animatedDuration)} label="de lecture" opacity={stat2} />
          <StatItem emoji="📌" value={`p.${startPage}→${endPage}`} label="progression" opacity={stat4} />
        </div>
      </div>
      <div style={{ height: 16 }} />

      {/* ── Progression bar ── */}
      <div
        style={{
          opacity: progressOpacity,
          width: '100%',
          padding: '10px 16px',
          backgroundColor: 'rgba(255,255,255,0.04)',
          borderRadius: 14,
          border: `1px solid ${ACCENT}14`,
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          boxSizing: 'border-box',
        }}
      >
        <span
          style={{
            fontFamily: FONTS.jetBrainsMono,
            fontSize: 12,
            color: 'rgba(255,255,255,0.5)',
            whiteSpace: 'nowrap',
          }}
        >
          Page {startPage}
        </span>
        <div style={{ flex: 1, position: 'relative' }}>
          {/* Track */}
          <div
            style={{
              height: 3,
              borderRadius: 2,
              backgroundColor: 'rgba(255,255,255,0.08)',
            }}
          />
          {/* Fill */}
          <div
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: `${barFill * 100}%`,
              height: 3,
              borderRadius: 2,
              background: `linear-gradient(to right, ${ACCENT}4D, ${ACCENT})`,
            }}
          />
        </div>
        <span
          style={{
            fontFamily: FONTS.jetBrainsMono,
            fontSize: 12,
            fontWeight: 600,
            color: '#FFFFFF',
            whiteSpace: 'nowrap',
            opacity: anim(barFill, 0.5, 1),
          }}
        >
          Page {endPage}
        </span>
      </div>

      {/* Spacer */}
      <div style={{ flex: 1 }} />

      {/* ── Footer ── */}
      <div
        style={{
          width: footerLineWidth,
          height: 1,
          background: `linear-gradient(to right, transparent, ${ACCENT}80, transparent)`,
        }}
      />
      <div style={{ height: 10 }} />
      <div
        style={{
          opacity: footerOpacity,
          fontFamily: FONTS.jetBrainsMono,
          fontSize: 9,
          letterSpacing: 3,
          color: `${ACCENT}40`,
        }}
      >
        LEXDAY
      </div>
    </div>
  );
};

// ══════════════════════════════════════════════════════════════════════
// SQUARE CARD CONTENT (360 x 360)
// Reproduces Flutter _SquareCard layout exactly
// ══════════════════════════════════════════════════════════════════════

const SquareContent: React.FC<ContentProps> = ({
  frame,
  bookTitle,
  bookAuthor,
  pagesRead,
  animatedPages,
  durationMinutes,
  animatedDuration,
  startPage,
  endPage,
  emojiSpring,
  counterProgress,
}) => {
  const headerOpacity = anim(frame, 10, 30);
  const lineWidth = anim(frame, 40, 60, [0, 40]);
  const stat1 = anim(frame, 65, 85);
  const stat2 = anim(frame, 70, 90);
  const stat3 = anim(frame, 75, 95);
  const stat4 = anim(frame, 80, 100);
  const footerOpacity = anim(frame, 140, 160);

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
      {/* Header row: emoji + title */}
      <div
        style={{
          opacity: headerOpacity,
          display: 'flex',
          alignItems: 'flex-start',
          gap: 12,
        }}
      >
        <div style={{ fontSize: 28, transform: `scale(${emojiSpring})` }}>📚</div>
        <div style={{ flex: 1 }}>
          <div
            style={{
              fontFamily: FONTS.libreBaskerville,
              fontSize: 16,
              fontWeight: 700,
              color: '#FFFFFF',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              display: '-webkit-box',
              WebkitLineClamp: 2,
              WebkitBoxOrient: 'vertical',
              lineHeight: 1.3,
            }}
          >
            {bookTitle}
          </div>
          {bookAuthor && (
            <div
              style={{
                marginTop: 4,
                fontFamily: FONTS.libreBaskerville,
                fontSize: 11,
                fontStyle: 'italic',
                color: 'rgba(255,255,255,0.5)',
              }}
            >
              {bookAuthor}
            </div>
          )}
        </div>
      </div>
      <div style={{ height: 16 }} />

      {/* Accent line */}
      <div
        style={{
          width: lineWidth,
          height: 1,
          margin: '0 auto',
          background: `linear-gradient(to right, transparent, ${ACCENT}80, transparent)`,
        }}
      />
      <div style={{ height: 16 }} />

      {/* Horizontal stats row */}
      <div style={{ display: 'flex' }}>
        {[
          { emoji: '📖', value: `${animatedPages}`, label: 'pages', o: stat1 },
          { emoji: '⏱️', value: formatDuration(animatedDuration), label: 'duree', o: stat2 },
          { emoji: '⚡', value: formatPace(pagesRead, durationMinutes), label: 'rythme', o: stat3 },
          { emoji: '📌', value: `${startPage}→${endPage}`, label: 'pages', o: stat4 },
        ].map((item, i) => (
          <div
            key={i}
            style={{
              flex: 1,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 2,
              opacity: item.o,
              transform: `translateY(${(1 - item.o) * 10}px)`,
            }}
          >
            <span style={{ fontSize: 16 }}>{item.emoji}</span>
            <div style={{ height: 4 }} />
            <span
              style={{
                fontFamily: FONTS.jetBrainsMono,
                fontSize: 13,
                fontWeight: 700,
                color: '#FFFFFF',
                textAlign: 'center',
              }}
            >
              {item.value}
            </span>
            <span
              style={{
                fontFamily: FONTS.jetBrainsMono,
                fontSize: 8,
                color: 'rgba(255,255,255,0.3)',
              }}
            >
              {item.label}
            </span>
          </div>
        ))}
      </div>

      <div style={{ flex: 1 }} />

      {/* Footer */}
      <div
        style={{
          opacity: footerOpacity,
          textAlign: 'center',
          fontFamily: FONTS.jetBrainsMono,
          fontSize: 8,
          letterSpacing: 3,
          color: `${ACCENT}40`,
        }}
      >
        LEXDAY
      </div>
    </div>
  );
};

// ══════════════════════════════════════════════════════════════════════
// Stat item (used in story 2x2 grid)
// ══════════════════════════════════════════════════════════════════════

const StatItem: React.FC<{
  emoji: string;
  value: string;
  label: string;
  opacity: number;
}> = ({ emoji, value, label, opacity }) => (
  <div
    style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      opacity,
      transform: `translateY(${(1 - opacity) * 12}px)`,
    }}
  >
    <span style={{ fontSize: 16 }}>{emoji}</span>
    <div style={{ height: 3 }} />
    <span
      style={{
        fontFamily: FONTS.jetBrainsMono,
        fontSize: 14,
        fontWeight: 700,
        color: '#FFFFFF',
        textAlign: 'center',
      }}
    >
      {value}
    </span>
    <div style={{ height: 2 }} />
    <span
      style={{
        fontFamily: FONTS.jetBrainsMono,
        fontSize: 9,
        color: 'rgba(255,255,255,0.35)',
      }}
    >
      {label}
    </span>
  </div>
);
