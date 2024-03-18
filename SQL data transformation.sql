-- Function to process titles by removing specified delimiters and last characters
CREATE OR REPLACE FUNCTION process_title(input_title VARCHAR, delimiter_list VARCHAR[]) RETURNS VARCHAR AS $$
DECLARE
    delimiter_value VARCHAR; -- Variable to hold each delimiter value
    last_char VARCHAR; -- Variable to hold the last character of the title
    modified_title VARCHAR := input_title; -- Initialize modified title with the input title
BEGIN
    -- Check for each delimiter in the delimiter list
    FOR delimiter_value IN SELECT unnest(delimiter_list)
    LOOP
        -- If delimiter found in the modified title, split and return the modified title
        IF POSITION(delimiter_value IN modified_title) > 0 THEN
            modified_title := SPLIT_PART(modified_title, delimiter_value, 1);
            RETURN modified_title; -- Return the modified title
        END IF;
    END LOOP;

    -- Check the last character of the title
    last_char := RIGHT(TRIM(modified_title), 1);
    -- If the last character is a digit, remove it and return the modified title
    IF last_char BETWEEN '1' AND '9' THEN
        RETURN SPLIT_PART(TRIM(modified_title), last_char, 1);
    END IF;

    -- If no modification made, return the original title
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Common Table Expressions to process anime data
WITH new_anime AS (
    -- CTE to preprocess anime data
    SELECT
        uid,
        title,
        synopsis,
        genre,
        aired,
        episodes,
        members,
        popularity,
        ranking,
        score,
        img_link,
        link,
        s_date,
        startyear,
        e_date,
        endyear,
        CASE 
            -- Calculate duration in days if start and end dates available
            WHEN s_date IS NULL AND episodes = 1 THEN 0
            ELSE e_date - s_date
        END AS duration_day,
        CASE 
            -- Calculate duration in months if start and end dates available
            WHEN s_date IS NULL AND episodes = 1 THEN 0
            ELSE (endyear - startyear) * 12 + 
                 (Date_part('Month', e_date) - Date_part('Month', s_date))
        END AS duration_month,
        ROUND(
            -- Calculate duration in years if start and end dates available
            CASE 
                WHEN s_date IS NULL AND episodes = 1 THEN 0
                ELSE (e_date - s_date) / 365.0
            END,
            2
        ) AS duration_year
    FROM (
        -- Subquery to preprocess data and calculate start and end dates
        SELECT
            *,
            endyear - startyear AS duration_y,
            CASE 
                -- Extract start date month if available
                WHEN s_month IS NULL THEN NULL
                ELSE TO_DATE(
                    CONCAT(
                        CASE 
                            WHEN s_day IS NULL THEN '01'
                            WHEN s_day < 10 THEN CONCAT('0', s_day)
                            ELSE CAST(s_day AS TEXT)
                        END,
                        s_month,
                        startyear
                    ),
                    'DDMonYYYY'
                )
            END AS s_date,
            CASE 
                -- Extract end date month if available
                WHEN e_month IS NULL THEN NULL
                ELSE TO_DATE(
                    CONCAT(
                        CASE 
                            WHEN e_day IS NULL THEN '01'
                            WHEN e_day < 10 THEN CONCAT('0', e_day)
                            ELSE CAST(e_day AS TEXT)
                        END,
                        e_month,
                        endyear
                    ),
                    'DDMonYYYY'
                )
            END AS e_date
        FROM (
            -- Subquery to split and preprocess aired data
            SELECT
                *,
                CASE 
                    -- Extract start year from aired data
                    WHEN trim(split_part(aired, 'to', 1)) = '?' OR 
                         trim(split_part(aired, 'to', 1)) LIKE 'Not available' THEN NULL
                    ELSE CAST(RIGHT(trim(split_part(aired, 'to', 1)), 4) AS INT)
                END AS startyear,
                CASE 
                    -- Handle single-episode anime with missing end year
                    WHEN episodes = 1 AND trim(split_part(aired, 'to', 2)) = '' THEN (
                        CASE 
                            WHEN trim(split_part(aired, 'to', 1)) = '?' OR 
                                 trim(split_part(aired, 'to', 1)) LIKE 'Not available' THEN NULL
                            ELSE CAST(RIGHT(trim(split_part(aired, 'to', 1)), 4) AS INT)
                        END
                    )
                    WHEN trim(split_part(aired, 'to', 2)) = '?' OR 
                         trim(split_part(aired, 'to', 2)) = '' THEN NULL
                    ELSE CAST(RIGHT(trim(split_part(aired, 'to', 2)), 4) AS INT)
                END AS endyear,
                CASE 
                    -- Extract start month from aired data
                    WHEN LENGTH(trim(split_part(aired, 'to', 1))) > 4 AND 
                         LENGTH(trim(split_part(aired, 'to', 1))) < 13 THEN LEFT(split_part(aired, 'to', 1), 3)
                    ELSE NULL
                END AS s_month,
                CASE 
                    -- Extract start day from aired data
                    WHEN LENGTH(trim(split_part(aired, 'to', 1))) > 9 AND 
                         LENGTH(trim(split_part(aired, 'to', 1))) < 13 THEN 
                        CAST(TRIM(RIGHT(TRIM(split_part(split_part(aired, 'to', 1), ',', 1)), 2)) AS INT)
                    ELSE NULL
                END AS s_day,
                CASE 
                    -- Handle single-episode anime with missing end month
                    WHEN episodes = 1 AND trim(split_part(aired, 'to', 2)) = '' THEN (
                        CASE 
                            WHEN LENGTH(trim(split_part(aired, 'to', 1))) > 4 AND 
                                 LENGTH(trim(split_part(aired, 'to', 1))) < 13 THEN LEFT(split_part(aired, 'to', 1), 3)
                            ELSE NULL
                        END
                    )
                    WHEN LENGTH(trim(split_part(aired, 'to', 2))) > 4 AND 
                         LENGTH(trim(split_part(aired, 'to', 2))) < 13 THEN LEFT(trim(split_part(aired, 'to', 2)), 3)
                    ELSE NULL
                END AS e_month,
                CASE 
                    -- Handle single-episode anime with missing end day
                    WHEN episodes = 1 AND trim(split_part(aired, 'to', 2)) = '' THEN (
                        CASE 
                            WHEN LENGTH(trim(split_part(aired, 'to', 1))) > 9 AND 
                                 LENGTH(trim(split_part(aired, 'to', 1))) < 13 THEN 
                                CAST(TRIM(RIGHT(TRIM(split_part(split_part(aired, 'to', 1), ',', 1)), 2)) AS INT)
                            ELSE NULL
                        END
                    )
                    WHEN LENGTH(trim(split_part(aired, 'to', 2)) THEN 
                        CAST(TRIM(RIGHT(TRIM(split_part(split_part(aired, 'to', 2), ',', 1)), 2)) AS INT)
                    ELSE NULL
                END AS e_day
            FROM anime
        ) AS a
    ) AS b
),
preseason AS (
    -- CTE to identify if an anime has a pre-season or other seasons
    SELECT 
        DISTINCT
        mm.uid,
        mm.title,
        CASE 
            -- Check if there is a next anime entry, indicating a pre-season
            WHEN next_uid IS NOT NULL THEN 1 
            ELSE 0 
        END AS is_have_preseason,
        b.uid AS pre_uid,
        b.title AS pre_title
    FROM 
        anime mm
    LEFT JOIN (
        -- Subquery to find the next anime entry for each anime
        SELECT 
            *,
            ROW_NUMBER() OVER (PARTITION BY next_uid ORDER BY s_date DESC) AS r 
        FROM 
            last_anime
    ) AS b ON mm.uid = b.next_uid
)
-- Final query to select data from the preseason CTE and add a column indicating whether each anime has a pre-season or other seasons
SELECT 
    *, 
    CASE 
        -- Check if an anime has a pre-season or other seasons based on the presence of pre-seasons in the dataset
        WHEN is_have_preseason = 1 OR uid IN (SELECT pre_uid FROM preseason) THEN 1 
        ELSE 0 
    END AS is_have_otherseason
FROM 
    preseason;