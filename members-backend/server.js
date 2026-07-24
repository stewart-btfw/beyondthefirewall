const path = require('path');
const express = require('express');
const cookieParser = require('cookie-parser');
const admin = require('firebase-admin');

admin.initializeApp();

const app = express();
app.set('trust proxy', true); // nginx sets X-Forwarded-For to the real client IP
app.use(express.json());
app.use(cookieParser());

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

// Login page and its assets (login.html, login.css, dist/login.bundle.js) are always public.
// The HTML itself stays uncached; the CSS/JS behind it rarely change once published.
app.get('/members/login', (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'login.html')));
app.get('/members/login.css', (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'login.css'), { maxAge: '1d' }));
app.use('/members/dist', express.static(path.join(PUBLIC_DIR, 'dist'), { maxAge: '1d' }));

app.post('/members/session', async (req, res) => {
  const idToken = req.body && req.body.idToken;
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
    logAuthEvent({ outcome: 'success', email: decoded.email, ip: req.ip });
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

function requireAdmin(req, res, next) {
  const email = (req.user && req.user.email || '').toLowerCase();
  if (!ADMIN_EMAILS.includes(email)) {
    return res.status(403).send('Forbidden');
  }
  next();
}

// Account page: change your own password. The change itself happens
// client-side via Firebase after a fresh re-authentication; this endpoint
// only audit-logs that it happened.
app.get('/members/account', requireSession, (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'account.html')));
app.get('/members/account.css', (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'account.css'), { maxAge: '1d' }));
app.get('/members/whoami', requireSession, (req, res) => res.status(200).json({ email: req.user.email }));
app.post('/members/account/password-changed', requireSession, (req, res) => {
  logAuthEvent({ type: 'password_changed', email: req.user.email, ip: req.ip });
  res.status(200).json({ status: 'ok' });
});

// Admin: invite new users and enable/disable existing ones. Gated by
// ADMIN_EMAILS (set via the Cloud Run service's env vars), not a Firebase
// custom claim — simpler to reason about at this scale (a handful of admins).
app.get('/members/admin', requireSession, requireAdmin, (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'admin.html')));
app.get('/members/admin.css', (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'admin.css'), { maxAge: '1d' }));

app.get('/members/admin/users', requireSession, requireAdmin, async (req, res) => {
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

app.post('/members/admin/invite', requireSession, requireAdmin, async (req, res) => {
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

app.post('/members/admin/toggle-disabled', requireSession, requireAdmin, async (req, res) => {
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

app.use('/members/', requireSession, express.static(GATED_DIR, { index: 'index.html', extensions: ['html'] }));

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`members-backend listening on ${port}`);
});
