const { google } = require('googleapis');


/*
 * Input Section
 */
const serviceAccountEmail = '';
const privateKey = '';
const adminEmail = '';

// (Optional) If not provided, the calculated `domain` variable is used instead.
const customerId = '';
const domain = adminEmail.split('@')[1];

// (Optional) The most common authorization scopes are already provided by default.
const authScopes = [
  'https://www.googleapis.com/auth/admin.directory.user',
  'https://www.googleapis.com/auth/classroom.courses'
];
/*
 * End of Input Section
 */


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

  let expiry_date;
  try {
    const { expiry_date } = await client.authorize();
  } catch (error) {
    console.log('AUTHORIZATION ERROR; Unable to fetch token!');
    console.log(error);
    return;
  }

  console.log(`Token fetched! Expires ${expiry_date}`);

  let options = { auth: client };
  if (customerId) { options = { ...options, customerId }; }
  else { options = { ...options, domain }; }

  google.admin('directory_v1').users.list(options, (error, response) => {
    if (error) {
      console.log('DIRECTORY ERROR');
      console.log(error);
    } else {
      console.log('directory_v1 got a successful response!');
    }
  });

  google.classroom('v1').courses.list(options, (error, response) => {
    if (error) {
      console.log('CLASSROOM ERROR');
      console.log(error);
    } else {
      console.log('classroom_v1 got a successful response!');
    }
  });
};

validate();
