const path = require('path');
const express = require('express');
const cookieParser = require('cookie-parser');
const admin = require('firebase-admin');

admin.initializeApp();

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', true); // nginx sets X-Forwarded-For to the real client IP
app.use(express.json());
app.use(cookieParser());

// Holdover from when this service also had a public Cloud Run *.run.app
// URL that nginx's rate limits didn't cover — this header was the only
// thing standing between a direct hit and that gap. Now that the service
// only runs on the Pi behind nginx on localhost (see infra/README.md),
// that specific threat is gone, but the check is harmless to leave in
// place. No-ops (doesn't block anything) if PROXY_SECRET isn't set, so a
// missing/misconfigured secret fails open rather than taking the whole
// members area down.
const PROXY_SECRET = process.env.PROXY_SECRET;
if (PROXY_SECRET) {
  app.use((req, res, next) => {
    if (req.headers['x-proxy-secret'] !== PROXY_SECRET) {
      return res.status(403).send('Forbidden');
    }
    next();
  });
}

// Auth event audit log. Never logs the password or ID token itself —
// only the outcome, so a compromised log can't leak credentials.
function logAuthEvent(fields) {
  console.log(JSON.stringify({ type: 'login_attempt', time: new Date().toISOString(), ...fields }));
}

const COOKIE_NAME = '__session';
const SESSION_EXPIRES_MS = 5 * 24 * 60 * 60 * 1000; // 5 days
const ADMIN_EMAILS = (process.env.ADMIN_EMAILS || '')
  .split(',')
  .map((s) => s.trim().toLowerCase())
  .filter(Boolean);

const PUBLIC_DIR = path.join(__dirname, 'public');
const GATED_DIR = path.join(__dirname, 'gated-content');

// Login page and its assets (login.html, login.css, dist/*.bundle.js) are
// always public. no-store everywhere here: this app is under active
// iteration, and Cloudflare overrides any weaker/absent Cache-Control on
// static-looking extensions with its own multi-hour default, so a short or
// missing maxAge doesn't actually protect against stale cached JS/CSS —
// only no-store reliably does. Revisit with real caching (behind versioned
// filenames) once these stop changing every day.
app.get('/members/login', (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'login.html')));
app.get('/members/login.css', (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  res.sendFile(path.join(PUBLIC_DIR, 'login.css'));
});
app.use('/members/dist', express.static(path.join(PUBLIC_DIR, 'dist'), {
  setHeaders: (res) => res.setHeader('Cache-Control', 'no-store'),
}));

const SESSION_REISSUE_REASONS = {
  password_changed: 'password_changed',
  mfa_enrolled: 'mfa_enrolled',
};

app.post('/members/session', async (req, res) => {
  const idToken = req.body && req.body.idToken;
  // Optional: distinguishes a session *reissue* (after a password change or
  // MFA enrollment, both of which can invalidate the current cookie — see
  // account.js) from an ordinary login, purely for audit-log clarity.
  const reason = req.body && req.body.reason;
  if (!idToken) {
    return res.status(400).json({ error: 'missing idToken' });
  }

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    const sessionCookie = await admin.auth().createSessionCookie(idToken, {
      expiresIn: SESSION_EXPIRES_MS,
    });
    res.cookie(COOKIE_NAME, sessionCookie, {
      maxAge: SESSION_EXPIRES_MS,
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/members/',
    });
    logAuthEvent({
      type: SESSION_REISSUE_REASONS[reason] || 'login_attempt',
      outcome: 'success',
      email: decoded.email,
      ip: req.ip,
    });
    res.status(200).json({ status: 'ok' });
  } catch (err) {
    console.error('session creation failed:', err);
    logAuthEvent({ outcome: 'failure', reason: err.code || err.message, ip: req.ip });
    res.status(401).json({ error: 'invalid token' });
  }
});

app.get('/members/logout', (req, res) => {
  res.clearCookie(COOKIE_NAME, { path: '/members/' });
  res.redirect('/members/login');
});

// Audit-only: the actual reset email is sent client-side via Firebase.
// This just records that a reset was requested for this email.
app.post('/members/forgot-password', (req, res) => {
  const email = req.body && req.body.email;
  logAuthEvent({ type: 'password_reset_requested', email, ip: req.ip });
  res.status(200).json({ status: 'ok' });
});

// Everything else under /members/ requires a valid session cookie.
async function requireSession(req, res, next) {
  const cookie = req.cookies[COOKIE_NAME];
  if (!cookie) {
    return res.redirect(`/members/login?next=${encodeURIComponent(req.originalUrl)}`);
  }
  try {
    req.user = await admin.auth().verifySessionCookie(cookie, true);
    next();
  } catch (err) {
    res.clearCookie(COOKIE_NAME, { path: '/members/' });
    res.redirect(`/members/login?next=${encodeURIComponent(req.originalUrl)}`);
  }
}

function hasMfaEnrolled(userRecord) {
  return !!(userRecord.multiFactor
    && userRecord.multiFactor.enrolledFactors
    && userRecord.multiFactor.enrolledFactors.length > 0);
}

// Applied to every member-only route except the account page itself (and
// its supporting endpoints), which must stay reachable without MFA so an
// unenrolled member can actually get there to enroll one.
async function requireMfa(req, res, next) {
  try {
    const userRecord = await admin.auth().getUser(req.user.uid);
    if (!hasMfaEnrolled(userRecord)) {
      return res.redirect('/members/account?mfa=required');
    }
    next();
  } catch (err) {
    console.error('requireMfa: could not verify MFA status:', err);
    res.status(500).send('Could not verify account security status');
  }
}

