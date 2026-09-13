import React from 'react';
import { Composition } from 'remotion';
import { ReadingSession } from './compositions/reading-session/ReadingSession';
import { BookFinished } from './compositions/book-finished/BookFinished';
import { MonthlyWrapped } from './compositions/monthly-wrapped/MonthlyWrapped';
import { YearlyWrapped } from './compositions/yearly-wrapped/YearlyWrapped';
import { AdStreak30, AD_DURATION, AdStreak30Input } from './compositions/ad-streak30/AdStreak30';
import { AdPalScan, AD_PAL_DURATION } from './compositions/ad-pal-scan/AdPalScan';
import { AdWrapped, AD_WRAPPED_DURATION, AdWrappedInput } from './compositions/ad-wrapped/AdWrapped';
import { AdTenMin, AD_TENMIN_DURATION } from './compositions/ad-ten-min/AdTenMin';
import { AdNightReader, AD_NIGHT_DURATION } from './compositions/ad-night-reader/AdNightReader';
import { AdRentree, AD_RENTREE_DURATION } from './compositions/ad-rentree/AdRentree';
import { AdPacteS1, AD_PACTE_S1_DURATION } from './compositions/ad-pacte-s1/AdPacteS1';
import {
  ReadingSessionInput,
  BookFinishedInput,
  MonthlyWrappedInput,
  YearlyWrappedInput,
} from './shared/types';

const FPS = 30;
const DURATION_15S = FPS * 15; // 450
const DURATION_6S = FPS * 6;   // 180

// ─── Reading Session defaults ──────────────────────────────────────
const readingSessionDefaults: ReadingSessionInput = {
  format: 'story',
  bookTitle: 'Dune',
  bookAuthor: 'Frank Herbert',
  pagesRead: 36,
  durationMinutes: 45,
  startPage: 42,
  endPage: 78,
};

// ─── Book Finished defaults ────────────────────────────────────────
const bookFinishedDefaults: BookFinishedInput = {
  format: 'story',
  title: 'Dune',
  author: 'Frank Herbert',
  coverUrl: '',
  pagesRead: 688,
  totalPages: 688,
  readingTime: '22h 15min',
  sessions: 31,
  startDate: '3 Déc',
  endDate: '2 Fév',
  dominantColor: '#D97706',
  secondaryColor: '#92400E',
  seed: 42,
};

// ─── Monthly Wrapped defaults ──────────────────────────────────────
const monthlyWrappedDefaults: MonthlyWrappedInput = {
  format: 'story',
  month: 5,
  year: 2025,
  totalMinutes: 1480,
  sessions: 24,
  avgSessionMinutes: 62,
  booksFinished: 3,
  booksInProgress: 2,
  longestSessionMinutes: 120,
  bestDayWeekday: 7,
  longestFlow: 12,
  currentFlow: 8,
  topBook: {
    title: 'L\'Insoutenable Légèreté de l\'être',
    author: 'Milan Kundera',
    totalMinutes: 480,
  },
  vsLastMonthPercent: 23,
  dailyMinutes: Array.from({ length: 31 }, (_, i) => Math.round(Math.random() * 60)),
  badges: [],
};

// ─── Yearly Wrapped defaults ───────────────────────────────────────
const yearlyWrappedDefaults: YearlyWrappedInput = {
  format: 'story',
  year: 2025,
  userName: 'Adrien',
  totalMinutes: 14820,
  totalSessions: 1482,
  avgSessionMinutes: 10,
  booksFinished: 34,
  booksPerMonth: [],
  topGenres: [],
  readerType: 'Night Owl Reader',
  readerEmoji: '\uD83C\uDF19',
  nightSessionsPercent: 72,
  peakHour: '22h30',
  activeDays: 298,
  bestFlow: 42,
  bestFlowPeriod: 'Juillet-Août',
  longestSessionMinutes: 180,
  longestSessionDateLabel: '15 mars',
  topBooks: [
    { title: 'Les Frères Karamazov', author: 'Dostoïevski', totalMinutes: 2400 },
    { title: 'Dune', author: 'Frank Herbert', totalMinutes: 1800 },
  ],
  milestones: [],
  percentileRank: 3,
  totalUsersCompared: 12000,
  previousYearMinutes: 9600,
  previousYearBooks: 22,
  previousYearSessions: 980,
  previousYearFlow: 28,
};

// Cast needed because Remotion Composition expects (Schema, Props) generics
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const ReadingSessionComp = ReadingSession as React.FC<any>;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const BookFinishedComp = BookFinished as React.FC<any>;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const MonthlyWrappedComp = MonthlyWrapped as React.FC<any>;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const YearlyWrappedComp = YearlyWrapped as React.FC<any>;

// ─── Ad Streak 30 defaults (pub TikTok/Reels) ──────────────────────
const adStreak30Defaults: AdStreak30Input = {
  rushHome: 'surface_session.mp4',
  rushSession: 'surface_session.mp4',
  rushMoment: 'badge.png',
  rushFeed: 'stats.png',
  rushSweep: 'stats.png',
  trimHome: 0.2,
  trimSession: 1.8,
  trimMoment: 0,
  trimFeed: 0,
  trimSweep: 0,
};

