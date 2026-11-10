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
import { AdMuse, AD_MUSE_DURATION } from './compositions/ad-muse/AdMuse';
import { AdPacteS2, AD_PACTE_S2_DURATION } from './compositions/ad-pacte-s2/AdPacteS2';
import { AdPacteS3, AD_PACTE_S3_DURATION } from './compositions/ad-pacte-s3/AdPacteS3';
import { AdPacteS4, AD_PACTE_S4_DURATION } from './compositions/ad-pacte-s4/AdPacteS4';
import { AdPacteS5, AD_PACTE_S5_DURATION } from './compositions/ad-pacte-s5/AdPacteS5';
import { AdPacteS6, AD_PACTE_S6_DURATION } from './compositions/ad-pacte-s6/AdPacteS6';
import { AdPrix2026, AD_PRIX_2026_DURATION } from './compositions/ad-prix-2026/AdPrix2026';
import { AdStats120, AD_STATS_120_DURATION } from './compositions/ad-stats-120/AdStats120';
import { AdHalloween, AD_HALLOWEEN_DURATION } from './compositions/ad-halloween/AdHalloween';
import { AdMuseGift, AD_MUSE_GIFT_DURATION } from './compositions/ad-muse-gift/AdMuseGift';
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

// ─── Ad Wrapped octobre 2026 — vraies stats d'Adrien (màj mensuelle) ──
const adWrappedDefaults: AdWrappedInput = {
  hookLine1: "Mon bilan d'octobre : 58 minutes…",
  hookLine2: "l'app ne m'a pas raté 📉",
  wrapped: {
    format: 'story',
    month: 10,
    year: 2026,
    totalMinutes: 58,
    sessions: 11,
    avgSessionMinutes: 5,
    booksFinished: 2,
    booksInProgress: 4,
    longestSessionMinutes: 27,
    bestDayWeekday: 1,
    longestFlow: 3,
    currentFlow: 0,
    topBook: {
      title: 'Le Livre des Baltimore',
      author: 'Joël Dicker',
      totalMinutes: 27,
    },
    vsLastMonthPercent: -59,
    dailyMinutes: [0,4,0,3,3,3,0,0,0,6,0,32,1,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
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

      {/* Pub TikTok — « J'ai laissé une IA choisir mon prochain livre » (9:16, 15 s) */}
      <Composition
        id="AdMuse"
        component={AdMuse}
        durationInFrames={AD_MUSE_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « Je laisse une IA choisir le livre cadeau de ma mère » (9:16, 17 s) */}
      <Composition
        id="AdMuseGift"
        component={AdMuseGift}
        durationInFrames={AD_MUSE_GIFT_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « Pacte : la rédemption » (9:16, 15 s) */}
      <Composition
        id="AdPacteS2"
        component={AdPacteS2}
        durationInFrames={AD_PACTE_S2_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « Pacte : 7 soirs d'affilée, jour 3 » (9:16, 15 s) */}
      <Composition
        id="AdPacteS3"
        component={AdPacteS3}
        durationInFrames={AD_PACTE_S3_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « Pacte : verdict 7 sur 7 » (9:16, 15 s) */}
      <Composition
        id="AdPacteS4"
        component={AdPacteS4}
        durationInFrames={AD_PACTE_S4_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « Pacte : 14 jours » (9:16, 15 s) */}
      <Composition
        id="AdPacteS5"
        component={AdPacteS5}
        durationInFrames={AD_PACTE_S5_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « Pacte : la série est cassée » (9:16, 15 s) */}
      <Composition
        id="AdPacteS6"
        component={AdPacteS6}
        durationInFrames={AD_PACTE_S6_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « Grands prix 2026 : 0/6 » (9:16, 15 s) */}
      <Composition
        id="AdPrix2026"
        component={AdPrix2026}
        durationInFrames={AD_PRIX_2026_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « 120 h de lecture en 30 jours » (9:16, 15 s) */}
      <Composition
        id="AdStats120"
        component={AdStats120}
        durationInFrames={AD_STATS_120_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
        defaultProps={{}}
      />

      {/* Pub TikTok — « Halloween : Il était deux fois » (9:16, 15 s) */}
      <Composition
        id="AdHalloween"
        component={AdHalloween}
        durationInFrames={AD_HALLOWEEN_DURATION}
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
