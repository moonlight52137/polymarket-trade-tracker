WITH
-- ═══════════════════════════════════════════════
-- 分支 A: Crypto — 需要提取时间跨度判断 5m/15m
-- ═══════════════════════════════════════════════
crypto_inner AS (
  SELECT
    t.block_time, t.question, t.maker, t.taker, t.amount,
    regexp_extract(t.question, '(\d+):(\d+)(AM|PM)-(\d+):(\d+)(AM|PM)', 1) AS sh,
    regexp_extract(t.question, '(\d+):(\d+)(AM|PM)-(\d+):(\d+)(AM|PM)', 2) AS sm,
    regexp_extract(t.question, '(\d+):(\d+)(AM|PM)-(\d+):(\d+)(AM|PM)', 3) AS sa,
    regexp_extract(t.question, '(\d+):(\d+)(AM|PM)-(\d+):(\d+)(AM|PM)', 4) AS eh,
    regexp_extract(t.question, '(\d+):(\d+)(AM|PM)-(\d+):(\d+)(AM|PM)', 5) AS em,
    regexp_extract(t.question, '(\d+):(\d+)(AM|PM)-(\d+):(\d+)(AM|PM)', 6) AS ea
  FROM polymarket_polygon.market_trades t
  WHERE t.block_time >= TIMESTAMP '2026-04-01'
    AND t.block_time <  TIMESTAMP '2026-04-27'
    AND t.action = 'CLOB trade'
    AND (LOWER(t.question) LIKE '%bitcoin%'
      OR LOWER(t.question) LIKE '%ethereum%'
      OR LOWER(t.question) LIKE '%solana%')
    AND LOWER(t.question) LIKE '%up or down%'
),

crypto_raw AS (
  SELECT * FROM crypto_inner WHERE sh IS NOT NULL
),

crypto_span AS (
  SELECT *,
    (TRY_CAST(sh AS INTEGER) + CASE WHEN sa = 'PM' AND TRY_CAST(sh AS INTEGER) <> 12 THEN 12
                                     WHEN sa = 'AM' AND TRY_CAST(sh AS INTEGER) = 12 THEN -12 ELSE 0 END)
      * 60 + TRY_CAST(sm AS INTEGER) AS start_min,
    (TRY_CAST(eh AS INTEGER) + CASE WHEN ea = 'PM' AND TRY_CAST(eh AS INTEGER) <> 12 THEN 12
                                     WHEN ea = 'AM' AND TRY_CAST(eh AS INTEGER) = 12 THEN -12 ELSE 0 END)
      * 60 + TRY_CAST(em AS INTEGER) AS end_min
  FROM crypto_raw
),

crypto_minute AS (
  SELECT *,
    CASE WHEN end_min >= start_min THEN end_min - start_min
         ELSE end_min - start_min + 1440 END AS minute_span
  FROM crypto_span
),

crypto_tagged AS (
  SELECT
    block_time,
    CASE WHEN minute_span BETWEEN 3 AND 7  THEN 'Crypto-5m'
         WHEN minute_span BETWEEN 13 AND 17 THEN 'Crypto-15m'
    END AS category,
    maker, taker, amount
  FROM crypto_minute
  WHERE minute_span BETWEEN 3 AND 7 OR minute_span BETWEEN 13 AND 17
),

