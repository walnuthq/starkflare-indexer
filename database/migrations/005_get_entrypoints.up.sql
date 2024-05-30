BEGIN;

CREATE OR REPLACE FUNCTION starkflare_api.get_entrypoints_table(contract_address_param VARCHAR(66))
RETURNS TABLE (
    entrypoint_selector VARCHAR(66),
    entrypoint_steps BIGINT,
    entrypoint_steps_percentage FLOAT
) AS $$
DECLARE
    last_7_days_timestamp FLOAT := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - INTERVAL '7 days'));
    steps_total_number BIGINT;
BEGIN
    SELECT SUM(steps_number) INTO steps_total_number
    FROM starkflare_api.account_calls
    WHERE contract_address = contract_address_param AND timestamp >= last_7_days_timestamp;

    RETURN QUERY
    SELECT
      DISTINCT starkflare_api.account_calls.entrypoint_selector,
      SUM(steps_number) AS entrypoint_steps,
      CAST(SUM(steps_number) AS FLOAT) * 100.0 / steps_total_number AS entrypoint_steps_percentage
    FROM starkflare_api.account_calls
    WHERE contract_address = contract_address_param AND timestamp >= last_7_days_timestamp
    GROUP BY starkflare_api.account_calls.entrypoint_selector
    ORDER BY entrypoint_steps DESC;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS starkflare_api.get_entrypoints(VARCHAR(66));

CREATE OR REPLACE FUNCTION starkflare_api.get_entrypoints(contract_address_param VARCHAR(66))
RETURNS JSON
AS $$
DECLARE
    entrypoints JSON;
BEGIN
    -- Fetch entrypoints by contract address
    SELECT json_agg(
        json_build_object(
            'entrypoint_selector', entrypoints_table.entrypoint_selector,
            'entrypoint_steps', entrypoints_table.entrypoint_steps,
            'entrypoint_steps_percentage', entrypoints_table.entrypoint_steps_percentage
        )
    ) INTO entrypoints
    FROM starkflare_api.get_entrypoints_table(contract_address_param) AS entrypoints_table;

    RETURN json_build_object('entrypoints', COALESCE(entrypoints, '[]'::json));
END;
$$ LANGUAGE plpgsql;

grant execute on function starkflare_api.get_entrypoints to starkflare_web_anon;

COMMIT;
