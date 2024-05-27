BEGIN;

DROP FUNCTION IF EXISTS starkflare_api.get_top_transactions_by_steps();

CREATE OR REPLACE FUNCTION starkflare_api.get_top_transactions_by_steps()
RETURNS TABLE (
    tx_hash VARCHAR(66),
    steps_number INTEGER,
    tx_timestamp INTEGER,
    block_number INTEGER
)
AS $$
DECLARE
    current_period_start TIMESTAMP := DATE_TRUNC('day', NOW() - INTERVAL '7 days');
    current_period_end TIMESTAMP := DATE_TRUNC('day', NOW());
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (t.tx_hash)
        t.tx_hash,
        t.steps_number,
        t.timestamp AS tx_timestamp,
        t.block_number
    FROM starkflare_api.account_calls t
    WHERE t.timestamp >= EXTRACT(EPOCH FROM current_period_start)
      AND t.timestamp < EXTRACT(EPOCH FROM current_period_end)
    ORDER BY t.tx_hash, t.steps_number DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS starkflare_api.get_common_data();

CREATE OR REPLACE FUNCTION starkflare_api.get_common_data()
RETURNS json
AS $$
DECLARE
    user_stats json;
    top_transactions json;
    transaction_stats json;
BEGIN
    -- Fetch user stats
    SELECT json_build_object(
        'unique_users_last_7_days', user_stats.unique_users_last_7_days,
        'new_users_last_7_days', user_stats.new_users_last_7_days,
        'lost_users_last_7_days', user_stats.lost_users_last_7_days
    ) INTO user_stats
    FROM starkflare_api.get_user_stats() AS user_stats;

    -- Fetch top transactions by steps
    SELECT json_agg(json_build_object(
        'tx_hash', tx.tx_hash,
        'steps_consumed', tx.steps_number,
        'tx_timestamp', tx.tx_timestamp,
        'block_number', tx.block_number
    )) INTO top_transactions
    FROM starkflare_api.get_top_transactions_by_steps() AS tx;

    -- Fetch transaction stats
    SELECT json_build_object(
        'transactions_count_last_7_days', transaction_stats.transactions_count_last_7_days,
        'steps_number_last_7_days', transaction_stats.steps_number_last_7_days
    ) INTO transaction_stats 
    FROM starkflare_api.get_transaction_stats() AS transaction_stats;

    RETURN json_build_object(
        'user_stats', user_stats,
        'top_transactions_by_steps', top_transactions,
        'transaction_stats', transaction_stats
    );
END;
$$ LANGUAGE plpgsql;


COMMIT;