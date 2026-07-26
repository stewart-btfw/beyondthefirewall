import { initializeApp } from 'firebase/app';
import {
  getAuth,
  signInWithEmailAndPassword,
  updatePassword,
  multiFactor,
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

const whoamiEl = document.getElementById('whoami');
const form = document.getElementById('password-form');
const errorEl = document.getElementById('account-error');
const infoEl = document.getElementById('account-info');
const submitBtn = document.getElementById('account-submit');

const nameForm = document.getElementById('displayname-form');
const nameInput = document.getElementById('display-name');
const nameErrorEl = document.getElementById('displayname-error');
const nameInfoEl = document.getElementById('displayname-info');
const nameSubmitBtn = document.getElementById('displayname-submit');

const mfaCurrentStatusEl = document.getElementById('mfa-current-status');
const mfaStartForm = document.getElementById('mfa-start-form');
const mfaStartErrorEl = document.getElementById('mfa-start-error');
const mfaStartSubmitBtn = document.getElementById('mfa-start-submit');
const mfaVerifyForm = document.getElementById('mfa-verify-form');
const mfaSecretKeyEl = document.getElementById('mfa-secret-key');
const mfaVerifyErrorEl = document.getElementById('mfa-verify-error');
const mfaVerifyInfoEl = document.getElementById('mfa-verify-info');
const mfaVerifySubmitBtn = document.getElementById('mfa-verify-submit');

let currentEmail = '';
let enrolledUser = null; // set once re-auth succeeds in startMfaEnrollment()
let pendingTotpSecret = null;

fetch('/members/whoami')
  .then((res) => res.json())
  .then((data) => {
    currentEmail = data.email || '';
    whoamiEl.textContent = currentEmail ? `Signed in as ${currentEmail}` : '';
    nameInput.value = data.displayName || '';
    mfaCurrentStatusEl.textContent = data.mfaEnrolled
      ? 'Two-factor authentication is currently enabled on this account.'
      : 'Two-factor authentication is not currently enabled on this account.';
    if (data.mfaEnrolled) {
      mfaStartForm.style.display = 'none';
    } else if (new URLSearchParams(window.location.search).get('mfa') === 'required') {
      mfaStartErrorEl.textContent = 'Two-factor authentication is required for admin accounts. Set it up below to continue.';
    }
  })
  .catch(() => {});

async function saveDisplayName() {
  nameErrorEl.textContent = '';
  nameInfoEl.textContent = '';

  nameSubmitBtn.disabled = true;
  try {
    const res = await fetch('/members/account/display-name', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ displayName: nameInput.value }),
    });
    if (!res.ok) throw new Error('failed');
    nameInfoEl.textContent = 'Name saved.';
  } catch (err) {
    nameErrorEl.textContent = 'Could not save name. Try again.';
  } finally {
    nameSubmitBtn.disabled = false;
  }
}

// The button is type="button" (not "submit") so a click can never fall back
// to a native form submission if this listener is ever slow to attach — the
// submit listener below only exists as a safety net for pressing Enter in
// the field, and preventDefault()s immediately either way.
nameSubmitBtn.addEventListener('click', saveDisplayName);
nameForm.addEventListener('submit', (event) => {
  event.preventDefault();
  saveDisplayName();
});

