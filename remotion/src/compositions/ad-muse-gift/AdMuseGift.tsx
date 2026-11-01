import React from 'react';
import {
  AbsoluteFill,
  Sequence,
  Img,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
} from 'remotion';
import { ensureAdFonts, AD_FONTS } from '../ad-streak30/fonts-local';
import { Outro, Caption, FloatingPhone } from '../ad-streak30/AdStreak30';
import { ParticleField } from '../../shared/animations/particle-field';

// ─── « Je laisse une IA choisir le livre cadeau de ma mère » ───────
// 17 s (510 frames), zéro rush : écran Muse recréé en animation.
// Tous les textes sont des props → remplacer par la vraie réponse de Muse
// (voir defaultProps dans Root.tsx). Publication cible : mi-novembre,
// suite (réaction de maman) le 25 décembre.
export const AD_MUSE_GIFT_DURATION = 510;

export interface AdMuseGiftInput {
  /** Message tapé par l'utilisateur dans Muse */
  userMessage: string;
  /** Début de la réponse de Muse (avant le titre) */
  museIntro: string;
  bookTitle: string;
  bookAuthor: string;
  /** Fin de la réponse de Muse (après l'auteur) */
  museReason: string;
  /** Couverture optionnelle : fichier dans public/rushes/ (ex. 'gift_cover.jpg') */
  coverSrc?: string | null;
  /** Dernière phrase affichée sur la carte finale */
  teaser?: string;
}

export const adMuseGiftDefaults: AdMuseGiftInput = {
  userMessage:
    "Je cherche un livre à offrir à ma mère pour Noël. Elle a adoré « L'Élégance du hérisson » et « Le Club des incorrigibles optimistes ». Elle aime les héroïnes fortes et les histoires qui font voyager.",
  museIntro: 'Pour ta maman, je te recommande ',
  bookTitle: '« Là où chantent les écrevisses »',
  bookAuthor: 'Delia Owens',
  museReason:
    '. Une héroïne indomptable, une nature sauvage et un souffle romanesque : parfait pour une lectrice qui aime voyager et les personnages forts. Un cadeau qui se lit d’une traite. 🎁',
  coverSrc: null,
  teaser: 'Réponse de maman le 25 décembre 🎄',
};

const DARK_BG = 'radial-gradient(circle at 50% 32%, #123329 0%, #0A1F1A 62%)';
const GREEN = '#7FA497';
const AMBER = '#FFB347';
const SCREEN_BG = '#F2EFE8';
const INK = '#1F2A26';
const FOREST = '#2F5D4E';

/** Hook plein écran */
const HookScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 15, stiffness: 190 } });
  return (
    <AbsoluteFill
      style={{ alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '0 70px' }}
    >
      <div
        style={{
          fontFamily: AD_FONTS.poppins,
          fontWeight: 900,
          fontSize: 80,
          lineHeight: 1.25,
          color: '#FFFFFF',
          transform: `scale(${0.92 + 0.08 * s})`,
        }}
      >
        Je laisse une IA choisir
        <br />
        <span style={{ color: AMBER }}>
          le livre cadeau
          <br />
          de ma mère. 🎁
        </span>
      </div>
    </AbsoluteFill>
  );
};

// ─── Écran Muse recréé (coordonnées pour un écran ~656×1473) ───────

