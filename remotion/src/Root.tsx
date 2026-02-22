import React from 'react';
import { Composition } from 'remotion';
import { ReadingSession } from './compositions/reading-session/ReadingSession';
import { BookFinished } from './compositions/book-finished/BookFinished';
import { MonthlyWrapped } from './compositions/monthly-wrapped/MonthlyWrapped';
import { YearlyWrapped } from './compositions/yearly-wrapped/YearlyWrapped';
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

export const RemotionRoot: React.FC = () => {
  return (
    <>
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
