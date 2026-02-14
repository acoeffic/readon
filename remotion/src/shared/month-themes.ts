// 12 month themes mirroring Flutter's monthThemes map

export interface MonthTheme {
  gradientColors: [string, string];
  accent: string;
  emoji: string;
}

export const monthThemes: Record<number, MonthTheme> = {
  1: {
    gradientColors: ['#0B1120', '#1B2A4A'],
    accent: '#7EC8E3',
    emoji: '\u2744\uFE0F', // snowflake
  },
  2: {
    gradientColors: ['#1A0A2E', '#3D1F56'],
    accent: '#E8A0BF',
    emoji: '\uD83D\uDC9C', // purple heart
  },
  3: {
    gradientColors: ['#0A1F0A', '#1B3D2F'],
    accent: '#90EE90',
    emoji: '\uD83C\uDF31', // seedling
  },
  4: {
    gradientColors: ['#1F1A0A', '#3D3520'],
    accent: '#FFD700',
    emoji: '\uD83C\uDF24\uFE0F', // sun behind cloud
  },
  5: {
    gradientColors: ['#0A1A1F', '#1B3540'],
    accent: '#FF6B8A',
    emoji: '\uD83C\uDF38', // cherry blossom
  },
  6: {
    gradientColors: ['#1F0F00', '#4A2800'],
    accent: '#FFA24C',
    emoji: '\u2600\uFE0F', // sun
  },
  7: {
    gradientColors: ['#00101F', '#002040'],
    accent: '#00D4FF',
    emoji: '\uD83C\uDFD6\uFE0F', // beach
  },
  8: {
    gradientColors: ['#1A0F00', '#3D2400'],
    accent: '#FFB347',
    emoji: '\uD83C\uDF05', // sunrise
  },
  9: {
    gradientColors: ['#150A00', '#3A2010'],
    accent: '#D4915E',
    emoji: '\uD83C\uDF42', // fallen leaf
  },
  10: {
    gradientColors: ['#0F0A1A', '#2A1F3D'],
    accent: '#C77DFF',
    emoji: '\uD83C\uDF83', // jack-o-lantern
  },
  11: {
    gradientColors: ['#0D0D0D', '#2A2A2A'],
    accent: '#A0A0A0',
    emoji: '\uD83C\uDF2B\uFE0F', // fog
  },
  12: {
    gradientColors: ['#0A0015', '#1A0A3D'],
    accent: '#FFD93D',
    emoji: '\u2728', // sparkles
  },
};

export function getMonthTheme(month: number): MonthTheme {
  return monthThemes[month] ?? monthThemes[1]!;
}

const monthNames = [
  '', // index 0 unused
  'Janvier', 'Fevrier', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Aout', 'Septembre', 'Octobre', 'Novembre', 'Decembre',
];

export function getMonthName(month: number): string {
  return month >= 1 && month <= 12 ? monthNames[month]! : '';
}

const dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

export function getDayName(weekday: number): string {
  return weekday >= 1 && weekday <= 7 ? dayNames[weekday - 1]! : '';
}
