BEGIN;

-- Proficiency mapping: raw value → canonical value
-- Mirrors parser's commonMappings (index.js:559-582) and formOptions.js:384-391
WITH proficiency_map(raw_lower, canonical) AS (
  VALUES
    -- CEFR codes
    ('a1', 'Beginner'), ('a2', 'Beginner'),
    ('b1', 'Intermediate'), ('b2', 'Intermediate'),
    ('c1', 'Advanced'), ('c2', 'Fluent'),
    ('a1-a2', 'Beginner'), ('b1-b2', 'Intermediate'), ('c1-c2', 'Fluent'),
    -- Native / Mother tongue → Native (distinct from Fluent)
    ('mother tongue', 'Native'), ('native', 'Native'), ('native speaker', 'Native'),
    ('langue maternelle', 'Native'), ('muttersprache', 'Native'),
    -- Fluent (high proficiency, not native)
    ('full professional proficiency', 'Fluent'),
    ('courant', 'Fluent'), ('fließend', 'Fluent'),
    -- Advanced
    ('professional', 'Advanced'), ('proficient', 'Advanced'),
    -- Intermediate
    ('professional working proficiency', 'Intermediate'),
    ('limited working proficiency', 'Intermediate'),
    ('conversational', 'Intermediate'), ('working proficiency', 'Intermediate'),
    ('professional working', 'Intermediate'),
    -- Beginner
    ('elementary', 'Beginner'), ('basic', 'Beginner'),
    ('notions', 'Beginner'), ('grundkenntnisse', 'Beginner'),
    -- Case-normalized canonical values
    ('beginner', 'Beginner'), ('intermediate', 'Intermediate'),
    ('advanced', 'Advanced'), ('fluent', 'Fluent'),
    -- Label variants
    ('fluent/native', 'Native'), ('native/fluent', 'Native'),
    ('fluent/native (c2)', 'Native'), ('c2/native', 'Native'),
    ('beginner (a1-a2)', 'Beginner'), ('intermediate (b1-b2)', 'Intermediate'),
    ('advanced (c1)', 'Advanced'), ('fluent (c2)', 'Fluent'),
    -- "None" = no proficiency, remove key
    ('none', NULL)
)
UPDATE user_profiles
SET languages = (
  SELECT COALESCE(jsonb_agg(
    CASE
      -- Dirty values: null, empty, "undefined", "null" → language only
      WHEN elem->>'proficiency' IS NULL
        OR elem->>'proficiency' IN ('', 'undefined', 'null')
        THEN jsonb_build_object('language', elem->>'language')
      -- Mappable synonym → canonical value (or remove if maps to NULL like "None")
      WHEN EXISTS (SELECT 1 FROM proficiency_map pm WHERE pm.raw_lower = LOWER(TRIM(elem->>'proficiency')))
        THEN CASE
          WHEN (SELECT pm.canonical FROM proficiency_map pm WHERE pm.raw_lower = LOWER(TRIM(elem->>'proficiency')) LIMIT 1) IS NULL
            THEN jsonb_build_object('language', elem->>'language')
          ELSE jsonb_build_object('language', elem->>'language',
                                  'proficiency', (SELECT pm.canonical FROM proficiency_map pm WHERE pm.raw_lower = LOWER(TRIM(elem->>'proficiency')) LIMIT 1))
        END
      -- Already valid (exact match) → keep as-is
      WHEN elem->>'proficiency' IN ('Beginner', 'Intermediate', 'Advanced', 'Fluent', 'Native')
        THEN elem
      -- Unknown/unmappable → remove proficiency, keep language
      ELSE jsonb_build_object('language', elem->>'language')
    END
  ORDER BY elem->>'language'), '[]'::jsonb)
  FROM jsonb_array_elements(COALESCE(languages, '[]'::jsonb)) AS elem
)
WHERE languages IS NOT NULL AND jsonb_array_length(languages) > 0;

