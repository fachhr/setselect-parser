-- ============================================================================
-- URGENT SCHEMA FIX FOR SILVIA'S LIST
-- ============================================================================
--
-- PROBLEM: The cv_parsing_jobs table is missing the extracted_data column
-- that the parser and trigger depend on.
--
-- RUN THIS IN YOUR SUPABASE SQL EDITOR IMMEDIATELY!
-- ============================================================================

BEGIN;

-- Add missing extracted_data column to cv_parsing_jobs table
ALTER TABLE cv_parsing_jobs
  ADD COLUMN IF NOT EXISTS extracted_data JSONB;

-- Verify the fix
DO $$
DECLARE
  col_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'cv_parsing_jobs'
    AND column_name = 'extracted_data'
  ) INTO col_exists;

  IF col_exists THEN
    RAISE NOTICE '✓ SUCCESS: extracted_data column now exists in cv_parsing_jobs';
  ELSE
    RAISE EXCEPTION '✗ FAILED: extracted_data column still missing!';
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- VERIFICATION QUERY
-- ============================================================================
-- Run this after to confirm all columns exist:

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'cv_parsing_jobs'
ORDER BY ordinal_position;

-- Expected columns:
-- 1. id (uuid)
-- 2. profile_id (uuid)
-- 3. status (text)
-- 4. job_type (text)
-- 5. error_message (text)
-- 6. created_at (timestamp with time zone)
-- 7. completed_at (timestamp with time zone)
-- 8. extracted_data (jsonb) ← SHOULD NOW BE PRESENT!
