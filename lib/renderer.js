// ============================================================================
// Remotion server-side renderer
// ============================================================================
// Uses @remotion/bundler to bundle the Remotion project and
// @remotion/renderer to render videos locally.
// Videos are uploaded to Supabase Storage (shares bucket).
// ============================================================================

const path = require('path');
const fs = require('fs');
const os = require('os');
const { bundle } = require('@remotion/bundler');
const { renderMedia, renderStill } = require('@remotion/renderer');
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
);

// Path to the Remotion project entry point.
// In production, set REMOTION_ENTRY to the absolute path of the Remotion src/index.ts.
// By default, assumes the readon repo is cloned alongside readon-sync.
const REMOTION_ENTRY = process.env.REMOTION_ENTRY || path.resolve(__dirname, '../../readon/remotion/src/index.ts');

// Cache the bundle URL so we don't re-bundle on every render.
let bundleUrl = null;

async function ensureBundle() {
  if (bundleUrl) return bundleUrl;

  console.log('Bundling Remotion project...');
  bundleUrl = await bundle({
    entryPoint: REMOTION_ENTRY,
    // Enable webpack caching for faster subsequent bundles
    webpackOverride: (config) => config,
  });
  console.log('Bundle ready:', bundleUrl);
  return bundleUrl;
}

/**
 * Render a Remotion composition to MP4 and a still frame to PNG.
 * Uploads both to Supabase Storage and returns the public URLs.
 *
 * @param {string} compositionId - e.g. "MonthlyWrapped", "BookFinished"
 * @param {object} inputProps - the props passed to the composition
 * @returns {{ videoUrl: string, imageUrl: string }}
 */
async function renderVideo(compositionId, inputProps) {
  const bundled = await ensureBundle();
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'remotion-'));

  const videoPath = path.join(tmpDir, 'output.mp4');
  const imagePath = path.join(tmpDir, 'still.png');

  try {
    // Render video
    console.log(`Rendering ${compositionId}...`);
    await renderMedia({
      composition: {
        id: compositionId,
        durationInFrames: compositionId.includes('Yearly') ? 450 : 180,
        fps: 30,
        width: 1080,
        height: inputProps.format === 'square' ? 1080 : 1920,
        defaultProps: inputProps,
        props: inputProps,
      },
      serveUrl: bundled,
      codec: 'h264',
      outputLocation: videoPath,
      inputProps,
    });

    // Render still (thumbnail at frame 90 — midpoint of 6s video)
    const midFrame = compositionId.includes('Yearly') ? 225 : 90;
    await renderStill({
      composition: {
        id: compositionId,
        durationInFrames: compositionId.includes('Yearly') ? 450 : 180,
        fps: 30,
        width: 1080,
        height: inputProps.format === 'square' ? 1080 : 1920,
        defaultProps: inputProps,
        props: inputProps,
      },
      serveUrl: bundled,
      output: imagePath,
      frame: midFrame,
      inputProps,
    });

    // Upload to Supabase Storage
    const timestamp = Date.now();
    const videoKey = `renders/${compositionId.toLowerCase()}/${timestamp}.mp4`;
    const imageKey = `renders/${compositionId.toLowerCase()}/${timestamp}.png`;

    const videoBuffer = fs.readFileSync(videoPath);
    const imageBuffer = fs.readFileSync(imagePath);

    const [videoUpload, imageUpload] = await Promise.all([
      supabase.storage.from('shares').upload(videoKey, videoBuffer, {
        contentType: 'video/mp4',
        upsert: true,
      }),
      supabase.storage.from('shares').upload(imageKey, imageBuffer, {
        contentType: 'image/png',
        upsert: true,
      }),
    ]);

    if (videoUpload.error) throw new Error(`Video upload failed: ${videoUpload.error.message}`);
    if (imageUpload.error) throw new Error(`Image upload failed: ${imageUpload.error.message}`);

    const baseStorageUrl = `${process.env.SUPABASE_URL}/storage/v1/object/public/shares`;
    const videoUrl = `${baseStorageUrl}/${videoKey}`;
    const imageUrl = `${baseStorageUrl}/${imageKey}`;

    console.log(`Render complete: ${videoUrl}`);
    return { videoUrl, imageUrl };
  } finally {
    // Cleanup temp files
    try {
      if (fs.existsSync(videoPath)) fs.unlinkSync(videoPath);
      if (fs.existsSync(imagePath)) fs.unlinkSync(imagePath);
      fs.rmdirSync(tmpDir);
    } catch (_) {
      // ignore cleanup errors
    }
  }
}

module.exports = { renderVideo };
