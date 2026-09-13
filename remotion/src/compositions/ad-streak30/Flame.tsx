import React from 'react';

// Small flame glyph drawn as SVG so we never depend on emoji fonts at render time.
export const Flame: React.FC<{ size?: number; style?: React.CSSProperties }> = ({
  size = 64,
  style,
}) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    style={{ display: 'inline-block', verticalAlign: '-12%', ...style }}
  >
    <defs>
      <linearGradient id="flameGrad" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stopColor="#FFB347" />
        <stop offset="55%" stopColor="#FF7A2F" />
        <stop offset="100%" stopColor="#E8442E" />
      </linearGradient>
      <linearGradient id="flameCore" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stopColor="#FFE8A3" />
        <stop offset="100%" stopColor="#FFB03A" />
      </linearGradient>
    </defs>
    <path
      fill="url(#flameGrad)"
      d="M12 1.5c.6 3.2-.6 5.1-2.1 6.8C8.3 10 6.5 11.7 6.5 15a5.5 5.5 0 0 0 11 0c0-1.6-.5-3-1.2-4.3-.3.9-.8 1.6-1.6 2.1.4-3.6-.8-8.3-2.7-11.3Z"
    />
    <path
      fill="url(#flameCore)"
      d="M12 21.2a3.6 3.6 0 0 1-3.6-3.6c0-1.8 1-2.9 2-4 .7-.8 1.3-1.5 1.6-2.5 1.5 1.9 3.6 4 3.6 6.5a3.6 3.6 0 0 1-3.6 3.6Z"
    />
  </svg>
);
