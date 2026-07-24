const errorEl = document.getElementById('admin-error');
const infoEl = document.getElementById('admin-info');
const tbody = document.getElementById('users-tbody');
const inviteForm = document.getElementById('invite-form');
const inviteSubmit = document.getElementById('invite-submit');

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));
}

async function loadUsers() {
  const res = await fetch('/members/admin/users');
  if (!res.ok) {
    errorEl.textContent = 'Could not load users.';
    return;
  }
  const { users } = await res.json();
  tbody.innerHTML = '';
  for (const u of users) {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${escapeHtml(u.email || '')}</td>
      <td>${u.disabled ? 'Disabled' : 'Active'}</td>
      <td>${u.creationTime ? new Date(u.creationTime).toLocaleDateString() : ''}</td>
      <td>${u.lastSignInTime ? new Date(u.lastSignInTime).toLocaleDateString() : 'Never'}</td>
      <td><button type="button" class="toggle-btn" data-uid="${escapeHtml(u.uid)}" data-disabled="${u.disabled}">${u.disabled ? 'Enable' : 'Disable'}</button></td>
    `;
    tbody.appendChild(tr);
  }
}

tbody.addEventListener('click', async (event) => {
  const btn = event.target.closest('.toggle-btn');
  if (!btn) return;
  errorEl.textContent = '';
  const uid = btn.dataset.uid;
  const disabled = btn.dataset.disabled === 'true';
  btn.disabled = true;
  try {
    const res = await fetch('/members/admin/toggle-disabled', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ uid, disabled: !disabled }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      errorEl.textContent = data.error || 'Could not update user.';
      btn.disabled = false;
      return;
    }
    await loadUsers();
  } catch {
    errorEl.textContent = 'Could not update user.';
    btn.disabled = false;
  }
});

inviteForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  errorEl.textContent = '';
  infoEl.textContent = '';

  const email = document.getElementById('invite-email').value.trim();
  if (!email) return;

  inviteSubmit.disabled = true;
  try {
    const res = await fetch('/members/admin/invite', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      errorEl.textContent = data.error || 'Could not invite user.';
      return;
    }
    infoEl.textContent = data.alreadyExisted
      ? `${email} already has an account.`
      : `Invited. Reset link: ${data.resetLink}`;
    inviteForm.reset();
    await loadUsers();
  } catch {
    errorEl.textContent = 'Could not invite user.';
  } finally {
    inviteSubmit.disabled = false;
  }
});

loadUsers();
