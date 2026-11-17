# How the ICA16 App Works

This app is a Flutter quiz game that connects to Firebase Authentication and Cloud Firestore.

## 1. Starting Up and Signing In
- The app initializes Firebase first.
- The user signs in using an email and password (accounts created in Firebase).
- The user's UID determines their personal storage folder in Firestore (`users/{uid}/attempts/{roundId}`).

## 2. Getting Questions
- The app requests 10 General Knowledge questions from the Open Trivia Database.
- It checks that the HTTP status is 200 and the API response code is 0.
- It decodes HTML special characters (like `&quot;` to `"`) and makes sure there are 4 distinct choices.
- If there is any network or format error, it stops and lets the user retry.

## 3. Playing the Quiz
- Answer choices are shuffled once for each question.
- Tapping an answer locks it in: correct turns green, wrong turns red. You cannot tap again to change your answer or get extra points.
- After question 10, the user reviews all 10 answers and the score is locked in.

## 4. Saving the Score (Cloud Firestore)
- The round gets a unique ID when it starts.
- When saving, a Firestore transaction checks the database first:
  - If the document is missing, it creates it.
  - If it already exists with the same score, it reuses it safely.
  - If it has a different score, it stops and warns of a collision.
- After saving, the app reads the document back directly from the server (`Source.server`) to make sure it is actually saved before showing **Cloud Verified**.

## 5. Handling Errors and Retries
- **Save Unknown:** If a write times out or the connection drops, the app does not call it a failure. It offers a **Reconcile** button to check if the server actually received it.
- **Fault Menu:** A bug icon lets you test different failure scenarios (bad JSON, lost acknowledgement, quota errors, etc.) to prove the app recovers cleanly.
- **Session Protection:** If a user signs out while an operation is in progress, any delayed response is dropped so it does not change the next user's screen.
