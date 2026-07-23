import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';

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
const submitBtn = document.getElementById('login-submit');

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  errorEl.textContent = '';
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
