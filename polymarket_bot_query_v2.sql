WITH
-- ═══════════════════════════════════════════════
-- 一次扫描: 所有关键词预过滤 (关键优化: 大幅减少扫描行数)
-- ═══════════════════════════════════════════════
raw AS (
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
    -- ★ 关键: WHERE 里预过滤, 避免全表扫描
    AND (
      (LOWER(t.question) LIKE '%up or down%' AND (LOWER(t.question) LIKE '%bitcoin%' OR LOWER(t.question) LIKE '%ethereum%' OR LOWER(t.question) LIKE '%solana%'))
      OR LOWER(t.question) LIKE '%nba%'
      OR LOWER(t.question) LIKE '%champions league%' OR LOWER(t.question) LIKE '%fifa%' OR LOWER(t.question) LIKE '%world cup%'
      OR LOWER(t.question) LIKE '%premier league%' OR LOWER(t.question) LIKE '%la liga%' OR LOWER(t.question) LIKE '%serie a%'
      OR LOWER(t.question) LIKE '%bundesliga%' OR LOWER(t.question) LIKE '%ligue 1%' OR LOWER(t.question) LIKE '%mls%'
      OR LOWER(t.question) LIKE '%soccer%' OR LOWER(t.question) LIKE '%uefa%'
      OR LOWER(t.question) LIKE '%nhl%' OR LOWER(t.question) LIKE '%hockey%'
      OR LOWER(t.question) LIKE '%table tennis%' OR LOWER(t.question) LIKE '%ping pong%'
      OR LOWER(t.question) LIKE '%tennis%' OR LOWER(t.question) LIKE '%wimbledon%' OR LOWER(t.question) LIKE '%atp%'
      OR LOWER(t.question) LIKE '%cs2%' OR LOWER(t.question) LIKE '%counter-strike%' OR LOWER(t.question) LIKE '%counter strike%'
      OR LOWER(t.question) LIKE '%lol:%' OR LOWER(t.question) LIKE '%lck%' OR LOWER(t.question) LIKE '%lpl%' OR LOWER(t.question) LIKE '%lec%'
      OR LOWER(t.question) LIKE '%dota%'
    )
),

-- ═══════════════════════════════════════════════
-- 分类 + 计算 crypto 时间跨度
-- ═══════════════════════════════════════════════
tagged AS (
  SELECT
    block_time,
    maker, taker, amount,
    CASE
      /* ── Crypto 5m ── */
      WHEN sh IS NOT NULL
       AND LOWER(question) LIKE '%up or down%'
       AND (
         CASE WHEN end_min2 >= start_min2 THEN end_min2 - start_min2 ELSE end_min2 - start_min2 + 1440 END
         BETWEEN 3 AND 7
       )
        THEN 'Crypto-5m'

      /* ── Crypto 15m ── */
      WHEN sh IS NOT NULL
       AND LOWER(question) LIKE '%up or down%'
       AND (
         CASE WHEN end_min2 >= start_min2 THEN end_min2 - start_min2 ELSE end_min2 - start_min2 + 1440 END
         BETWEEN 13 AND 17
       )
        THEN 'Crypto-15m'

      /* ── Sports ── */
      WHEN LOWER(question) LIKE '%champions league%' OR LOWER(question) LIKE '%fifa%'
        OR LOWER(question) LIKE '%world cup%' OR LOWER(question) LIKE '%premier league%'
        OR LOWER(question) LIKE '%la liga%' OR LOWER(question) LIKE '%serie a%'
        OR LOWER(question) LIKE '%bundesliga%' OR LOWER(question) LIKE '%ligue 1%'
        OR LOWER(question) LIKE '%mls%' OR LOWER(question) LIKE '%soccer%' OR LOWER(question) LIKE '%uefa%'
        THEN 'Sports-足球'

      WHEN LOWER(question) LIKE '%nba%' OR LOWER(question) LIKE '%basketball%' OR LOWER(question) LIKE '%wnba%'
        THEN 'Sports-篮球'

      WHEN LOWER(question) LIKE '%nhl%' OR LOWER(question) LIKE '%hockey%'
        THEN 'Sports-冰球'

      WHEN LOWER(question) LIKE '%table tennis%' OR LOWER(question) LIKE '%ping pong%'
        THEN 'Sports-乒乓球'

      WHEN LOWER(question) LIKE '%tennis%' OR LOWER(question) LIKE '%wimbledon%' OR LOWER(question) LIKE '%atp%'
        THEN 'Sports-网球'

      WHEN LOWER(question) LIKE '%cs2%' OR LOWER(question) LIKE '%counter-strike%' OR LOWER(question) LIKE '%counter strike%'
        THEN 'Sports-CS2'

      WHEN LOWER(question) LIKE '%lol:%' OR LOWER(question) LIKE '%lck%' OR LOWER(question) LIKE '%lpl%'
        OR LOWER(question) LIKE '%lec%' OR LOWER(question) LIKE '%lcs%'
        THEN 'Sports-英雄联盟'

      WHEN LOWER(question) LIKE '%dota%'
        THEN 'Sports-Dota2'
    END AS category
  FROM (
    SELECT *,
      (TRY_CAST(sh AS INTEGER) + CASE WHEN sa = 'PM' AND TRY_CAST(sh AS INTEGER) <> 12 THEN 12
                                       WHEN sa = 'AM' AND TRY_CAST(sh AS INTEGER) = 12 THEN -12 ELSE 0 END)
        * 60 + TRY_CAST(sm AS INTEGER) AS start_min2,
      (TRY_CAST(eh AS INTEGER) + CASE WHEN ea = 'PM' AND TRY_CAST(eh AS INTEGER) <> 12 THEN 12
                                       WHEN ea = 'AM' AND TRY_CAST(eh AS INTEGER) = 12 THEN -12 ELSE 0 END)
        * 60 + TRY_CAST(em AS INTEGER) AS end_min2
    FROM raw
  )
),

filtered AS (
  SELECT * FROM tagged WHERE category IS NOT NULL
),

-- ═══════════════════════════════════════════════
-- 展开 maker/taker (只在已分类的小数据集上做)
-- ═══════════════════════════════════════════════
daily_stats AS (
  SELECT
    DATE(block_time) AS trade_day,
    category,
    trader,
    SUM(flow) AS daily_net_flow,
    COUNT(*) AS daily_trades
  FROM (
    SELECT block_time, category, maker AS trader, +amount AS flow FROM filtered
    UNION ALL
    SELECT block_time, category, taker AS trader, -amount AS flow FROM filtered
  )
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
-- 每日统计
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
