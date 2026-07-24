fetch('/members/whoami')
  .then((res) => res.json())
  .then((data) => {
    const whoamiEl = document.getElementById('whoami');
    if (whoamiEl) {
      whoamiEl.textContent = `UID: ${data.uid} · Email: ${data.email} · IP: ${data.ip}`;
    }
    if (data.isAdmin) {
      document.getElementById('admin-link').innerHTML = ' &middot; <a href="/members/admin">Admin</a>';
    }
  })
  .catch(() => {});
