/* =========================================================
   0) IMPORT: CSV -> tabel "klanten" -> rename naar "layoffs"
   ========================================================= */

DROP TABLE IF EXISTS klanten;

CREATE TABLE klanten (
  company               VARCHAR(100),
  location              VARCHAR(100),
  industry              VARCHAR(100),
  total_laid_off         INT,
  percentage_laid_off    DECIMAL(5,2),
  date_raw              VARCHAR(20),
  stage                 VARCHAR(100),
  country               VARCHAR(100),
  funds_raised_millions  DECIMAL(10,2)
);

LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\Project_DataCleaning_SQL.csv'
INTO TABLE klanten
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
  company,
  location,
  industry,
  @laid_off,
  @percentage,
  date_raw,
  stage,
  country,
  @funds
)
SET
  total_laid_off        = IF(@laid_off REGEXP '^[0-9]+$', @laid_off, NULL),
  percentage_laid_off   = IF(@percentage REGEXP '^[0-9]+(\\.[0-9]+)?$', @percentage, NULL),
  funds_raised_millions = IF(@funds REGEXP '^[0-9]+(\\.[0-9]+)?$', @funds, NULL);

-- Quick checks
SELECT COUNT(*) AS row_count FROM klanten;
SELECT * FROM klanten LIMIT 10;

-- (Optioneel) als je dit per se als FLOAT wil
ALTER TABLE klanten MODIFY percentage_laid_off FLOAT;

-- Rename naar finale "raw" tabel
DROP TABLE IF EXISTS layoffs;
RENAME TABLE klanten TO layoffs;

SELECT * FROM layoffs LIMIT 10;


/* =========================================================
   1) STAGING: kopie + duplicate detection
   ========================================================= */

DROP TABLE IF EXISTS layoffs_staging;
CREATE TABLE layoffs_staging LIKE layoffs;

INSERT INTO layoffs_staging
SELECT * FROM layoffs;

-- Staging2 met row_num zodat we duplicates kunnen verwijderen
DROP TABLE IF EXISTS layoffs_staging2;
CREATE TABLE layoffs_staging2 (
  company               VARCHAR(100) DEFAULT NULL,
  location              VARCHAR(100) DEFAULT NULL,
  industry              VARCHAR(100) DEFAULT NULL,
  total_laid_off         INT DEFAULT NULL,
  percentage_laid_off    FLOAT DEFAULT NULL,
  date_raw              VARCHAR(20) DEFAULT NULL,
  stage                 VARCHAR(100) DEFAULT NULL,
  country               VARCHAR(100) DEFAULT NULL,
  funds_raised_millions  DECIMAL(10,2) DEFAULT NULL,
  row_num               INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO layoffs_staging2
SELECT
  s.*,
  ROW_NUMBER() OVER (
    PARTITION BY
      company,
      location,
      industry,
      total_laid_off,
      percentage_laid_off,
      date_raw,
      stage,
      country,
      funds_raised_millions
  ) AS row_num
FROM layoffs_staging s;

-- Check duplicates
SELECT *
FROM layoffs_staging2
WHERE row_num > 1;

-- Remove duplicates
DELETE FROM layoffs_staging2
WHERE row_num > 1;


/* =========================================================
   2) STANDARDIZE: trimming, values, dates
   ========================================================= */

-- Trim company
UPDATE layoffs_staging2
SET company = TRIM(company);

-- Industry: Crypto...
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Country: trailing dot
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- Convert date_raw -> date (DATE type)
ALTER TABLE layoffs_staging2
CHANGE COLUMN date_raw `date` VARCHAR(20);

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;


/* =========================================================
   3) NULL/BLANK CLEANUP + missing industry fill
   ========================================================= */

-- Blanks -> NULL
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- Fill missing industry by same company (self join)
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
  ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- Remove rows where both total_laid_off AND percentage_laid_off are NULL
DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- Drop helper column
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

SELECT * FROM layoffs_staging2 LIMIT 10;


/* =========================================================
   4) EXPLORATORY DATA ANALYSIS (EDA)
   ========================================================= */

-- 100% layoffs
SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY total_laid_off DESC;

-- Total layoffs per company
SELECT company, SUM(total_laid_off) AS total_off
FROM layoffs_staging2
GROUP BY company
ORDER BY total_off DESC;

-- Date range
SELECT MIN(`date`) AS min_date, MAX(`date`) AS max_date
FROM layoffs_staging2;

-- Total layoffs per industry
SELECT industry, SUM(total_laid_off) AS total_off
FROM layoffs_staging2
GROUP BY industry
ORDER BY total_off DESC;

-- Total layoffs per country
SELECT country, SUM(total_laid_off) AS total_off
FROM layoffs_staging2
GROUP BY country
ORDER BY total_off DESC;

-- Total layoffs per year
SELECT YEAR(`date`) AS year, SUM(total_laid_off) AS total_off
FROM layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY year DESC;

-- Monthly totals
SELECT SUBSTRING(`date`, 1, 7) AS month, SUM(total_laid_off) AS total_off
FROM layoffs_staging2
WHERE `date` IS NOT NULL
GROUP BY month
ORDER BY month ASC;

-- Rolling total by month
WITH rolling_total AS (
  SELECT
    SUBSTRING(`date`, 1, 7) AS month,
    SUM(total_laid_off) AS total_off
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY month
)
SELECT
  month,
  total_off,
  SUM(total_off) OVER (ORDER BY month) AS rolling_total
FROM rolling_total;

-- Company layoffs per year
SELECT company, YEAR(`date`) AS year, SUM(total_laid_off) AS total_off
FROM layoffs_staging2
GROUP BY company, YEAR(`date`)
ORDER BY total_off DESC;

-- Top 5 companies per year
WITH company_year AS (
  SELECT
    company,
    YEAR(`date`) AS year,
    SUM(total_laid_off) AS total_laid_off
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY company, YEAR(`date`)
),
company_year_rank AS (
  SELECT
    *,
    DENSE_RANK() OVER (PARTITION BY year ORDER BY total_laid_off DESC) AS ranking
  FROM company_year
)
SELECT *
FROM company_year_rank
WHERE ranking <= 5
ORDER BY year DESC, ranking ASC;
