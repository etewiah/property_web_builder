# Firebase Authentication Setup Guide

This guide explains how to configure Firebase authentication for the admin panel.

## Prerequisites

1. A Firebase account (free tier is sufficient)
2. A Firebase project created in the [Firebase Console](https://console.firebase.google.com/)

## Step 1: Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project** (or select an existing project)
3. Follow the setup wizard to create your project
4. Enable **Google Analytics** if desired (optional)

## Step 2: Enable Authentication Methods

1. In your Firebase project, navigate to **Build** → **Authentication**
2. Click **Get started** (if first time)
3. Go to the **Sign-in method** tab
4. Enable the authentication providers you want to use:
   - **Email/Password**: Click on it, toggle **Enable**, click **Save**
   - **Google**: Click on it, toggle **Enable**, provide a project support email, click **Save**

## Step 3: Get Your Firebase Configuration

1. In the Firebase Console, click the **gear icon** ⚙️ next to **Project Overview**
2. Select **Project settings**
3. Scroll down to **Your apps** section
4. If you haven't added a web app yet:
   - Click the **Web** button (`</>`)
   - Register your app with a nickname (e.g., "PropertyWebBuilder Admin")
   - You don't need to set up Firebase Hosting
5. You'll see your Firebase configuration object like this:

```javascript
const firebaseConfig = {
  apiKey: "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  authDomain: "your-project-id.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project-id.appspot.com",
  messagingSenderId: "123456789012",
  appId: "1:123456789012:web:abcdef1234567890"
};
```

## Step 4: Set Environment Variables

Add the following environment variables to your `.env` file in the project root:

```bash
# Firebase Configuration
FIREBASE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
FIREBASE_PROJECT_ID=your-project-id
```

### Required Variables

- **`FIREBASE_API_KEY`**: Your Firebase Web API Key (from `apiKey` in the config)
- **`FIREBASE_PROJECT_ID`**: Your Firebase Project ID (from `projectId` in the config)

### Example

```bash
FIREBASE_API_KEY=AIza...
FIREBASE_PROJECT_ID=property-web-builder-prod
```

## Step 5: Restart Your Rails Server

After setting the environment variables, restart your Rails server:

```bash
# Stop the current server (Ctrl+C)
# Then restart it
rails server
```

## Step 6: Configure Authorized Domains

For production deployments, you need to add your domain to Firebase's authorized domains:

1. In Firebase Console, go to **Authentication** → **Settings** → **Authorized domains**
2. Click **Add domain**
3. Add your production domain (e.g., `app.yourdomain.com`)
4. For development, `localhost` is already authorized by default

## Step 7: Create Your First Admin User

Since this is Firebase authentication, you need to create users in Firebase:

### Option 1: Sign-Up Page (Easiest)

1. Visit `http://localhost:3000/firebase_sign_up`
2. Enter your email address
3. Enter a password (minimum 6 characters)
4. Confirm your password
5. Click **Create Account**
6. The user will be automatically created in both Firebase and your Rails database
7. You'll be redirected to the login page

### Option 2: Firebase Console

1. Go to **Authentication** → **Users** in Firebase Console
2. Click **Add user**
3. Enter email and password
4. Click **Add user**

### Option 3: Google Sign-In

1. Visit `http://localhost:3000/firebase_login`
2. Click **Sign in with Google**
3. Select your Google account
4. The user will be automatically created

### Important: Set Admin Flag

After creating a Firebase user (any method), you need to mark them as an admin in your Rails database:

```ruby
# In Rails console
rails c

# Find the user (after first login)
user = Pwb::User.find_by(email: 'your-admin@example.com')

# Mark as admin
user.update(admin: true)
```

## Account Management Features

### Password Reset

Users can reset their password if they forget it:

1. Visit `http://localhost:3000/firebase_forgot_password`
2. Enter email address
3. Click **Send Reset Link**
4. Check email for password reset link from Firebase
5. Click the link and set a new password
6. Return to login page and sign in with new password

**Note**: Password reset emails are sent by Firebase, not your Rails application.

### Password Change

Logged-in users can change their password:

1. Log in to admin panel
2. Visit `http://localhost:3000/firebase_change_password`
3. Enter current password
4. Enter and confirm new password (min 6 characters)
5. Click **Change Password**
6. Use new password for future logins

## Troubleshooting

### Error: `Firebase: Error (auth/invalid-api-key)`

- **Cause**: `FIREBASE_API_KEY` is not set or is incorrect
- **Solution**: Double-check your `.env` file and ensure the API key matches your Firebase project settings

### Error: `Firebase: Error (auth/project-not-found)`

- **Cause**: `FIREBASE_PROJECT_ID` is incorrect
- **Solution**: Verify the project ID in your Firebase Console project settings

### Users can't sign in

- **Cause**: User might not be marked as admin or might be on wrong subdomain
- **Solution**: 
  1. Check that user exists in your database with `Pwb::User.find_by(email: 'user@example.com')`
  2. Ensure `admin` field is set to `true`
  3. Verify the user's `website_id` matches the current subdomain's website

### Login page shows blank screen

- **Cause**: JavaScript error or missing environment variables
- **Solution**: Check browser console for errors and verify all environment variables are set

## Security Best Practices

1. **Never commit `.env` to version control** - It's already in `.gitignore`
2. **Use different Firebase projects** for development, staging, and production
3. **Rotate API keys** if they are ever exposed
4. **Enable multi-factor authentication** in Firebase Console for added security
5. **Set up Firebase App Check** for production to prevent unauthorized API usage

## Additional Resources

- [Firebase Authentication Docs](https://firebase.google.com/docs/auth)
- [Firebase Console](https://console.firebase.google.com/)
- [FirebaseUI Web Documentation](https://firebase.google.com/docs/auth/web/firebaseui)
