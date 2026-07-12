# BrickStudio Supabase Setup

1. Create a Supabase project on the Free plan.
2. In Supabase Dashboard, open SQL Editor and run `Backend/supabase_schema.sql`.
3. In Authentication > Providers > Email, disable email confirmation for early testing, or sign-up will require email verification before the app receives a session.
4. In Project Settings > API, copy:
   - Project URL
   - anon public key
5. In Xcode, add build settings to the BrickStudio target:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
6. Create your admin account from the app, then in Supabase SQL Editor run:

```sql
update public.profiles
set role = 'admin'
where email = 'your@email.com';
```

7. Deploy the Instagram feed Edge Function for the Today carousel:

```bash
supabase functions deploy instagram-feed
```

Set the function secrets:

```bash
supabase secrets set INSTAGRAM_ACCESS_TOKEN="your-long-lived-instagram-token"
supabase secrets set INSTAGRAM_USER_ID="your-instagram-business-or-creator-user-id"
```

Optional:

```bash
supabase secrets set INSTAGRAM_GRAPH_VERSION="v23.0"
```

The app will call your Supabase function automatically:

```text
https://your-project.supabase.co/functions/v1/instagram-feed
```

If you want to use a different endpoint, add this Xcode build setting:

```text
INSTAGRAM_FEED_URL
```

Once set, user submissions, admin review, approved articles, feedback, and media upload through Supabase instead of staying only on one device.