-- ═══════════════════════════════════════════════
-- 分支 B: Sports — 直接关键词匹配
-- ═══════════════════════════════════════════════
sports_raw AS (
  SELECT
    t.block_time, t.question, t.maker, t.taker, t.amount,
    CASE
      /* 足球 */
      WHEN LOWER(t.question) LIKE '%champions league%'
        OR LOWER(t.question) LIKE '%fifa%'
        OR LOWER(t.question) LIKE '%world cup%'
        OR LOWER(t.question) LIKE '%premier league%'
        OR LOWER(t.question) LIKE '%la liga%'
        OR LOWER(t.question) LIKE '%serie a%'
        OR LOWER(t.question) LIKE '%bundesliga%'
        OR LOWER(t.question) LIKE '%ligue 1%'
        OR LOWER(t.question) LIKE '%mls%'
        OR LOWER(t.question) LIKE '%eredivisie%'
        OR LOWER(t.question) LIKE '%liga mx%'
        OR LOWER(t.question) LIKE '%euro 202%'
        OR LOWER(t.question) LIKE '%copa america%'
        OR LOWER(t.question) LIKE '%fa cup%'
        OR LOWER(t.question) LIKE '%soccer%'
        OR LOWER(t.question) LIKE '%uefa%'
        OR LOWER(t.question) LIKE '%goal scorer%'
        THEN 'Sports-足球'

      /* 篮球 */
      WHEN LOWER(t.question) LIKE '%nba%'
        OR LOWER(t.question) LIKE '%basketball%'
        OR LOWER(t.question) LIKE '%wnba%'
        OR LOWER(t.question) LIKE '%euroleague%'
        THEN 'Sports-篮球'

      /* 冰球 */
      WHEN LOWER(t.question) LIKE '%nhl%'
        OR LOWER(t.question) LIKE '%hockey%'
        OR LOWER(t.question) LIKE '%khl%'
        THEN 'Sports-冰球'

      /* 乒乓球 */
      WHEN LOWER(t.question) LIKE '%table tennis%'
        OR LOWER(t.question) LIKE '%ping pong%'
        OR LOWER(t.question) LIKE '%tt cup%'
        OR LOWER(t.question) LIKE '%wtt%'
        OR LOWER(t.question) LIKE '%ittf%'
        THEN 'Sports-乒乓球'

      /* 网球 */
      WHEN LOWER(t.question) LIKE '%tennis%'
        OR LOWER(t.question) LIKE '%grand slam%'
        OR LOWER(t.question) LIKE '%wimbledon%'
        OR LOWER(t.question) LIKE '%atp%'
        OR LOWER(t.question) LIKE '%wta%'
        OR LOWER(t.question) LIKE '%roland garros%'
        OR LOWER(t.question) LIKE '%australian open%'
        OR LOWER(t.question) LIKE '%us open%'
        THEN 'Sports-网球'

      /* CS2 */
      WHEN LOWER(t.question) LIKE '%cs2%'
        OR LOWER(t.question) LIKE '%counter-strike%'
        OR LOWER(t.question) LIKE '%counter strike%'
        OR LOWER(t.question) LIKE '%cs:go%'
        OR LOWER(t.question) LIKE '%blast premier%'
        OR LOWER(t.question) LIKE '%iem %'
        OR LOWER(t.question) LIKE '%esl pro%'
        OR LOWER(t.question) LIKE '%pgl %'
        THEN 'Sports-CS2'

      /* 英雄联盟 */
      WHEN LOWER(t.question) LIKE '%league of legends%'
        OR LOWER(t.question) LIKE '%lol:%'
        OR LOWER(t.question) LIKE '%lck%'
        OR LOWER(t.question) LIKE '%lpl%'
        OR LOWER(t.question) LIKE '%lec%'
        OR LOWER(t.question) LIKE '%lcs%'
        OR LOWER(t.question) LIKE '%worlds%'
        OR LOWER(t.question) LIKE '%msi%'
        OR LOWER(t.question) LIKE '%lta%'
        OR LOWER(t.question) LIKE '%lcp%'
        THEN 'Sports-英雄联盟'

      /* Dota2 */
      WHEN LOWER(t.question) LIKE '%dota%'
        OR LOWER(t.question) LIKE '%dreamleague%'
        OR LOWER(t.question) LIKE '%betboom%'
        THEN 'Sports-Dota2'
    END AS category
  FROM polymarket_polygon.market_trades t
  WHERE t.block_time >= TIMESTAMP '2026-04-01'
    AND t.block_time <  TIMESTAMP '2026-04-27'
    AND t.action = 'CLOB trade'
),

sports_tagged AS (
  SELECT block_time, category, maker, taker, amount
  FROM sports_raw
  WHERE category IS NOT NULL
),

-- ═══════════════════════════════════════════════
-- 合并 → 展开 maker/taker
-- ═══════════════════════════════════════════════
all_tagged AS (
  SELECT block_time, category, maker, taker, amount FROM crypto_tagged
  UNION ALL
  SELECT block_time, category, maker, taker, amount FROM sports_tagged
),

flows AS (
  SELECT block_time, category, maker AS trader, +amount AS usdc_flow
  FROM all_tagged
  UNION ALL
  SELECT block_time, category, taker AS trader, -amount AS usdc_flow
  FROM all_tagged
),

-- ═══════════════════════════════════════════════
-- 按天 + 分类 + 地址聚合
-- ═══════════════════════════════════════════════
daily_stats AS (
  SELECT
    DATE(block_time) AS trade_day,
    category,
    trader,
    SUM(usdc_flow) AS daily_net_flow,
    COUNT(*) AS daily_trades
  FROM flows
  GROUP BY 1, 2, 3
),

-- ═══════════════════════════════════════════════
-- 合格 Bot
-- ═══════════════════════════════════════════════
bot_registry AS (
  SELECT category, trader
  FROM daily_stats
  GROUP BY 1, 2
  HAVING COUNT(DISTINCT trade_day) >= 7
     AND COUNT(DISTINCT CASE WHEN daily_net_flow > 0 THEN trade_day END) * 1.0
         / COUNT(DISTINCT trade_day) >= 0.70
     AND SUM(daily_trades) * 1.0
         / COUNT(DISTINCT trade_day) >= 200
),

-- ═══════════════════════════════════════════════
-- 每日 DAU & Bot
-- ═══════════════════════════════════════════════
daily_metrics AS (
  SELECT
    d.trade_day,
    d.category,
    COUNT(DISTINCT d.trader) AS dau,
    COUNT(DISTINCT r.trader) AS bots
  FROM daily_stats d
  LEFT JOIN bot_registry r
    ON d.trader = r.trader AND d.category = r.category
  GROUP BY 1, 2
)

-- ═══════════════════════════════════════════════
-- 最终输出
-- ═══════════════════════════════════════════════
SELECT
  category,
  ROUND(AVG(dau), 0)     AS avg_dau,
  ROUND(AVG(bots), 1)    AS avg_bots,
  ROUND(AVG(100.0 * bots / NULLIF(dau, 0)), 2) AS bot_pct
FROM daily_metrics
GROUP BY 1
ORDER BY
  CASE category
    WHEN 'Crypto-5m'     THEN 1
    WHEN 'Crypto-15m'    THEN 2
    WHEN 'Sports-足球'      THEN 3
    WHEN 'Sports-篮球'      THEN 4
    WHEN 'Sports-冰球'      THEN 5
    WHEN 'Sports-乒乓球'     THEN 6
    WHEN 'Sports-网球'      THEN 7
    WHEN 'Sports-CS2'    THEN 8
    WHEN 'Sports-英雄联盟'   THEN 9
    WHEN 'Sports-Dota2'  THEN 10
  END