async function changePassword() {
  errorEl.textContent = '';
  infoEl.textContent = '';

  const currentPassword = document.getElementById('current-password').value;
  const newPassword = document.getElementById('new-password').value;
  const confirmPassword = document.getElementById('confirm-password').value;

  if (newPassword !== confirmPassword) {
    errorEl.textContent = 'New passwords do not match.';
    return;
  }
  if (!currentEmail) {
    errorEl.textContent = 'Could not determine your account. Try reloading the page.';
    return;
  }

  submitBtn.disabled = true;
  try {
    // Firebase requires a fresh sign-in (not just our session cookie) before
    // allowing a sensitive change like a password update.
    const credential = await signInWithEmailAndPassword(auth, currentEmail, currentPassword);
    await updatePassword(credential.user, newPassword);

    // Changing the password bumps Firebase's revocation timestamp, which
    // invalidates our *current* session cookie too (not just other
    // devices'). A mere token refresh can still race with that timestamp,
    // so sign in fresh with the new password to get a token unambiguously
    // issued after it, and use that to reissue a valid session cookie.
    const freshCredential = await signInWithEmailAndPassword(auth, currentEmail, newPassword);
    const idToken = await freshCredential.user.getIdToken();
    await fetch('/members/session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken, reason: 'password_changed' }),
    });

    form.reset();
    infoEl.textContent = 'Password changed.';
  } catch (err) {
    errorEl.textContent = 'Could not change password. Check your current password and try again.';
  } finally {
    submitBtn.disabled = false;
  }
}

submitBtn.addEventListener('click', changePassword);
form.addEventListener('submit', (event) => {
  event.preventDefault();
  changePassword();
});

async function startMfaEnrollment() {
  mfaStartErrorEl.textContent = '';
  const currentPassword = document.getElementById('mfa-current-password').value;
  if (!currentEmail || !currentPassword) {
    mfaStartErrorEl.textContent = 'Enter your current password first.';
    return;
  }

  mfaStartSubmitBtn.disabled = true;
  try {
    // Enrolling a second factor is a sensitive change, same as a password
    // update — Firebase requires a fresh sign-in first.
    const credential = await signInWithEmailAndPassword(auth, currentEmail, currentPassword);
    enrolledUser = credential.user;

    const session = await multiFactor(enrolledUser).getSession();
    pendingTotpSecret = await TotpMultiFactorGenerator.generateSecret(session);

    mfaSecretKeyEl.textContent = pendingTotpSecret.secretKey;
    mfaStartForm.style.display = 'none';
    mfaVerifyForm.style.display = 'block';
  } catch (err) {
    mfaStartErrorEl.textContent = 'Could not start setup. Check your current password and try again.';
  } finally {
    mfaStartSubmitBtn.disabled = false;
  }
}

async function verifyMfaEnrollment() {
  mfaVerifyErrorEl.textContent = '';
  mfaVerifyInfoEl.textContent = '';

  const code = document.getElementById('mfa-code').value.trim();
  if (!enrolledUser || !pendingTotpSecret || !code) {
    mfaVerifyErrorEl.textContent = 'Enter the 6-digit code from your authenticator app.';
    return;
  }

  mfaVerifySubmitBtn.disabled = true;
  try {
    const assertion = TotpMultiFactorGenerator.assertionForEnrollment(pendingTotpSecret, code);
    await multiFactor(enrolledUser).enroll(assertion, 'Authenticator app');

    // Reissue the session so the server's mfaEnrolled/requireAdmin checks
    // (which read a fresh admin.auth().getUser() lookup, not cookie claims)
    // see the new factor immediately, without a re-login.
    const idToken = await enrolledUser.getIdToken(true);
    await fetch('/members/session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken, reason: 'mfa_enrolled' }),
    });

    mfaVerifyInfoEl.textContent = 'Two-factor authentication enabled.';
    mfaVerifyForm.style.display = 'none';
    mfaCurrentStatusEl.textContent = 'Two-factor authentication is currently enabled on this account.';
  } catch (err) {
    mfaVerifyErrorEl.textContent = 'Invalid code. Try again.';
  } finally {
    mfaVerifySubmitBtn.disabled = false;
  }
}

mfaStartSubmitBtn.addEventListener('click', startMfaEnrollment);
mfaStartForm.addEventListener('submit', (event) => {
  event.preventDefault();
  startMfaEnrollment();
});

mfaVerifySubmitBtn.addEventListener('click', verifyMfaEnrollment);
mfaVerifyForm.addEventListener('submit', (event) => {
  event.preventDefault();
  verifyMfaEnrollment();
});
