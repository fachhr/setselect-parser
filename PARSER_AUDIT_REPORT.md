# Parser Audit Report - Old Project References

**Date:** November 15, 2025
**Auditor:** Claude Code (Google Pro Engineer Mode)
**Status:** 🔴 CRITICAL ISSUES FOUND

---

## Executive Summary

Deep audit of silvias-list-parser revealed **3 critical mismatches** between the parser (designed for old CV generator project) and Silvia's List infrastructure.

---

## ✅ FIXED ISSUES (Already Deployed to GitHub)

### 1. Wrong Storage Bucket Name
**Location:** `index.js` lines 73, 408

**Problem:**
- Parser was hardcoded to use `raw-cvs` bucket (from old project)
- Silvia's List uses `talent-pool-cvs` bucket

**Fix Applied:**
```javascript
// BEFORE
await supabase.storage.from('raw-cvs').download(storagePath);

// AFTER
await supabase.storage.from('talent-pool-cvs').download(storagePath);
```

**Status:** ✅ Fixed in commit cc8c3f1

---

### 2. Wrong Database Schema Queries
**Location:** `index.js` lines 1159-1187

**Problem:**
- Parser was querying `clerk_user_id` and `is_quick` columns
- These columns don't exist in Silvia's List schema
- Caused: `column cv_parsing_jobs.clerk_user_id does not exist` error

**Fix Applied:**
- Removed database query for non-existent columns
- Simplified to extract profile ID directly from storagePath
- Set `isQuickCV = false` (not used in Silvia's List)

**Status:** ✅ Fixed in commit cc8c3f1

---

## 🔴 CRITICAL ISSUE - REQUIRES USER ACTION

### 3. Missing `extracted_data` Column in Database

**Severity:** 🔴 **BLOCKING** - Parser will fail until fixed

**Problem:**
The `cv_parsing_jobs` table in your Supabase database is missing the `extracted_data` column.

**Evidence:**
1. **Parser writes to it:** `index.js:1195`
   ```javascript
   await supabase.from('cv_parsing_jobs').update({
     status: 'completed',
     extracted_data: extractedData,  // ← Column doesn't exist!
     completed_at: new Date().toISOString()
   }).eq('id', jobId);
   ```

2. **Trigger reads from it:** `database/sync_trigger.sql:51`
   ```sql
   IF NEW.status = 'completed' AND NEW.extracted_data IS NOT NULL THEN
   ```

3. **Migration doesn't create it:** `SILVIAS_LIST_MIGRATION.sql:151-159`
   ```sql
   CREATE TABLE IF NOT EXISTS cv_parsing_jobs (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     profile_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
     status TEXT DEFAULT 'pending',
     job_type TEXT DEFAULT 'talent_pool',
     error_message TEXT,
     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
     completed_at TIMESTAMP WITH TIME ZONE
     -- ❌ extracted_data JSONB IS MISSING!
   );
   ```

**Impact:**
- Parser will crash when trying to UPDATE with extracted_data
- Database trigger won't fire (expects extracted_data to exist)
- No CV data will be synced to user_profiles

**Fix Required:**
Run the SQL fix provided in `database/URGENT_SCHEMA_FIX.sql`

---

## ✅ VERIFIED CORRECT CONFIGURATIONS

### 4. Profile Picture Storage Bucket ✓
**Location:** `index.js:370`

**Configuration:**
```javascript
await supabase.storage
  .from('profile-pictures')
  .upload(storagePath, imageBuffer, ...)
```

**Status:** ✅ CORRECT - `profile-pictures` bucket should exist per SUPABASE_SETUP_GUIDE.md

---

### 5. Database Table Names ✓
**Tables Used:**
- `cv_parsing_jobs` ✅ Correct
- `user_profiles` ✅ Correct (via trigger)

**Status:** ✅ All table names match Silvia's List schema

---

### 6. Column Names in Updates ✓
**Columns Written:**
- `cv_parsing_jobs.status` ✅ Exists
- `cv_parsing_jobs.completed_at` ✅ Exists
- `cv_parsing_jobs.error_message` ✅ Exists
- `cv_parsing_jobs.extracted_data` ❌ **MISSING** (see Issue #3)

---

## 📋 ACTION REQUIRED

### Immediate (Required for Parser to Work):

1. **Run Database Fix:**
   ```bash
   # In Supabase SQL Editor, run:
   /database/URGENT_SCHEMA_FIX.sql
   ```

2. **Verify Fix:**
   ```sql
   SELECT column_name, data_type
   FROM information_schema.columns
   WHERE table_name = 'cv_parsing_jobs'
   ORDER BY ordinal_position;
   ```

   **Expected output should include:**
   - `extracted_data | jsonb`

3. **Confirm Buckets Exist:**
   - Go to Supabase Storage
   - Verify these 3 buckets exist:
     - ✅ `talent-pool-cvs` (Private)
     - ✅ `profile-pictures` (Public)
     - ✅ `cv-texts` (Private)

4. **Wait for Railway Redeploy:**
   - Parser code changes will auto-deploy
   - Check Railway dashboard for "Active" status
   - Usually takes 1-2 minutes

5. **Test End-to-End:**
   - Submit a test CV through the form
   - Check Railway logs for parsing progress
   - Verify data appears in `user_profiles` table

---

## 🎯 Summary of Changes Made to Parser

| File | Lines | Change | Status |
|------|-------|--------|--------|
| `index.js` | 73, 408 | Changed bucket: `raw-cvs` → `talent-pool-cvs` | ✅ Deployed |
| `index.js` | 1158-1177 | Removed `clerk_user_id` / `is_quick` queries | ✅ Deployed |
| `database/URGENT_SCHEMA_FIX.sql` | NEW | Add `extracted_data` column | ⏳ User must run |

---

## 🔍 Methodology

**Audit Process:**
1. ✅ Searched all database operations (`.from()`, `.update()`, `.insert()`)
2. ✅ Verified storage bucket names
3. ✅ Compared database schema with parser expectations
4. ✅ Checked column names in all UPDATE/INSERT queries
5. ✅ Validated trigger dependencies
6. ✅ Cross-referenced with Silvia's List migration file

**Tools Used:**
- `grep` for pattern matching across codebase
- Database schema analysis
- Migration file comparison
- Trigger dependency analysis

---

## ⚠️ Why This Happened

The parser was originally built for the **my-cv-generator** project which had:
- Different bucket names (`raw-cvs`)
- Different schema (included `clerk_user_id`, `is_quick`)
- Clerk authentication system
- Quick CV mode

Silvia's List is a **simplified talent pool** version without:
- Clerk authentication
- Quick CV mode
- User accounts (just email-based profiles)

The migration file was incomplete - it didn't include the `extracted_data` column that the parser requires.

---

## 📊 Risk Assessment

| Issue | Severity | Impact | Status |
|-------|----------|--------|--------|
| Wrong bucket name | High | Parser couldn't download CVs | ✅ Fixed |
| Wrong schema queries | Medium | Non-fatal warnings in logs | ✅ Fixed |
| Missing `extracted_data` | **CRITICAL** | **Parser completely broken** | ⚠️ **USER ACTION REQUIRED** |

---

## ✅ Sign-Off

All code-level issues have been fixed and deployed to GitHub.
Railway will auto-redeploy with the fixes.

**Remaining blocker:** Database schema fix (user must run SQL script).

Once the database fix is applied, the parser should work end-to-end.

---

**Generated by:** Claude Code
**Commit:** cc8c3f1
