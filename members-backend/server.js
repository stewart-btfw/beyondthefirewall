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

app.use('/members/', requireSession, express.static(GATED_DIR, { index: 'index.html', extensions: ['html'] }));

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`members-backend listening on ${port}`);
});
