BEGIN;

DROP FUNCTION IF EXISTS starkflare_api.get_top_contracts_by_steps();

CREATE OR REPLACE FUNCTION starkflare_api.get_top_contracts_by_steps()
RETURNS TABLE (
    contract_hash VARCHAR(66),
    contract_steps BIGINT,
    contract_steps_percentage FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        contract_address AS contract_hash,
        CAST(SUM(steps_number) AS BIGINT) AS contract_steps,
        (CAST(SUM(steps_number) AS FLOAT) * 100.0 / total_steps.total) AS contract_steps_percentage
    FROM 
        starkflare_api.account_calls,
        (SELECT SUM(steps_number) AS total 
         FROM starkflare_api.account_calls
         WHERE timestamp >= EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - INTERVAL '7 days'))) AS total_steps
    WHERE 
        timestamp >= EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - INTERVAL '7 days'))
    GROUP BY 
        contract_address, total_steps.total
    ORDER BY 
        contract_steps DESC
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
    top_contracts_by_steps json;
BEGIN
    -- Fetch user stats
    SELECT json_build_object(
        'unique_users_last_7_days', user_stats.unique_users_last_7_days,
        'new_users_last_7_days', user_stats.new_users_last_7_days,
        'lost_users_last_7_days', user_stats.lost_users_last_7_days
    ) INTO user_stats
    FROM starkflare_api.get_user_stats() AS user_stats;

    -- Fetch transaction stats
    SELECT json_build_object(
        'transactions_count_last_7_days', transaction_stats.transactions_count_last_7_days,
        'steps_number_last_7_days', transaction_stats.steps_number_last_7_days
    ) INTO transaction_stats 
    FROM starkflare_api.get_transaction_stats() AS transaction_stats;

    -- Fetch top contracts by steps stats
    SELECT json_agg(
        json_build_object(
            'contract_address', contracts.contract_hash,
            'steps_number', contracts.contract_steps,
            'steps_percentage', contracts.contract_steps_percentage
        )
    ) INTO top_contracts_by_steps
    FROM starkflare_api.get_top_contracts_by_steps() AS contracts;

    RETURN json_build_object(
        'user_stats', user_stats,
        'transaction_stats', transaction_stats,
        'top_contracts_by_steps', top_contracts_by_steps
    );
END;
$$ LANGUAGE plpgsql;

COMMIT;