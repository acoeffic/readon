// TypeScript interfaces mirroring the Dart data models

export type ShareFormat = 'story' | 'square';

// ─── Yearly Wrapped ─────────────────────────────────────────────────

export interface GenreData {
  name: string;
  totalMinutes: number;
  percentage: number;
}

export interface TopBookData {
  title: string;
  author: string;
  totalMinutes: number;
  coverUrl?: string;
}

export interface MilestoneData {
  icon: string;
  title: string;
  dateLabel?: string;
}

export interface MonthlyBookCount {
  label: string; // "Jan", "Fev", etc.
  count: number;
}

export interface YearlyWrappedInput {
  format: ShareFormat;
  year: number;
  userName?: string;
  totalMinutes: number;
  totalSessions: number;
  avgSessionMinutes: number;
  booksFinished: number;
  booksPerMonth: MonthlyBookCount[];
  topGenres: GenreData[];
  readerType: string;
  readerEmoji: string;
  nightSessionsPercent: number;
  peakHour: string;
  activeDays: number;
  bestFlow: number;
  bestFlowPeriod: string;
  longestSessionMinutes: number;
  longestSessionDateLabel: string;
  topBooks: TopBookData[];
  milestones: MilestoneData[];
  percentileRank: number;
  totalUsersCompared: number;
  previousYearMinutes: number;
  previousYearBooks: number;
  previousYearSessions: number;
  previousYearFlow: number;
}

// ─── Monthly Wrapped ────────────────────────────────────────────────

export interface BadgeData {
  icon: string;
  name: string;
}

export interface MonthlyWrappedInput {
  format: ShareFormat;
  month: number; // 1-12
  year: number;
  totalMinutes: number;
  sessions: number;
  avgSessionMinutes: number;
  booksFinished: number;
  booksInProgress: number;
  longestSessionMinutes: number;
  bestDayWeekday: number; // 1=Mon..7=Sun
  longestFlow: number;
  currentFlow: number;
  topBook?: TopBookData;
  vsLastMonthPercent: number;
  dailyMinutes: number[];
  badges: BadgeData[];
}

// ─── Book Finished ──────────────────────────────────────────────────

export interface BookFinishedInput {
  format: ShareFormat;
  title: string;
  author: string;
  coverUrl: string;
  pagesRead: number;
  totalPages: number;
  readingTime: string;
  sessions: number;
  startDate: string;
  endDate: string;
  dominantColor: string;
  secondaryColor: string;
  seed: number;
}

// ─── Reading Session ────────────────────────────────────────────────

export interface ReadingSessionInput {
  format: ShareFormat;
  bookTitle: string;
  bookAuthor?: string;
  pagesRead: number;
  durationMinutes: number;
  startPage: number;
  endPage: number;
}
