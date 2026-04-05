// ============================================================================
// Random audio picker — selects from Supabase Storage asset/audio/ bucket
// ============================================================================

const SUPABASE_URL = process.env.SUPABASE_URL;

const WRAPPED_AUDIO_TRACKS = [
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
];

/**
 * Returns a random public audio URL from the Supabase asset bucket.
 */
function pickRandomAudioUrl() {
  const idx = Math.floor(Math.random() * WRAPPED_AUDIO_TRACKS.length);
  return `${SUPABASE_URL}/storage/v1/object/public/asset/audio/${WRAPPED_AUDIO_TRACKS[idx]}`;
}

module.exports = { WRAPPED_AUDIO_TRACKS, pickRandomAudioUrl };
