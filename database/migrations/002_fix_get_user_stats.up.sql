BEGIN;

DROP FUNCTION IF EXISTS starkflare_api.get_user_stats();

CREATE OR REPLACE FUNCTION starkflare_api.get_user_stats()
RETURNS TABLE (
    unique_users_last_7_days INTEGER,
    new_users_last_7_days INTEGER,
    lost_users_last_7_days INTEGER
)
AS $$
DECLARE
    current_period_start TIMESTAMP := NOW() - INTERVAL '7 days';
    current_period_end TIMESTAMP := NOW();
    previous_period_start TIMESTAMP := NOW() - INTERVAL '14 days';
    previous_period_end TIMESTAMP := NOW() - INTERVAL '7 days';
BEGIN
    -- 1. Get unique number of users for the last period
    SELECT COUNT(DISTINCT sender_address)
    INTO unique_users_last_7_days
    FROM starkflare_api.account_calls
    WHERE timestamp >= EXTRACT(EPOCH FROM current_period_start)
      AND timestamp < EXTRACT(EPOCH FROM current_period_end);

    -- 2. Get number of new users for the last period relative to the previous period
    SELECT COUNT(DISTINCT t1.sender_address)
    INTO new_users_last_7_days
    FROM starkflare_api.account_calls t1
    WHERE t1.timestamp >= EXTRACT(EPOCH FROM current_period_start)
      AND t1.timestamp < EXTRACT(EPOCH FROM current_period_end)
      AND NOT EXISTS (
        SELECT 1
        FROM starkflare_api.account_calls t2
        WHERE t2.sender_address = t1.sender_address
          AND t2.timestamp >= EXTRACT(EPOCH FROM previous_period_start)
          AND t2.timestamp < EXTRACT(EPOCH FROM previous_period_end)
    );

    -- 3. Get number of lost users (active in the previous period but not active in the current period)
    SELECT COUNT(DISTINCT t2.sender_address)
    INTO lost_users_last_7_days
    FROM starkflare_api.account_calls t2
    WHERE t2.timestamp >= EXTRACT(EPOCH FROM previous_period_start)
      AND t2.timestamp < EXTRACT(EPOCH FROM previous_period_end)
      AND NOT EXISTS (
        SELECT 1
        FROM starkflare_api.account_calls t1
        WHERE t1.sender_address = t2.sender_address
          AND t1.timestamp >= EXTRACT(EPOCH FROM current_period_start)
          AND t1.timestamp < EXTRACT(EPOCH FROM current_period_end)
    );

    RETURN QUERY
    SELECT unique_users_last_7_days, new_users_last_7_days, lost_users_last_7_days;
END;
$$ LANGUAGE plpgsql;

COMMIT;