import React, { useEffect, useState } from 'react';
import {
  AbsoluteFill,
  Audio,
  useCurrentFrame,
  interpolate,
  useVideoConfig,
  staticFile,
  delayRender,
  continueRender,
} from 'remotion';
import { BookFinishedInput } from '../../shared/types';
import { loadFonts } from '../../shared/fonts';
import { Background } from './Background';
import { Pattern } from './Pattern';
import { BookCover } from './BookCover';
import { BookInfo } from './BookInfo';
import { Stats } from './Stats';
import { HeaderBranding, FooterBranding } from './Branding';

// ──────────────────────────────────────────────────────────────────────
// BookFinished – 6 seconds (180 frames @ 30fps)
// Spotify Wrapped / Strava style – dynamic colors from book cover
//
// Timeline:
//   0-15:   Background + pattern fade-in
//   5-20:   Header branding "LexDay" appears
//  15-50:   Book cover spring-in
//  40-65:   Title fade-up
//  50-70:   Author fade-in
//  65-120:  Hero stat (reading time) + stats grid staggered
// 130-170:  Footer branding (spring-in + tagline)
// 150-180:  Audio fade-out
// ──────────────────────────────────────────────────────────────────────

export const BookFinished: React.FC<BookFinishedInput> = (props) => {
  const {
    format,
    title,
    author,
    coverUrl,
    pagesRead,
    readingTime,
    sessions,
    startDate,
    endDate,
    dominantColor,
    secondaryColor,
    seed,
  } = props;

  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Load fonts
  const [fontHandle] = useState(() => delayRender('Loading fonts'));
  useEffect(() => {
    loadFonts().then(() => continueRender(fontHandle));
  }, [fontHandle]);

  const isStory = format === 'story';
  const SCALE = 3;
  const W = 360;
  const H = isStory ? 640 : 360;

  // Audio: fade-in/out (shorter video = shorter fades)
  const musicVolume = (f: number) => {
    const fadeIn = interpolate(f, [0, 15], [0, 0.25], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
    const fadeOut = interpolate(f, [150, 180], [0.25, 0], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
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
        <div
          style={{
            width: W,
            height: H,
            position: 'relative',
            overflow: 'hidden',
          }}
        >
          {/* Layer 1: Dynamic gradient background */}
          <Background
            dominantColor={dominantColor}
            secondaryColor={secondaryColor}
            width={W}
            height={H}
          />

          {/* Layer 2: Decorative pattern */}
          <Pattern seed={seed} color={dominantColor} width={W} height={H} />

          {/* Layer 3: Content */}
          {isStory ? (
            <StoryLayout
              title={title}
              author={author}
              coverUrl={coverUrl}
              pagesRead={pagesRead}
              readingTime={readingTime}
              sessions={sessions}
              startDate={startDate}
              endDate={endDate}
              dominantColor={dominantColor}
              secondaryColor={secondaryColor}
            />
          ) : (
            <SquareLayout
              title={title}
              author={author}
              coverUrl={coverUrl}
              pagesRead={pagesRead}
              readingTime={readingTime}
              sessions={sessions}
              startDate={startDate}
              endDate={endDate}
              dominantColor={dominantColor}
              secondaryColor={secondaryColor}
            />
          )}
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ══════════════════════════════════════════════════════════════════════
// STORY LAYOUT (360 x 640)
// ══════════════════════════════════════════════════════════════════════

interface LayoutProps {
  title: string;
  author: string;
  coverUrl: string;
  pagesRead: number;
  readingTime: string;
  sessions: number;
  startDate: string;
  endDate: string;
  dominantColor: string;
  secondaryColor: string;
}

const StoryLayout: React.FC<LayoutProps> = ({
  title,
  author,
  coverUrl,
  pagesRead,
  readingTime,
  sessions,
  startDate,
  endDate,
  dominantColor,
  secondaryColor,
}) => (
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
    {/* Header branding */}
    <HeaderBranding startFrame={5} />
    <div style={{ height: 28 }} />

    {/* Book cover */}
    <BookCover
      coverUrl={coverUrl}
      title={title}
      author={author}
      dominantColor={dominantColor}
      startFrame={15}
    />
    <div style={{ height: 20 }} />

    {/* Title + author */}
    <BookInfo
      title={title}
      author={author}
      titleStartFrame={40}
      authorStartFrame={50}
    />

    <div style={{ flex: 1, minHeight: 16 }} />

    {/* Stats */}
    <Stats
      readingTime={readingTime}
      pagesRead={pagesRead}
      sessions={sessions}
      startDate={startDate}
      endDate={endDate}
      dominantColor={dominantColor}
      secondaryColor={secondaryColor}
      heroStartFrame={65}
      gridStartFrame={80}
    />

    <div style={{ height: 20 }} />

    {/* Footer branding */}
    <FooterBranding startFrame={130} />
  </div>
);

// ══════════════════════════════════════════════════════════════════════
// SQUARE LAYOUT (360 x 360)
// ══════════════════════════════════════════════════════════════════════

const SquareLayout: React.FC<LayoutProps> = ({
  title,
  author,
  coverUrl,
  pagesRead,
  readingTime,
  sessions,
  startDate,
  endDate,
  dominantColor,
  secondaryColor,
}) => (
  <div
    style={{
      position: 'absolute',
      inset: 0,
      padding: '18px 20px',
      display: 'flex',
      flexDirection: 'column',
    }}
  >
    {/* Header branding */}
    <HeaderBranding startFrame={5} />
    <div style={{ height: 12 }} />

    {/* Main row: cover + info */}
    <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
      <BookCover
        coverUrl={coverUrl}
        title={title}
        author={author}
        dominantColor={dominantColor}
        startFrame={15}
      />
      <div style={{ flex: 1 }}>
        <BookInfo
          title={title}
          author={author}
          titleStartFrame={40}
          authorStartFrame={50}
        />
      </div>
    </div>
    <div style={{ height: 12 }} />

    {/* Stats (compact) */}
    <Stats
      readingTime={readingTime}
      pagesRead={pagesRead}
      sessions={sessions}
      startDate={startDate}
      endDate={endDate}
      dominantColor={dominantColor}
      secondaryColor={secondaryColor}
      heroStartFrame={65}
      gridStartFrame={80}
    />

    <div style={{ flex: 1 }} />

    {/* Footer branding */}
    <FooterBranding startFrame={130} />
  </div>
);
