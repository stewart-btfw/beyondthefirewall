import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, updatePassword } from 'firebase/auth';

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

let currentEmail = '';

fetch('/members/whoami')
  .then((res) => res.json())
  .then((data) => {
    currentEmail = data.email || '';
    whoamiEl.textContent = currentEmail ? `Signed in as ${currentEmail}` : '';
  })
  .catch(() => {});

form.addEventListener('submit', async (event) => {
  event.preventDefault();
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
    // devices'). Reissue a fresh one from the still-valid client credential
    // so the user isn't unexpectedly logged out right after this succeeds.
    const idToken = await credential.user.getIdToken(true);
    await fetch('/members/session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken }),
    });

    fetch('/members/account/password-changed', { method: 'POST' }).catch(() => {});

    form.reset();
    infoEl.textContent = 'Password changed.';
  } catch (err) {
    errorEl.textContent = 'Could not change password. Check your current password and try again.';
  } finally {
    submitBtn.disabled = false;
  }
});
