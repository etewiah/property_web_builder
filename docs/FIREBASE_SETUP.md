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

### Option 1: Firebase Console (Recommended for first user)

1. Go to **Authentication** → **Users** in Firebase Console
2. Click **Add user**
3. Enter email and password
4. Click **Add user**

### Option 2: Self-registration via the login page

1. Visit `http://localhost:3000/firebase_login`
2. Click **Sign up** (if using Email/Password provider)
3. Enter your email and password

### Important: Set Admin Flag

After creating a Firebase user, you need to mark them as an admin in your Rails database:

```ruby
# In Rails console
rails c

# Find or create the user (Firebase will auto-create on first login)
# After first login, update the user:
user = Pwb::User.find_by(email: 'your-admin@example.com')
user.update(admin: true)
```

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
