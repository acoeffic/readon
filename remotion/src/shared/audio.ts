// ──────────────────────────────────────────────────────────────────────
// Audio tracks available on Supabase Storage (bucket: asset/audio/)
// The server picks one at random when triggering a Remotion render.
// ──────────────────────────────────────────────────────────────────────

/**
 * All wrapped audio tracks hosted on Supabase Storage.
 * Filenames must match exactly what's in the `asset` bucket under `audio/`.
 *
 * To add a new track: upload to Supabase → add the filename here.
 */
export const WRAPPED_AUDIO_TRACKS = [
  // Intro (01-03)
  'wrapped_01_intro_future_bass.mp3',
  'wrapped_02_intro_energetic_upbeat.mp3',
  'wrapped_03_intro_abstract.mp3',
  // Stats (04-07)
  'wrapped_04_stats_background_motivational.mp3',
  'wrapped_05_stats_future_tech.mp3',
  'wrapped_06_stats_trap_future_bass.mp3',
  'wrapped_07_stats_nightfall.mp3',
  // Momentum (08-10)
  'wrapped_08_momentum_bounce_on_it.mp3',
  'wrapped_09_momentum_lokiis.mp3',
  'wrapped_10_momentum_miro_max.mp3',
  // Cool (11-13)
  'wrapped_11_cool_good_vibes.mp3',
  'wrapped_12_cool_vlogs_vlog.mp3',
  'wrapped_13_cool_nastel_bom.mp3',
  // Calm (14-16)
  'wrapped_14_calm_new_age_nature.mp3',
  'wrapped_15_calm_lofi_ksmk.mp3',
  'wrapped_16_calm_lofi_osynthw.mp3',
  // Outro (17-20)
  'wrapped_17_outro_dreamy_night.mp3',
  'wrapped_18_outro_80s_synth.mp3',
  'wrapped_19_outro_soft_house.mp3',
  'wrapped_20_outro_new_age_vibe.mp3',
] as const;

export type WrappedAudioTrack = (typeof WRAPPED_AUDIO_TRACKS)[number];

/**
 * Build the full public URL for a track in the Supabase `asset` bucket.
 * @param supabaseUrl - e.g. "https://xxx.supabase.co"
 * @param filename - one of WRAPPED_AUDIO_TRACKS
 */
export function buildAudioUrl(supabaseUrl: string, filename: string): string {
  return `${supabaseUrl}/storage/v1/object/public/asset/audio/${filename}`;
}

/**
 * Pick a random audio track URL.
 * @param supabaseUrl - e.g. "https://xxx.supabase.co"
 */
export function randomAudioUrl(supabaseUrl: string): string {
  const idx = Math.floor(Math.random() * WRAPPED_AUDIO_TRACKS.length);
  return buildAudioUrl(supabaseUrl, WRAPPED_AUDIO_TRACKS[idx]);
}
