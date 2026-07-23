// Creates Firebase Auth accounts for a list of invited emails and prints a
// password-reset link for each new account. Run with the owner's own gcloud
// credentials — no service-account key file needed:
//
//   gcloud auth application-default login --project beyondthefirewall
//   node invite-users.js [path/to/invitees.csv]
//
// invitees.csv: one email per line, optional "email" header row. Idempotent —
// safe to re-run; existing accounts are skipped, not recreated.

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'beyondthefirewall' });

function readEmails(csvPath) {
  const raw = fs.readFileSync(csvPath, 'utf8');
  return raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && line.toLowerCase() !== 'email')
    .filter((line) => line.includes('@'));
}

async function inviteOne(email) {
  try {
    await admin.auth().getUserByEmail(email);
    console.log(`SKIP  (already exists) ${email}`);
    return 'skipped';
  } catch (err) {
    if (err.code !== 'auth/user-not-found') {
      console.error(`ERROR (lookup failed) ${email}: ${err.message}`);
      return 'failed';
    }
  }

  try {
    await admin.auth().createUser({ email, emailVerified: true, disabled: false });
    const link = await admin.auth().generatePasswordResetLink(email);
    console.log(`OK    ${email}`);
    console.log(`      ${link}`);
    return 'created';
  } catch (err) {
    console.error(`ERROR (create failed) ${email}: ${err.message}`);
    return 'failed';
  }
}

async function main() {
  const csvPath = path.resolve(process.argv[2] || path.join(__dirname, 'invitees.csv'));
  if (!fs.existsSync(csvPath)) {
    console.error(`No such file: ${csvPath}`);
    console.error('Copy invitees.example.csv to invitees.csv and fill in real emails first.');
    process.exit(1);
  }

  const emails = readEmails(csvPath);
  console.log(`${emails.length} email(s) to process from ${csvPath}\n`);

  const results = { created: 0, skipped: 0, failed: 0 };
  for (const email of emails) {
    const outcome = await inviteOne(email);
    results[outcome] += 1;
  }

  console.log(`\nDone. Created ${results.created}, skipped ${results.skipped}, failed ${results.failed}.`);
  if (results.failed > 0) process.exitCode = 1;
}

main();