const Sparkle: React.FC<{ size?: number }> = ({ size = 40 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={GREEN}>
    <path d="M10 3l1.7 4.6L16 9.3l-4.3 1.7L10 15.6 8.3 11 4 9.3l4.3-1.7L10 3z" />
    <path d="M18 12l.9 2.4 2.4.9-2.4.9L18 18.6l-.9-2.4-2.4-.9 2.4-.9L18 12z" />
  </svg>
);

const BubbleText: React.FC<{ segments: Array<{ t: string; link?: boolean }> }> = ({ segments }) => (
  <>
    {segments.map((seg, i) => (
      <span
        key={i}
        style={
          seg.link
            ? { color: GREEN, textDecoration: 'underline', textUnderlineOffset: 4, fontWeight: 600 }
            : undefined
        }
      >
        {seg.t}
      </span>
    ))}
  </>
);

/** Découpe en mots en conservant le style lien, puis tronque à `count` mots */
function revealSegments(
  parts: Array<{ t: string; link?: boolean }>,
  count: number
): Array<{ t: string; link?: boolean }> {
  const out: Array<{ t: string; link?: boolean }> = [];
  let left = count;
  for (const p of parts) {
    const words = p.t.split(/(?<=\s)/); // garde l'espace final de chaque mot
    let acc = '';
    for (const w of words) {
      if (left <= 0) break;
      acc += w;
      left -= 1;
    }
    if (acc) out.push({ t: acc, link: p.link });
    if (left <= 0) break;
  }
  return out;
}

const MuseChat: React.FC<{ input: AdMuseGiftInput }> = ({ input }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const TYPE_END = 80; // fin de frappe
  const SEND_AT = 86;
  const THINK_FROM = 100;
  const ANSWER_AT = 150;

  const typed = input.userMessage.slice(
    0,
    Math.floor(Math.min(frame / TYPE_END, 1) * input.userMessage.length)
  );
  const sent = frame >= SEND_AT;
  const sentSpring = spring({ frame: frame - SEND_AT, fps, config: { damping: 15, stiffness: 170 } });

  const thinking = frame >= THINK_FROM && frame < ANSWER_AT;
  const answering = frame >= ANSWER_AT;
  const answerSpring = spring({ frame: frame - ANSWER_AT, fps, config: { damping: 15, stiffness: 150 } });

  const parts = [
    { t: input.museIntro },
    { t: `${input.bookTitle} de ${input.bookAuthor}`, link: true },
    { t: input.museReason },
  ];
  const totalWords = parts.reduce((n, p) => n + p.t.split(/(?<=\s)/).length, 0);
  const wordsShown = Math.min(totalWords, Math.floor((frame - ANSWER_AT) * 0.9));
  const answerParts = revealSegments(parts, Math.max(0, wordsShown));

  const dot = (i: number) => 0.35 + 0.65 * Math.max(0, Math.sin((frame - i * 5) * 0.35));

  return (
    <AbsoluteFill style={{ background: SCREEN_BG, fontFamily: AD_FONTS.inter }}>
      {/* Barre de statut */}
      <div
        style={{
          position: 'absolute',
          top: 36,
          left: 52,
          fontWeight: 700,
          fontSize: 26,
          color: INK,
        }}
      >
        9:41
      </div>

      {/* En-tête */}
      <div
        style={{
          position: 'absolute',
          top: 100,
          left: 34,
          right: 34,
          display: 'flex',
          alignItems: 'center',
          gap: 18,
          color: INK,
        }}
      >
        <span style={{ fontSize: 40, lineHeight: 1 }}>←</span>
        <Sparkle size={44} />
        <span style={{ fontWeight: 700, fontSize: 34 }}>Muse</span>
      </div>

      {/* Fil de discussion */}
      <div
        style={{
          position: 'absolute',
          top: 190,
          left: 26,
          right: 26,
          bottom: 250,
          display: 'flex',
          flexDirection: 'column',
          gap: 22,
          justifyContent: 'flex-start',
        }}
      >
        {sent && (
          <div
            style={{
              alignSelf: 'flex-end',
              maxWidth: '84%',
              background: FOREST,
              color: '#F5EFE3',
              fontSize: 31,
              lineHeight: 1.38,
              padding: '20px 26px',
              borderRadius: '30px 30px 8px 30px',
              transform: `translateY(${(1 - sentSpring) * 40}px)`,
              opacity: sentSpring,
            }}
          >
            {input.userMessage}
          </div>
        )}

        {thinking && (
          <div
            style={{
              alignSelf: 'flex-start',
              background: '#FFFFFF',
              borderRadius: '30px 30px 30px 8px',
              padding: '24px 32px',
              display: 'flex',
              gap: 12,
            }}
          >
            {[0, 1, 2].map((i) => (
              <div
                key={i}
                style={{
                  width: 16,
                  height: 16,
                  borderRadius: 8,
                  background: GREEN,
                  opacity: dot(i),
                }}
              />
            ))}
          </div>
        )}

        {answering && (
          <div
            style={{
              alignSelf: 'flex-start',
              maxWidth: '90%',
              background: '#FFFFFF',
              color: INK,
              fontSize: 31,
              lineHeight: 1.4,
              padding: '22px 28px',
              borderRadius: '30px 30px 30px 8px',
              boxShadow: '0 4px 18px rgba(0,0,0,0.06)',
              transform: `scale(${0.94 + 0.06 * answerSpring})`,
              transformOrigin: 'left top',
              opacity: Math.min(1, answerSpring * 1.5),
            }}
          >
            <BubbleText segments={answerParts} />
          </div>
        )}
      </div>

      {/* Composer */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          height: 230,
          background: '#FFFFFF',
          padding: '26px 24px 0',
          display: 'flex',
          gap: 16,
          alignItems: 'flex-start',
        }}
      >
        <div
          style={{
            flex: 1,
            height: 130,
            overflow: 'hidden',
            display: 'flex',
            alignItems: 'flex-end',
            border: `3px solid ${GREEN}`,
            borderRadius: 26,
            background: SCREEN_BG,
            padding: '14px 22px',
            fontSize: 25,
            lineHeight: 1.35,
            color: sent ? '#8A9A93' : INK,
          }}
        >
          <div>
            {sent ? (
              'Demande une recommandation…'
            ) : (
              <>
                {typed}
                <span style={{ color: GREEN }}>|</span>
              </>
            )}
          </div>
        </div>
        <div style={{ paddingTop: 36 }}>
          <svg width="56" height="56" viewBox="0 0 24 24" fill={GREEN}>
            <path d="M2 21l21-9L2 3v7l15 2-15 2z" />
          </svg>
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ─── Carte finale : le livre choisi, emballé ───────────────────────

const GiftCard: React.FC<{ input: AdMuseGiftInput }> = ({ input }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 12, stiffness: 120 } });
  const label = spring({ frame: frame - 4, fps, config: { damping: 14, stiffness: 170 } });
  const bow = spring({ frame: frame - 24, fps, config: { damping: 8, stiffness: 140 } });
  const W = 480;
  const H = 700;
  return (
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center' }}>
      <div
        style={{
          position: 'absolute',
          top: 250,
          fontFamily: AD_FONTS.poppins,
          fontWeight: 700,
          fontSize: 50,
          color: GREEN,
          opacity: label,
          transform: `translateY(${(1 - label) * 20}px)`,
        }}
      >
        Le choix de Muse
      </div>

      <div
        style={{
          position: 'relative',
          width: W,
          height: H,
          marginTop: 30,
          transform: `scale(${0.7 + 0.3 * s}) rotate(${(1 - s) * -6 + 2}deg)`,
          opacity: Math.min(1, s * 2),
          borderRadius: 14,
          overflow: 'hidden',
          boxShadow: '0 40px 90px rgba(0,0,0,0.55)',
          background: 'linear-gradient(160deg, #1F4E4A 0%, #0E2B2A 100%)',
        }}
      >
        {input.coverSrc ? (
          <Img
            src={staticFile(`rushes/${input.coverSrc}`)}
            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
          />
        ) : (
          <div
            style={{
              height: '100%',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'flex-start',
              gap: 44,
              padding: '56px 40px',
              textAlign: 'center',
            }}
          >
            <div
              style={{
                fontFamily: AD_FONTS.inter,
                fontWeight: 600,
                fontSize: 30,
                letterSpacing: 4,
                color: AMBER,
                textTransform: 'uppercase',
              }}
            >
              {input.bookAuthor}
            </div>
            <div
              style={{
                fontFamily: AD_FONTS.poppins,
                fontWeight: 700,
                fontSize: 56,
                lineHeight: 1.2,
                color: '#F5E6C8',
              }}
            >
              {input.bookTitle.replace(/[«»]/g, '').trim()}
            </div>
            <div style={{ height: 6, width: 90, background: AMBER, margin: '0 auto', borderRadius: 3 }} />
          </div>
        )}

        {/* Ruban */}
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            top: '74%',
            height: 64,
            background: 'linear-gradient(180deg, #C23B3B 0%, #E25555 50%, #C23B3B 100%)',
            opacity: 0.95,
          }}
        />
      </div>

      {/* Nœud */}
      <div
        style={{
          position: 'absolute',
          top: 'calc(50% + 100px)',
          fontSize: 150,
          transform: `scale(${bow}) translateY(${(1 - bow) * -40}px)`,
          marginTop: 30,
          filter: 'drop-shadow(0 10px 20px rgba(0,0,0,0.4))',
        }}
      >
        🎀
      </div>
    </AbsoluteFill>
  );
};

