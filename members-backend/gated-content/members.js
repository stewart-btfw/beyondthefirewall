fetch('/members/whoami')
  .then((res) => res.json())
  .then((data) => {
    if (data.displayName) {
      const greetingEl = document.getElementById('greeting');
      if (greetingEl) {
        greetingEl.textContent = `You're signed in, ${data.displayName}.`;
      }
    }
    const whoamiEl = document.getElementById('whoami');
    if (whoamiEl) {
      whoamiEl.textContent = `UID: ${data.uid} · Email: ${data.email} · IP: ${data.ip} · Browser: ${navigator.userAgent}`;
    }
    if (data.isAdmin) {
      document.getElementById('admin-link').innerHTML = ' &middot; <a href="/members/admin">Admin</a>';
    }
  })
  .catch(() => {});
