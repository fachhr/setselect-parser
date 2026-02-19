-- Fix malformed language entries where proficiency was baked into the language name
-- e.g. "English · Fluent" → {"language": "English", "proficiency": "Fluent"}
-- e.g. "English · undefined" → {"language": "English"}
-- Affects ~12 profiles in both user_profiles and talent_profiles

-- Fix user_profiles
UPDATE user_profiles
SET languages = (
  SELECT COALESCE(jsonb_agg(fixed ORDER BY fixed->>'language'), '[]'::jsonb)
  FROM (
    SELECT DISTINCT ON (fixed) fixed
    FROM (
      SELECT
        CASE
          WHEN elem->>'language' LIKE '%·%' THEN
            CASE
              WHEN SPLIT_PART(elem->>'language', ' · ', 2) = 'undefined'
                THEN jsonb_build_object('language', TRIM(SPLIT_PART(elem->>'language', ' · ', 1)))
                ELSE jsonb_build_object('language', TRIM(SPLIT_PART(elem->>'language', ' · ', 1)),
                                       'proficiency', TRIM(SPLIT_PART(elem->>'language', ' · ', 2)))
            END
          ELSE elem
        END AS fixed
      FROM jsonb_array_elements(COALESCE(languages, '[]'::jsonb)) AS elem
    ) raw
  ) deduped
)
WHERE EXISTS (
  SELECT 1 FROM jsonb_array_elements(COALESCE(languages, '[]'::jsonb)) AS elem
  WHERE elem->>'language' LIKE '%·%'
);

-- Fix talent_profiles
UPDATE talent_profiles
SET languages = (
  SELECT COALESCE(jsonb_agg(fixed ORDER BY fixed->>'language'), '[]'::jsonb)
  FROM (
    SELECT DISTINCT ON (fixed) fixed
    FROM (
      SELECT
        CASE
          WHEN elem->>'language' LIKE '%·%' THEN
            CASE
              WHEN SPLIT_PART(elem->>'language', ' · ', 2) = 'undefined'
                THEN jsonb_build_object('language', TRIM(SPLIT_PART(elem->>'language', ' · ', 1)))
                ELSE jsonb_build_object('language', TRIM(SPLIT_PART(elem->>'language', ' · ', 1)),
                                       'proficiency', TRIM(SPLIT_PART(elem->>'language', ' · ', 2)))
            END
          ELSE elem
        END AS fixed
      FROM jsonb_array_elements(COALESCE(languages, '[]'::jsonb)) AS elem
    ) raw
  ) deduped
)
WHERE EXISTS (
  SELECT 1 FROM jsonb_array_elements(COALESCE(languages, '[]'::jsonb)) AS elem
  WHERE elem->>'language' LIKE '%·%'
);

-- Verify: both should return 0
SELECT 'user_profiles' AS table_name, COUNT(*) AS malformed_count FROM user_profiles
WHERE EXISTS (
  SELECT 1 FROM jsonb_array_elements(COALESCE(languages, '[]'::jsonb)) AS elem
  WHERE elem->>'language' LIKE '%·%'
)
UNION ALL
SELECT 'talent_profiles', COUNT(*) FROM talent_profiles
WHERE EXISTS (
  SELECT 1 FROM jsonb_array_elements(COALESCE(languages, '[]'::jsonb)) AS elem
  WHERE elem->>'language' LIKE '%·%'
);