// ─── Ad Wrapped août 2026 — vraies stats d'Adrien (màj mensuelle) ──
const adWrappedDefaults: AdWrappedInput = {
  hookLine1: "Mon app m'a sorti mon bilan d'août…",
  hookLine2: "c'est gênant 📉",
  wrapped: {
    format: 'story',
    month: 8,
    year: 2026,
    totalMinutes: 65,
    sessions: 6,
    avgSessionMinutes: 11,
    booksFinished: 1,
    booksInProgress: 3,
    longestSessionMinutes: 14,
    bestDayWeekday: 3,
    longestFlow: 2,
    currentFlow: 2,
    topBook: {
      title: "L'étrange défaite",
      author: 'Marc Bloch',
      totalMinutes: 31,
    },
    vsLastMonthPercent: -76,
    dailyMinutes: [0,9,0,11,14,0,0,0,13,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,12,7,0],
    badges: [],
  },
};

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* Pub TikTok/Reels — Concept A « Streak 30 jours » (9:16, 18 s) */}
      <Composition
        id="AdStreak30"
        component={AdStreak30 as React.FC<any>}
        durationInFrames={AD_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={adStreak30Defaults}
      />

      {/* Pub TikTok/Reels — Concept C « PAL satisfaisante » (9:16, 15 s) */}
      <Composition
        id="AdPalScan"
        component={AdPalScan as React.FC<any>}
        durationInFrames={AD_PAL_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « Mon Wrapped du mois » (9:16, 8 s) */}
      <Composition
        id="AdWrapped"
        component={AdWrapped as React.FC<any>}
        durationInFrames={AD_WRAPPED_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={adWrappedDefaults}
      />

      {/* Pub TikTok — « 10 minutes par soir » (9:16, 15 s, motion design) */}
      <Composition
        id="AdTenMin"
        component={AdTenMin}
        durationInFrames={AD_TENMIN_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « L'app m'a démasqué » (9:16, 14 s) */}
      <Composition
        id="AdNightReader"
        component={AdNightReader}
        durationInFrames={AD_NIGHT_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « Le pacte de rentrée » (9:16, 15 s, motion design) */}
      <Composition
        id="AdRentree"
        component={AdRentree}
        durationInFrames={AD_RENTREE_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « Pacte de rentrée : semaine 1 » (9:16, 15 s) */}
      <Composition
        id="AdPacteS1"
        component={AdPacteS1}
        durationInFrames={AD_PACTE_S1_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Reading Session - Story format (9:16) */}
      <Composition
        id="ReadingSession"
        component={ReadingSessionComp}
        durationInFrames={DURATION_6S}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={readingSessionDefaults}
      />

      {/* Reading Session - Square format (1:1) */}
      <Composition
        id="ReadingSessionSquare"
        component={ReadingSessionComp}
        durationInFrames={DURATION_6S}
        fps={FPS}
        width={1080}
        height={1080}
        defaultProps={{ ...readingSessionDefaults, format: 'square' as const }}
      />

      {/* Book Finished - Story format (9:16) – 6 seconds */}
      <Composition
        id="BookFinished"
        component={BookFinishedComp}
        durationInFrames={DURATION_6S}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={bookFinishedDefaults}
      />

      {/* Book Finished - Square format (1:1) – 6 seconds */}
      <Composition
        id="BookFinishedSquare"
        component={BookFinishedComp}
        durationInFrames={DURATION_6S}
        fps={FPS}
        width={1080}
        height={1080}
        defaultProps={{ ...bookFinishedDefaults, format: 'square' as const }}
      />

      {/* Monthly Wrapped - Story format (9:16) – 6 seconds */}
      <Composition
        id="MonthlyWrapped"
        component={MonthlyWrappedComp}
        durationInFrames={DURATION_6S}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={monthlyWrappedDefaults}
      />

      {/* Monthly Wrapped - Square format (1:1) – 6 seconds */}
      <Composition
        id="MonthlyWrappedSquare"
        component={MonthlyWrappedComp}
        durationInFrames={DURATION_6S}
        fps={FPS}
        width={1080}
        height={1080}
        defaultProps={{ ...monthlyWrappedDefaults, format: 'square' as const }}
      />

      {/* Yearly Wrapped - Story format (9:16) */}
      <Composition
        id="YearlyWrapped"
        component={YearlyWrappedComp}
        durationInFrames={DURATION_15S}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={yearlyWrappedDefaults}
      />

      {/* Yearly Wrapped - Square format (1:1) */}
      <Composition
        id="YearlyWrappedSquare"
        component={YearlyWrappedComp}
        durationInFrames={DURATION_15S}
        fps={FPS}
        width={1080}
        height={1080}
        defaultProps={{ ...yearlyWrappedDefaults, format: 'square' as const }}
      />
    </>
  );
};