function requireAdmin(req, res, next) {
  const email = (req.user && req.user.email || '').toLowerCase();
  if (!ADMIN_EMAILS.includes(email)) {
    return res.status(403).send('Forbidden');
  }
  next();
}

// Account page: change your own password. The change itself happens
// client-side via Firebase after a fresh re-authentication, then the client
// reissues its session via POST /members/session (reason: 'password_changed'),
// which is where this gets audit-logged — see there for why.
app.get('/members/account', requireSession, (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'account.html')));
app.get('/members/account.css', (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  res.sendFile(path.join(PUBLIC_DIR, 'account.css'));
});
app.get('/members/whoami', requireSession, async (req, res) => {
  const email = (req.user.email || '');
  // Looked up fresh (not read off the session cookie's cached claims) so a
  // just-changed display name/MFA status shows immediately, without needing
  // a re-login.
  let displayName = null;
  let mfaEnrolled = false;
  let emailVerified = false;
  try {
    const userRecord = await admin.auth().getUser(req.user.uid);
    displayName = userRecord.displayName || null;
    mfaEnrolled = hasMfaEnrolled(userRecord);
    emailVerified = !!userRecord.emailVerified;
  } catch (err) {
    console.error('whoami: could not look up user record:', err);
  }
  res.status(200).json({
    email,
    uid: req.user.uid,
    ip: req.ip,
    displayName,
    mfaEnrolled,
    emailVerified,
    isAdmin: ADMIN_EMAILS.includes(email.toLowerCase()),
  });
});

app.post('/members/account/display-name', requireSession, async (req, res) => {
  const raw = req.body && req.body.displayName;
  if (typeof raw !== 'string') {
    return res.status(400).json({ error: 'missing displayName' });
  }
  const displayName = raw.trim().slice(0, 100);

  try {
    await admin.auth().updateUser(req.user.uid, { displayName: displayName || null });
    logAuthEvent({ type: 'display_name_changed', email: req.user.email, ip: req.ip });
    res.status(200).json({ status: 'ok', displayName: displayName || null });
  } catch (err) {
    console.error('display name update failed:', err);
    res.status(500).json({ error: 'could not update display name' });
  }
});

// Admin: invite new users and enable/disable existing ones. Gated by
// ADMIN_EMAILS (set via the Cloud Run service's env vars), not a Firebase
// custom claim — simpler to reason about at this scale (a handful of admins).
app.get('/members/admin', requireSession, requireAdmin, requireMfa, (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'admin.html')));
app.get('/members/admin.css', (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  res.sendFile(path.join(PUBLIC_DIR, 'admin.css'));
});

app.get('/members/admin/users', requireSession, requireAdmin, requireMfa, async (req, res) => {
  try {
    const list = await admin.auth().listUsers(1000);
    const users = list.users
      .map((u) => ({
        uid: u.uid,
        email: u.email,
        disabled: u.disabled,
        creationTime: u.metadata.creationTime,
        lastSignInTime: u.metadata.lastSignInTime,
      }))
      .sort((a, b) => (a.email || '').localeCompare(b.email || ''));
    res.status(200).json({ users });
  } catch (err) {
    console.error('list users failed:', err);
    res.status(500).json({ error: 'could not list users' });
  }
});

app.post('/members/admin/invite', requireSession, requireAdmin, requireMfa, async (req, res) => {
  const email = req.body && req.body.email;
  if (!email) {
    return res.status(400).json({ error: 'missing email' });
  }

  try {
    const existing = await admin.auth().getUserByEmail(email).catch((err) => {
      if (err.code === 'auth/user-not-found') return null;
      throw err;
    });

    if (existing) {
      logAuthEvent({ type: 'admin_invite', outcome: 'already_exists', email, by: req.user.email, ip: req.ip });
      return res.status(200).json({ alreadyExisted: true });
    }

    await admin.auth().createUser({ email, emailVerified: true, disabled: false });
    const resetLink = await admin.auth().generatePasswordResetLink(email);
    logAuthEvent({ type: 'admin_invite', outcome: 'created', email, by: req.user.email, ip: req.ip });
    res.status(200).json({ alreadyExisted: false, resetLink });
  } catch (err) {
    console.error('admin invite failed:', err);
    res.status(500).json({ error: 'invite failed' });
  }
});

app.post('/members/admin/toggle-disabled', requireSession, requireAdmin, requireMfa, async (req, res) => {
  const { uid, disabled } = req.body || {};
  if (!uid || typeof disabled !== 'boolean') {
    return res.status(400).json({ error: 'missing uid/disabled' });
  }
  if (uid === req.user.uid && disabled) {
    return res.status(400).json({ error: 'cannot disable your own account' });
  }

  try {
    await admin.auth().updateUser(uid, { disabled });
    logAuthEvent({ type: 'admin_toggle_disabled', uid, disabled, by: req.user.email, ip: req.ip });
    res.status(200).json({ status: 'ok' });
  } catch (err) {
    console.error('toggle disabled failed:', err);
    res.status(500).json({ error: 'could not update user' });
  }
});

// no-store (not just a short/no maxAge) because Cloudflare overrides
// unspecified/short Cache-Control for static-looking extensions with its
// own multi-hour "Browser Cache TTL" default — no-store is the one
// directive it won't override, which matters since this content is under
// active iteration and is gated behind auth anyway (no shared-cache benefit).
app.use('/members/', requireSession, requireMfa, express.static(GATED_DIR, {
  index: 'index.html',
  extensions: ['html'],
  setHeaders: (res) => res.setHeader('Cache-Control', 'no-store'),
}));

const port = process.env.PORT || 8080;
app.listen(port, '127.0.0.1', () => {
  console.log(`members-backend listening on 127.0.0.1:${port}`);
});
