import React from 'react';
import { useCurrentFrame, interpolate, spring, useVideoConfig } from 'remotion';
import { AD_FONTS } from './fonts-local';
import { Flame } from './Flame';

const GREEN = '#7FA497';
const BG = '#F7F5F0';
const DARK = '#1F2A26';

const card: React.CSSProperties = {
  background: '#FFFFFF',
  borderRadius: 28,
  boxShadow: '0 6px 24px rgba(31,42,38,0.08)',
  padding: 32,
};

const Screen: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div
    style={{
      position: 'absolute',
      inset: 0,
      background: BG,
      fontFamily: AD_FONTS.poppins,
      color: DARK,
      display: 'flex',
      flexDirection: 'column',
      padding: '120px 44px 44px',
      gap: 28,
    }}
  >
    {children}
  </div>
);

/** Home screen with streak counter at N days */
export const StreakHome: React.FC<{ streak: number; celebrate?: boolean }> = ({
  streak,
  celebrate = false,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = celebrate
    ? spring({ frame, fps, config: { damping: 10, stiffness: 160 } })
    : 1;
  return (
    <Screen>
      <div style={{ fontSize: 34, fontWeight: 600, opacity: 0.5 }}>Bonsoir 👋</div>
      <div
        style={{
          ...card,
          display: 'flex',
          alignItems: 'center',
          gap: 28,
          transform: `scale(${0.9 + 0.1 * Number(pop)})`,
        }}
      >
        <Flame size={110} />
        <div>
          <div style={{ fontSize: 96, fontWeight: 900, lineHeight: 1 }}>{streak}</div>
          <div style={{ fontSize: 30, fontWeight: 500, opacity: 0.55 }}>
            jours de suite
          </div>
        </div>
      </div>
      <div style={{ ...card, height: 260 }}>
        <div style={{ fontSize: 26, fontWeight: 600, opacity: 0.4, marginBottom: 20 }}>
          EN COURS
        </div>
        <div style={{ display: 'flex', gap: 24 }}>
          <div
            style={{
              width: 110,
              height: 160,
              borderRadius: 14,
              background: `linear-gradient(160deg, ${GREEN}, #4F6E62)`,
            }}
          />
          <div style={{ flex: 1, paddingTop: 8 }}>
            <div style={{ height: 26, width: '80%', borderRadius: 8, background: '#E6E2D8' }} />
            <div style={{ height: 20, width: '50%', borderRadius: 8, background: '#EDEAE1', marginTop: 14 }} />
            <div style={{ height: 14, borderRadius: 7, background: '#EDEAE1', marginTop: 40, width: '100%' }}>
              <div style={{ height: 14, borderRadius: 7, background: GREEN, width: '62%' }} />
            </div>
            <div style={{ fontSize: 22, marginTop: 10, opacity: 0.5 }}>p. 178 / 288</div>
          </div>
        </div>
      </div>
    </Screen>
  );
};

/** Reading timer running */
export const TimerScreen: React.FC = () => {
  const frame = useCurrentFrame();
  const totalSec = Math.floor(frame / 30) + 754;
  const mm = String(Math.floor(totalSec / 60)).padStart(2, '0');
  const ss = String(totalSec % 60).padStart(2, '0');
  const angle = interpolate(frame % 300, [0, 300], [0, 360]);
  return (
    <Screen>
      <div style={{ textAlign: 'center', marginTop: 60 }}>
        <div style={{ fontSize: 30, fontWeight: 500, opacity: 0.5 }}>Session en cours</div>
      </div>
      <div style={{ display: 'flex', justifyContent: 'center', marginTop: 40 }}>
        <div
          style={{
            width: 520,
            height: 520,
            borderRadius: '50%',
            background: `conic-gradient(${GREEN} ${angle}deg, #E6E2D8 ${angle}deg)`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <div
            style={{
              width: 460,
              height: 460,
              borderRadius: '50%',
              background: BG,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <div style={{ fontSize: 110, fontWeight: 900, fontVariantNumeric: 'tabular-nums' }}>
              {mm}:{ss}
            </div>
            <div style={{ fontSize: 28, opacity: 0.5, fontWeight: 500 }}>Dune — Frank Herbert</div>
          </div>
        </div>
      </div>
    </Screen>
  );
};

/** Feed with friend reactions */
export const FeedScreen: React.FC = () => {
  const frame = useCurrentFrame();
  const rows = [
    { name: 'Camille', action: 'a lu 42 pages', likes: 3, emoji: '👏' },
    { name: 'Toi', action: 'streak de 30 jours', likes: 8, emoji: '🔥', hot: true },
    { name: 'Marc', action: 'a terminé « Dune »', likes: 5, emoji: '🎉' },
    { name: 'Léa', action: 'a lu 25 min', likes: 2, emoji: '📚' },
  ];
  return (
    <Screen>
      <div style={{ fontSize: 40, fontWeight: 700 }}>Entre amis</div>
      {rows.map((r, i) => {
        const appear = interpolate(frame, [i * 8, i * 8 + 12], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        });
        return (
          <div
            key={i}
            style={{
              ...card,
              opacity: appear,
              transform: `translateY(${(1 - appear) * 24}px)`,
              display: 'flex',
              alignItems: 'center',
              gap: 24,
              border: r.hot ? `3px solid ${GREEN}` : undefined,
            }}
          >
            <div
              style={{
                width: 84,
                height: 84,
                borderRadius: '50%',
                background: r.hot ? GREEN : '#E6E2D8',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: 40,
              }}
            >
              {r.emoji}
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 30, fontWeight: 700 }}>{r.name}</div>
              <div style={{ fontSize: 26, opacity: 0.55 }}>{r.action}</div>
            </div>
            <div style={{ fontSize: 26, fontWeight: 600, opacity: 0.6 }}>❤️ {r.likes}</div>
          </div>
        );
      })}
    </Screen>
  );
};

/** Quick stats / PAL sweep */
export const StatsScreen: React.FC = () => {
  const frame = useCurrentFrame();
  const bars = [42, 68, 30, 85, 55, 92, 74];
  return (
    <Screen>
      <div style={{ fontSize: 40, fontWeight: 700 }}>Tes stats</div>
      <div style={{ ...card, height: 320, display: 'flex', alignItems: 'flex-end', gap: 20 }}>
        {bars.map((b, i) => {
          const h = interpolate(frame, [i * 3, i * 3 + 18], [0, b], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          });
          return (
            <div
              key={i}
              style={{
                flex: 1,
                height: `${h}%`,
                borderRadius: 10,
                background: i === 5 ? GREEN : '#D8E2DD',
              }}
            />
          );
        })}
      </div>
      <div style={{ display: 'flex', gap: 24 }}>
        {['PAL', 'Badges', 'Wrapped'].map((t, i) => (
          <div key={i} style={{ ...card, flex: 1, textAlign: 'center', padding: 24 }}>
            <div style={{ fontSize: 44, fontWeight: 900, color: GREEN }}>
              {[12, 8, '🏆'][i]}
            </div>
            <div style={{ fontSize: 24, opacity: 0.55, fontWeight: 600 }}>{t}</div>
          </div>
        ))}
      </div>
    </Screen>
  );
};
