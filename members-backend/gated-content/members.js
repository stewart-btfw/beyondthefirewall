fetch('/members/whoami')
  .then((res) => res.json())
  .then((data) => {
    if (data.isAdmin) {
      document.getElementById('admin-link').innerHTML = ' &middot; <a href="/members/admin">Admin</a>';
    }
  })
  .catch(() => {});
