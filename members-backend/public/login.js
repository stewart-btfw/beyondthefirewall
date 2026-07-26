import { initializeApp } from 'firebase/app';
import {
  getAuth,
  signInWithEmailAndPassword,
  sendPasswordResetEmail,
  getMultiFactorResolver,
  TotpMultiFactorGenerator,
} from 'firebase/auth';

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

const mfaForm = document.getElementById('mfa-form');
const mfaErrorEl = document.getElementById('mfa-login-error');
const mfaSubmitBtn = document.getElementById('mfa-login-submit');

let pendingResolver = null;

async function completeLogin(user) {
  const idToken = await user.getIdToken();

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
}

async function login() {
  errorEl.textContent = '';
  infoEl.textContent = '';
  submitBtn.disabled = true;

  const email = document.getElementById('email').value.trim();
  const password = document.getElementById('password').value;

  try {
    const credential = await signInWithEmailAndPassword(auth, email, password);
    await completeLogin(credential.user);
  } catch (err) {
    if (err.code === 'auth/multi-factor-auth-required') {
      pendingResolver = getMultiFactorResolver(auth, err);
      form.classList.add('hidden');
      mfaForm.classList.remove('hidden');
      infoEl.textContent = '';
      submitBtn.disabled = false;
      return;
    }
    errorEl.textContent = 'Login failed. Check your email and password.';
    submitBtn.disabled = false;
  }
}

async function submitMfaCode() {
  mfaErrorEl.textContent = '';

  const code = document.getElementById('mfa-login-code').value.trim();
  if (!pendingResolver || !code) {
    mfaErrorEl.textContent = 'Enter the 6-digit code from your authenticator app.';
    return;
  }

  mfaSubmitBtn.disabled = true;
  try {
    const hint = pendingResolver.hints.find((h) => h.factorId === TotpMultiFactorGenerator.FACTOR_ID);
    const assertion = TotpMultiFactorGenerator.assertionForSignIn(hint.uid, code);
    const userCredential = await pendingResolver.resolveSignIn(assertion);
    await completeLogin(userCredential.user);
  } catch (err) {
    mfaErrorEl.textContent = 'Invalid code. Try again.';
    mfaSubmitBtn.disabled = false;
  }
}

mfaSubmitBtn.addEventListener('click', submitMfaCode);
mfaForm.addEventListener('submit', (event) => {
  event.preventDefault();
  submitMfaCode();
});

// The button is type="button" (not "submit") so a click can never fall back
// to a native form submission if this listener is ever slow to attach — the
// submit listener below only exists as a safety net for pressing Enter in
// a field, and preventDefault()s immediately either way.
submitBtn.addEventListener('click', login);
form.addEventListener('submit', (event) => {
  event.preventDefault();
  login();
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
