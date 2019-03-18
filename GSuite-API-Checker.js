const { google } = require('googleapis');

const serviceAccountEmail = '';
const privateKey = '';
const authScopes = [
  'https://www.googleapis.com/auth/admin.directory.user',
  'https://www.googleapis.com/auth/classroom.courses'
];
const adminEmail = '';
const domain = adminEmail.split('@')[1];
const customer = '';

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

  let options = { auth: client };
  if (customer) { options = { ...options, customer }; }
  else { options = { ...options, domain }; }

  google.admin('directory_v1').users.list(options, (error, response) => {
    if (error) {
      console.log('DIRECTORY ERROR');
      console.log(error);
    } else {
      console.log('directory_v1 got a successful response');
    }
  });

  google.classroom('v1').courses.list(options, (error, response) => {
    if (error) {
      console.log('CLASSROOM ERROR');
      console.log(error);
    } else {
      console.log('classroom_v1 got  a successful response');
    }
  });
};

validate();
