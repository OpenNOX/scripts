const { google } = require('googleapis');

const serviceAccountEmail = '';
const privateKey =   '';
const authScopes = ['https://www.googleapis.com/auth/admin.directory.user'];
const adminEmail = '';

const validate = async () => {
  console.log('Initializing client...');
  const client = new google.auth.JWT(
    serviceAccountEmail,
    null,
    privateKey,
    authScopes,
    adminEmail
  );
  console.log('Client initialized!');

  console.log('Fetching token...');
  const { expiry_date } = await client.authorize();
  console.log(`Token fetched! Expires ${expiry_date}`);
};

validate();
