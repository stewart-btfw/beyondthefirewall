const path = require('path');
const express = require('express');
const cookieParser = require('cookie-parser');
const admin = require('firebase-admin');

admin.initializeApp();

const app = express();
app.use(express.json());
app.use(cookieParser());

const COOKIE_NAME = '__session';
const SESSION_EXPIRES_MS = 5 * 24 * 60 * 60 * 1000; // 5 days

const PUBLIC_DIR = path.join(__dirname, 'public');
const GATED_DIR = path.join(__dirname, 'gated-content');

// Login page and its assets (login.html, login.css, dist/login.bundle.js) are always public.
app.get('/members/login', (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'login.html')));
app.get('/members/login.css', (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'login.css')));
app.use('/members/dist', express.static(path.join(PUBLIC_DIR, 'dist')));

app.post('/members/session', async (req, res) => {
  const idToken = req.body && req.body.idToken;
  if (!idToken) {
    return res.status(400).json({ error: 'missing idToken' });
  }

  try {
    await admin.auth().verifyIdToken(idToken);
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
    res.status(200).json({ status: 'ok' });
  } catch (err) {
    console.error('session creation failed:', err);
    res.status(401).json({ error: 'invalid token' });
  }
});

app.get('/members/logout', (req, res) => {
  res.clearCookie(COOKIE_NAME, { path: '/members/' });
  res.redirect('/members/login');
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
