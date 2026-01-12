# ⚡ START PROCESSING FIX - QUICK START

## What's Wrong?
The "Start Processing" button fails with RLS (Row Level Security) permission errors.

## What to Do?

### 1️⃣ Open Supabase Dashboard
- Go to your Supabase project
- Click **SQL Editor** (left sidebar)

### 2️⃣ Run the Fix
- Click **New Query**
- Copy ALL text from: **`z/BACKEND_FIX_START_PROCESSING.sql`**
- Paste into the editor
- Click **▶️ Run** button
- ✅ Should complete without errors

### 3️⃣ Verify It Worked
Run this query to check policies are in place:
```sql
SELECT tablename, policyname 
FROM pg_policies 
WHERE tablename IN ('tokens', 'token_history') 
ORDER BY tablename;
```

You should see:
- `tokens_update_allow` ← for UPDATE operations
- `token_history_insert_allow` ← for INSERT operations

### 4️⃣ Reload App
- Open your app in browser
- Press **Ctrl+Shift+Delete** (clear cache)
- Refresh page
- Test "Start Processing" button

---

## What Was Fixed?

| Before | After |
|--------|-------|
| ❌ RLS policies missing | ✅ Proper policies created |
| ❌ Staff can't UPDATE tokens | ✅ Staff can change status |
| ❌ Staff can't INSERT history | ✅ Staff can log actions |
| ❌ Generic "permission denied" error | ✅ Clear RLS rules |

---

## If Still Not Working

1. **Check browser console (F12)** for specific error
2. **Run diagnostic query:**
   ```sql
   SELECT id, full_name, role FROM profiles 
   WHERE email = 'your-email@work.com';
   ```
   → Should show `role = 'staff'`

3. **See full guide:** `START_PROCESSING_TROUBLESHOOTING_GUIDE.md`

---

## Files Modified
- ✏️ `z/BACKEND_FIX_START_PROCESSING.sql` — Complete backend fix
- 📄 `z/START_PROCESSING_TROUBLESHOOTING_GUIDE.md` — Detailed guide

Run the SQL file in Supabase and you're done!
