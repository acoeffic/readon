// ============================================================================
// readon-sync — LexDay video render backend
// ============================================================================
// Endpoints (consumed by the Flutter app via ReadonSyncService):
//   POST /api/wrapped/monthly/:year/:month/render  → trigger async render
//   GET  /api/wrapped/monthly/:year/:month/share    → poll render status
//   POST /api/books/:bookId/finish                  → trigger book-finish render
//   GET  /api/books/:bookId/share                   → poll book share assets
// ============================================================================

const express = require('express');
const { createClient } = require('@supabase/supabase-js');
const { renderVideo } = require('./lib/renderer');
const { authenticateUser } = require('./lib/auth');
const { pickRandomAudioUrl } = require('./lib/audio');

const app = express();
app.use(express.json());

// ── Supabase admin client (service role) ──────────────────────────────
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
);

// ── Health check ──────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ ok: true }));

// ======================================================================
// MONTHLY WRAPPED
// ======================================================================

// POST /api/wrapped/monthly/:year/:month/render
// Triggers async video render for the authenticated user's monthly wrapped.
app.post('/api/wrapped/monthly/:year/:month/render', authenticateUser, async (req, res) => {
  const userId = req.userId;
  const month = parseInt(req.params.month, 10);
  const year = parseInt(req.params.year, 10);

  if (month < 1 || month > 12 || year < 2020) {
    return res.status(400).json({ error: 'Invalid month/year' });
  }

  try {
    // Upsert a pending record
    const { error: upsertError } = await supabase
      .from('monthly_wrapped_shares')
      .upsert(
        { user_id: userId, month, year, video_status: 'pending', updated_at: new Date().toISOString() },
        { onConflict: 'user_id,month,year' },
      );

    if (upsertError) {
      console.error('Upsert error:', upsertError);
      return res.status(500).json({ error: 'Database error' });
    }

    res.json({ status: 'pending' });

    // Fire-and-forget: gather data + render video
    renderMonthlyWrapped(userId, month, year).catch((err) => {
      console.error(`Render error for user=${userId} month=${month}/${year}:`, err);
    });
  } catch (err) {
    console.error('Render endpoint error:', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// GET /api/wrapped/monthly/:year/:month/share
// Returns the current render status + video/image URLs.
app.get('/api/wrapped/monthly/:year/:month/share', authenticateUser, async (req, res) => {
  const userId = req.userId;
  const month = parseInt(req.params.month, 10);
  const year = parseInt(req.params.year, 10);

  const { data, error } = await supabase
    .from('monthly_wrapped_shares')
    .select('video_url, image_url, video_status')
    .eq('user_id', userId)
    .eq('month', month)
    .eq('year', year)
    .maybeSingle();

  if (error) {
    console.error('Share query error:', error);
    return res.status(500).json({ error: 'Database error' });
  }

  if (!data) {
    return res.json({ status: 'none' });
  }

  res.json({
    status: data.video_status || 'none',
    videoUrl: data.video_url,
    imageUrl: data.image_url,
  });
});

// ======================================================================
// BOOK FINISHED
// ======================================================================

// POST /api/books/:bookId/finish
app.post('/api/books/:bookId/finish', authenticateUser, async (req, res) => {
  const userId = req.userId;
  const bookId = req.params.bookId;

  try {
    // Mark as pending
    const { error } = await supabase
      .from('user_books')
      .update({ share_video_status: 'pending', updated_at: new Date().toISOString() })
      .eq('user_id', userId)
      .eq('book_id', bookId);

    if (error) {
      console.error('Book finish update error:', error);
      return res.status(500).json({ error: 'Database error' });
    }

    res.json({ status: 'pending' });

    // Fire-and-forget: render book-finished video
    renderBookFinished(userId, bookId).catch((err) => {
      console.error(`Book render error for user=${userId} book=${bookId}:`, err);
    });
  } catch (err) {
    console.error('Book finish endpoint error:', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// GET /api/books/:bookId/share
app.get('/api/books/:bookId/share', authenticateUser, async (req, res) => {
  const userId = req.userId;
  const bookId = req.params.bookId;

  const { data, error } = await supabase
    .from('user_books')
    .select('share_video_url, share_image_url, share_video_status')
    .eq('user_id', userId)
    .eq('book_id', bookId)
    .maybeSingle();

  if (error || !data) {
    return res.json({ status: 'none' });
  }

  res.json({
    status: data.share_video_status || 'none',
    videoUrl: data.share_video_url,
    imageUrl: data.share_image_url,
  });
});

// ======================================================================
// RENDER LOGIC
// ======================================================================

async function renderMonthlyWrapped(userId, month, year) {
  try {
    // 1. Update status → rendering
    await supabase
      .from('monthly_wrapped_shares')
      .update({ video_status: 'rendering', updated_at: new Date().toISOString() })
      .eq('user_id', userId)
      .eq('month', month)
      .eq('year', year);

    // 2. Gather data from Supabase (same queries as Flutter MonthlyWrappedService)
    const inputProps = await gatherMonthlyData(userId, month, year);

    // 3. Render video (story format)
    const { videoUrl, imageUrl } = await renderVideo('MonthlyWrapped', {
      ...inputProps,
      format: 'story',
      audioUrl: pickRandomAudioUrl(),
    });

    // 4. Update with final URLs
    await supabase
      .from('monthly_wrapped_shares')
      .update({
        video_url: videoUrl,
        image_url: imageUrl,
        video_status: 'done',
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId)
      .eq('month', month)
      .eq('year', year);

    console.log(`Monthly wrapped rendered: user=${userId} month=${month}/${year}`);
  } catch (err) {
    await supabase
      .from('monthly_wrapped_shares')
      .update({ video_status: 'error', updated_at: new Date().toISOString() })
      .eq('user_id', userId)
      .eq('month', month)
      .eq('year', year);
    throw err;
  }
}

async function renderBookFinished(userId, bookId) {
  try {
    await supabase
      .from('user_books')
      .update({ share_video_status: 'rendering' })
      .eq('user_id', userId)
      .eq('book_id', bookId);

    const inputProps = await gatherBookData(userId, bookId);

    const { videoUrl, imageUrl } = await renderVideo('BookFinished', {
      ...inputProps,
      format: 'story',
      audioUrl: pickRandomAudioUrl(),
    });

    await supabase
      .from('user_books')
      .update({
        share_video_url: videoUrl,
        share_image_url: imageUrl,
        share_video_status: 'done',
      })
      .eq('user_id', userId)
      .eq('book_id', bookId);

    console.log(`Book finished rendered: user=${userId} book=${bookId}`);
  } catch (err) {
    await supabase
      .from('user_books')
      .update({ share_video_status: 'error' })
      .eq('user_id', userId)
      .eq('book_id', bookId);
    throw err;
  }
}

// ======================================================================
// DATA GATHERING
// ======================================================================

async function gatherMonthlyData(userId, month, year) {
  const start = new Date(Date.UTC(year, month - 1, 1)).toISOString();
  const end = new Date(Date.UTC(month === 12 ? year + 1 : year, month === 12 ? 0 : month, 1)).toISOString();

  // Parallel queries
  const [sessionsRes, booksFinishedRes, booksInProgressRes, badgesRes, prevMonthRes] = await Promise.all([
    // Completed sessions this month
    supabase
      .from('reading_sessions')
      .select('start_time, end_time, book_id, books(title, author, cover_url)')
      .eq('user_id', userId)
      .not('end_time', 'is', null)
      .gte('start_time', start)
      .lt('start_time', end)
      .order('start_time'),

    // Books finished this month
    supabase
      .from('user_books')
      .select('book_id')
      .eq('user_id', userId)
      .eq('status', 'finished')
      .gte('updated_at', start)
      .lt('updated_at', end),

    // Books currently in progress
    supabase
      .from('user_books')
      .select('book_id')
      .eq('user_id', userId)
      .eq('status', 'reading'),

    // Badges earned this month
    supabase
      .from('user_badges')
      .select('badge_id, badges(name, icon)')
      .eq('user_id', userId)
      .gte('earned_at', start)
      .lt('earned_at', end),

    // Previous month total minutes
    getPreviousMonthMinutes(userId, month, year),
  ]);

  const sessions = sessionsRes.data || [];
  const booksFinished = (booksFinishedRes.data || []).length;
  const booksInProgress = (booksInProgressRes.data || []).length;
  const badges = (badgesRes.data || []).map((b) => ({
    icon: b.badges?.icon || '',
    name: b.badges?.name || '',
  }));
  const prevMonthMinutes = prevMonthRes;

  // Aggregate session stats
  const daysInMonth = new Date(year, month, 0).getDate();
  const dailyMinutes = new Array(daysInMonth).fill(0);
  let totalMinutes = 0;
  let longestSessionMinutes = 0;
  const dayOfWeekTotals = {};
  const bookMinutes = {};
  const bookInfos = {};

  for (const s of sessions) {
    const st = new Date(s.start_time);
    const et = new Date(s.end_time);
    const dur = Math.floor((et - st) / 60000);
    if (dur <= 0) continue;

    totalMinutes += dur;
    if (dur > longestSessionMinutes) longestSessionMinutes = dur;

    const day = st.getUTCDate();
    if (day >= 1 && day <= daysInMonth) dailyMinutes[day - 1] += dur;

    const wd = st.getUTCDay() === 0 ? 7 : st.getUTCDay(); // 1=Mon..7=Sun
    dayOfWeekTotals[wd] = (dayOfWeekTotals[wd] || 0) + dur;

    const bookId = s.book_id;
    bookMinutes[bookId] = (bookMinutes[bookId] || 0) + dur;
    if (s.books && !bookInfos[bookId]) bookInfos[bookId] = s.books;
  }

  // Best day of week
  let bestDayWeekday = 7;
  let bestDayVal = 0;
  for (const [wd, mins] of Object.entries(dayOfWeekTotals)) {
    if (mins > bestDayVal) {
      bestDayVal = mins;
      bestDayWeekday = parseInt(wd, 10);
    }
  }

  // Top book
  let topBook = undefined;
  const bookEntries = Object.entries(bookMinutes);
  if (bookEntries.length > 0) {
    const [topBookId, topBookMins] = bookEntries.reduce((a, b) => (a[1] >= b[1] ? a : b));
    const info = bookInfos[topBookId];
    topBook = {
      title: info?.title || 'Livre inconnu',
      author: info?.author || '',
      totalMinutes: topBookMins,
    };
  }

  const avgSessionMinutes = sessions.length > 0 ? Math.floor(totalMinutes / sessions.length) : 0;

  // VS last month
  let vsLastMonthPercent = 0;
  if (prevMonthMinutes > 0) {
    vsLastMonthPercent = Math.round(((totalMinutes - prevMonthMinutes) / prevMonthMinutes) * 100);
  } else if (totalMinutes > 0) {
    vsLastMonthPercent = 100;
  }

  // Flow data
  const flowData = await getFlowData(userId, start, end, daysInMonth);

  return {
    month,
    year,
    totalMinutes,
    sessions: sessions.length,
    avgSessionMinutes,
    booksFinished,
    booksInProgress,
    longestSessionMinutes,
    bestDayWeekday,
    longestFlow: flowData.longest,
    currentFlow: flowData.current,
    topBook,
    vsLastMonthPercent,
    dailyMinutes,
    badges,
  };
}

async function getPreviousMonthMinutes(userId, month, year) {
  const prevMonth = month === 1 ? 12 : month - 1;
  const prevYear = month === 1 ? year - 1 : year;
  const prevStart = new Date(Date.UTC(prevYear, prevMonth - 1, 1)).toISOString();
  const prevEnd = new Date(Date.UTC(prevMonth === 12 ? prevYear + 1 : prevYear, prevMonth === 12 ? 0 : prevMonth, 1)).toISOString();

  const { data } = await supabase
    .from('reading_sessions')
    .select('start_time, end_time')
    .eq('user_id', userId)
    .not('end_time', 'is', null)
    .gte('start_time', prevStart)
    .lt('start_time', prevEnd);

  let total = 0;
  for (const s of data || []) {
    total += Math.floor((new Date(s.end_time) - new Date(s.start_time)) / 60000);
  }
  return total;
}

async function getFlowData(userId, start, end, daysInMonth) {
  const { data } = await supabase
    .from('reading_sessions')
    .select('end_time')
    .eq('user_id', userId)
    .not('end_time', 'is', null)
    .gte('start_time', start)
    .lt('start_time', end);

  const readDays = new Set();
  for (const s of data || []) {
    readDays.add(new Date(s.end_time).getUTCDate());
  }

  let longest = 0;
  let current = 0;
  for (let d = 1; d <= daysInMonth; d++) {
    if (readDays.has(d)) {
      current++;
      if (current > longest) longest = current;
    } else {
      current = 0;
    }
  }

  let currentFlow = 0;
  for (let d = daysInMonth; d >= 1; d--) {
    if (readDays.has(d)) {
      currentFlow++;
    } else if (currentFlow > 0) {
      break;
    }
  }

  return { longest, current: currentFlow };
}

async function gatherBookData(userId, bookId) {
  const [bookRes, sessionsRes] = await Promise.all([
    supabase
      .from('user_books')
      .select('book_id, books(title, author, cover_url, total_pages), created_at, updated_at')
      .eq('user_id', userId)
      .eq('book_id', bookId)
      .single(),
    supabase
      .from('reading_sessions')
      .select('start_time, end_time, start_page, end_page')
      .eq('user_id', userId)
      .eq('book_id', bookId)
      .not('end_time', 'is', null)
      .order('start_time'),
  ]);

  const book = bookRes.data;
  const sessions = sessionsRes.data || [];

  let totalMinutes = 0;
  let pagesRead = 0;
  for (const s of sessions) {
    totalMinutes += Math.floor((new Date(s.end_time) - new Date(s.start_time)) / 60000);
    pagesRead += Math.max(0, (s.end_page || 0) - (s.start_page || 0));
  }

  const formatTime = (min) => {
    const h = Math.floor(min / 60);
    const m = min % 60;
    if (h === 0) return `${m}min`;
    return m > 0 ? `${h}h ${m}min` : `${h}h`;
  };

  const formatDate = (iso) => {
    const d = new Date(iso);
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return `${d.getUTCDate()} ${months[d.getUTCMonth()]}`;
  };

  return {
    title: book?.books?.title || 'Livre inconnu',
    author: book?.books?.author || '',
    coverUrl: book?.books?.cover_url || '',
    pagesRead,
    totalPages: book?.books?.total_pages || pagesRead,
    readingTime: formatTime(totalMinutes),
    sessions: sessions.length,
    startDate: sessions.length > 0 ? formatDate(sessions[0].start_time) : '',
    endDate: sessions.length > 0 ? formatDate(sessions[sessions.length - 1].end_time) : '',
    dominantColor: '#D97706',
    secondaryColor: '#92400E',
    seed: bookId,
  };
}

// ── Start server ──────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`readon-sync listening on port ${PORT}`);
});