export const AdMuseGift: React.FC<Partial<AdMuseGiftInput>> = (props) => {
  ensureAdFonts();
  const input: AdMuseGiftInput = { ...adMuseGiftDefaults, ...props };
  const { width, height } = useVideoConfig();
  return (
    <AbsoluteFill style={{ background: '#0A1F1A' }}>
      <AbsoluteFill style={{ background: DARK_BG }} />
      <ParticleField count={35} color={GREEN} seed={31} width={width} height={height} />

      {/* S1 Hook 0–70 */}
      <Sequence durationInFrames={70} name="Hook">
        <HookScene />
      </Sequence>

      {/* S2–S4 Conversation Muse en un seul plan (70–360) */}
      <Sequence from={70} durationInFrames={290} name="Muse chat">
        <FloatingPhone baseScale={0.95} rotate={-1.5} yOffset={30}>
          <MuseChat input={input} />
        </FloatingPhone>
      </Sequence>
      <Sequence from={70} durationInFrames={90} name="Étape 1">
        <Caption text="Étape 1 : je lui parle de maman." appearAt={6} bottom={150} />
      </Sequence>
      <Sequence from={170} durationInFrames={55} name="Étape 2">
        <Caption text="Étape 2 : Muse réfléchit…" appearAt={4} bottom={150} />
      </Sequence>
      <Sequence from={225} durationInFrames={135} name="Étape 3">
        <Caption text="Étape 3 : elle a tranché 🎯" appearAt={4} bottom={150} />
      </Sequence>

      {/* S5 Le livre choisi 360–450 */}
      <Sequence from={360} durationInFrames={90} name="Cadeau">
        <GiftCard input={input} />
        <Caption text={input.teaser ?? ''} appearAt={14} bottom={190} accent />
      </Sequence>

      {/* S6 Outro 450–510 */}
      <Sequence from={450} durationInFrames={60} name="Outro">
        <Outro />
      </Sequence>
    </AbsoluteFill>
  );
};
