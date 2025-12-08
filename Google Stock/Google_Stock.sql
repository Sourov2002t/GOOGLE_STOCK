-- create database google_stock;

select * from stock;

-- 1. Find the highest closing price for each year
SELECT 
    YEAR(STR_TO_DATE(`Date`, '%d-%m-%Y')) AS year,
    MAX(`Close`) AS highest_close
FROM stock
GROUP BY YEAR(STR_TO_DATE(`Date`, '%d-%m-%Y'))
ORDER BY year;

-- 2. Extract the average daily trading volume per month
SELECT 
    YEAR(STR_TO_DATE(`Date`, '%d-%m-%Y')) AS year,
    MONTH(STR_TO_DATE(`Date`, '%d-%m-%Y')) AS month,
    AVG(`Volume`) AS avg_volume
FROM stock
GROUP BY 
    YEAR(STR_TO_DATE(`Date`, '%d-%m-%Y')),
    MONTH(STR_TO_DATE(`Date`, '%d-%m-%Y'))
ORDER BY year, month;

-- 3. Find days where the stock closed higher than it opened
SELECT 
    Date,
    Open,
    Close,
    (Close - Open) AS gain
FROM stock
WHERE Close > Open
ORDER BY Date;

-- 4. Get the top 10 days with the highest trading volume
SELECT 
    `Date`,
    Volume,
    Close,
    Open
FROM stock
ORDER BY Volume DESC
LIMIT 10;

-- 5. Count how many trading days had a price drop (Close < Open)
SELECT 
    COUNT(*) AS days_with_price_drop,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM stock), 2) AS percentage
FROM stock
WHERE Close < Open;

-- 6. Find the year-over-year percentage growth in average closing price
WITH yearly_avg AS (
    SELECT 
        YEAR(STR_TO_DATE(`Date`, '%d-%m-%Y')) AS year,
        round(avg(`Close`),2) AS avg_close
    FROM stock
    GROUP BY YEAR(STR_TO_DATE(`Date`, '%d-%m-%Y'))
)
SELECT 
    curr.year,
    curr.avg_close AS current_year_avg,
    prev.avg_close AS previous_year_avg,
    ROUND(((curr.avg_close - prev.avg_close) / prev.avg_close) * 100, 2) AS yoy_growth_percentage
FROM yearly_avg curr
LEFT JOIN yearly_avg prev ON curr.year = prev.year + 1
ORDER BY curr.year;

-- 7. Calculate moving averages (7, 30, 90 days) of closing price
SELECT 
    `Date`,
    `Close`,
    ROUND(AVG(`Close`) OVER (
        ORDER BY STR_TO_DATE(`Date`, '%d-%m-%Y')
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS 7_day,
    ROUND(AVG(`Close`) OVER (
        ORDER BY STR_TO_DATE(`Date`, '%d-%m-%Y')
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2) AS 30_day,
    ROUND(AVG(`Close`) OVER (
        ORDER BY STR_TO_DATE(`Date`, '%d-%m-%Y')
        ROWS BETWEEN 89 PRECEDING AND CURRENT ROW
    ), 2) AS 90_day
FROM stock
ORDER BY STR_TO_DATE(`Date`, '%d-%m-%Y');

-- 8. Find days where closing price was above the 30-day moving average

WITH meta_data AS (
    SELECT 
        Date,
        Close,
        AVG(Close) OVER (ORDER BY Date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS day_30
    FROM stock
)
SELECT 
    Date,
    Close,
    ROUND(day_30, 2) AS day_30,
    ROUND(Close - day_30, 2) AS difference
FROM meta_data
WHERE Close > day_30
ORDER BY Date asc;

-- 9. Compute daily return: (close - lag(close)) / lag(close)
SELECT 
    Date,
    Close,
    LAG(Close) OVER (ORDER BY Date) AS prev_close,
    ROUND(((Close - LAG(Close) OVER (ORDER BY Date)) / LAG(Close) OVER (ORDER BY Date)) * 100, 2) AS daily_return_pct
FROM stock
ORDER BY Date;

-- 10. Identify the longest streak of consecutive price increases
WITH daily_changes AS (
    SELECT 
        Date,
        Close,
        LAG(Close) OVER (ORDER BY Date) AS prev_close,
        CASE WHEN Close > LAG(Close) OVER (ORDER BY Date) THEN 1 ELSE 0 END AS is_increase
    FROM stock
),
streak_groups AS (
    SELECT 
        Date,
        Close,
        is_increase,
        SUM(CASE WHEN is_increase = 0 THEN 1 ELSE 0 END) OVER (ORDER BY Date) AS streak_group
    FROM daily_changes
),
streaks AS (
    SELECT 
        streak_group,
        COUNT(*) AS streak_length,
        MIN(Date) AS streak_start,
        MAX(Date) AS streak_end
    FROM streak_groups
    WHERE is_increase = 1
    GROUP BY streak_group
)
SELECT 
    streak_length,
    streak_start,
    streak_end
FROM streaks
ORDER BY streak_length DESC
LIMIT 1;

-- 11. Create a volatility metric: stddev(close) per month
SELECT 
    YEAR(STR_TO_DATE(`Date`, '%d-%m-%Y')) AS year,
    MONTH(STR_TO_DATE(`Date`, '%d-%m-%Y')) AS month,
    ROUND(STDDEV(`Close`), 2) AS volatility,
    ROUND(AVG(`Close`), 2) AS avg_close,
    ROUND((STDDEV(`Close`) / AVG(`Close`)) * 100, 2) AS coefficient_of_variation
FROM stock
GROUP BY 
    YEAR(STR_TO_DATE(`Date`, '%d-%m-%Y')),
    MONTH(STR_TO_DATE(`Date`, '%d-%m-%Y'))
ORDER BY year, month;