-- Same for talent_profiles
WITH proficiency_map(raw_lower, canonical) AS (
  VALUES
    ('a1', 'Beginner'), ('a2', 'Beginner'),
    ('b1', 'Intermediate'), ('b2', 'Intermediate'),
    ('c1', 'Advanced'), ('c2', 'Fluent'),
    ('a1-a2', 'Beginner'), ('b1-b2', 'Intermediate'), ('c1-c2', 'Fluent'),
    ('mother tongue', 'Native'), ('native', 'Native'), ('native speaker', 'Native'),
    ('langue maternelle', 'Native'), ('muttersprache', 'Native'),
    ('full professional proficiency', 'Fluent'),
    ('courant', 'Fluent'), ('fließend', 'Fluent'),
    ('professional', 'Advanced'), ('proficient', 'Advanced'),
    ('professional working proficiency', 'Intermediate'),
    ('limited working proficiency', 'Intermediate'),
    ('conversational', 'Intermediate'), ('working proficiency', 'Intermediate'),
    ('professional working', 'Intermediate'),
    ('elementary', 'Beginner'), ('basic', 'Beginner'),
    ('notions', 'Beginner'), ('grundkenntnisse', 'Beginner'),
    ('beginner', 'Beginner'), ('intermediate', 'Intermediate'),
    ('advanced', 'Advanced'), ('fluent', 'Fluent'),
    ('fluent/native', 'Native'), ('native/fluent', 'Native'),
    ('fluent/native (c2)', 'Native'), ('c2/native', 'Native'),
    ('beginner (a1-a2)', 'Beginner'), ('intermediate (b1-b2)', 'Intermediate'),
    ('advanced (c1)', 'Advanced'), ('fluent (c2)', 'Fluent'),
    ('none', NULL)
)
UPDATE talent_profiles
SET languages = (
  SELECT COALESCE(jsonb_agg(
    CASE
      WHEN elem->>'proficiency' IS NULL
        OR elem->>'proficiency' IN ('', 'undefined', 'null')
        THEN jsonb_build_object('language', elem->>'language')
      WHEN EXISTS (SELECT 1 FROM proficiency_map pm WHERE pm.raw_lower = LOWER(TRIM(elem->>'proficiency')))
        THEN CASE
          WHEN (SELECT pm.canonical FROM proficiency_map pm WHERE pm.raw_lower = LOWER(TRIM(elem->>'proficiency')) LIMIT 1) IS NULL
            THEN jsonb_build_object('language', elem->>'language')
          ELSE jsonb_build_object('language', elem->>'language',
                                  'proficiency', (SELECT pm.canonical FROM proficiency_map pm WHERE pm.raw_lower = LOWER(TRIM(elem->>'proficiency')) LIMIT 1))
        END
      WHEN elem->>'proficiency' IN ('Beginner', 'Intermediate', 'Advanced', 'Fluent', 'Native')
        THEN elem
      ELSE jsonb_build_object('language', elem->>'language')
    END
  ORDER BY elem->>'language'), '[]'::jsonb)
  FROM jsonb_array_elements(COALESCE(languages, '[]'::jsonb)) AS elem
)
WHERE languages IS NOT NULL AND jsonb_array_length(languages) > 0;

COMMIT;

-- Verify: both should return 0
SELECT 'user_profiles' AS tbl, COUNT(*) AS dirty_count
FROM user_profiles, jsonb_array_elements(COALESCE(languages, '[]'::jsonb)) AS elem
WHERE elem->>'proficiency' IS NOT NULL
  AND elem->>'proficiency' NOT IN ('Beginner', 'Intermediate', 'Advanced', 'Fluent', 'Native')
UNION ALL
SELECT 'talent_profiles', COUNT(*)
FROM talent_profiles, jsonb_array_elements(COALESCE(languages, '[]'::jsonb)) AS elem
WHERE elem->>'proficiency' IS NOT NULL
  AND elem->>'proficiency' NOT IN ('Beginner', 'Intermediate', 'Advanced', 'Fluent', 'Native');
