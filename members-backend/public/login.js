import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, sendPasswordResetEmail } from 'firebase/auth';

// Firebase web config is not secret (it's a public client identifier gated by
// Firebase Auth + the referrer restriction on the API key, not by secrecy).
const firebaseConfig = {
  apiKey: 'AIzaSyBe0jlBRU3Q_UsAR2carLRidwh2rEll_Io',
  authDomain: 'beyondthefirewall.firebaseapp.com',
  projectId: 'beyondthefirewall',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

const form = document.getElementById('login-form');
const errorEl = document.getElementById('login-error');
const infoEl = document.getElementById('login-info');
const submitBtn = document.getElementById('login-submit');
const forgotLink = document.getElementById('forgot-password');

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  errorEl.textContent = '';
  infoEl.textContent = '';
  submitBtn.disabled = true;

  const email = document.getElementById('email').value.trim();
  const password = document.getElementById('password').value;

  try {
    const credential = await signInWithEmailAndPassword(auth, email, password);
    const idToken = await credential.user.getIdToken();

    const response = await fetch('/members/session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken }),
    });

    if (!response.ok) {
      throw new Error('session creation failed');
    }

    const params = new URLSearchParams(window.location.search);
    const next = params.get('next') || '/members/';
    window.location.href = next;
  } catch (err) {
    errorEl.textContent = 'Login failed. Check your email and password.';
    submitBtn.disabled = false;
  }
});

forgotLink.addEventListener('click', async (event) => {
  event.preventDefault();
  errorEl.textContent = '';
  infoEl.textContent = '';

  const email = document.getElementById('email').value.trim();
  if (!email) {
    errorEl.textContent = 'Enter your email above first.';
    document.getElementById('email').focus();
    return;
  }

  try {
    await sendPasswordResetEmail(auth, email);
  } catch (err) {
    if (err.code === 'auth/invalid-email') {
      errorEl.textContent = 'That email address looks invalid.';
      return;
    }
    // Any other error (including "no such account") is intentionally not
    // surfaced differently, to avoid revealing which emails have accounts.
  }

  fetch('/members/forgot-password', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email }),
  }).catch(() => {});

  infoEl.textContent = 'If that email has an account, a reset link has been sent.';
});
