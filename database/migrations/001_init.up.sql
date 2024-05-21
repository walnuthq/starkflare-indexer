create schema starkflare_api;

CREATE TABLE starkflare_api.transactions (
    hash VARCHAR(66) PRIMARY KEY,
    block_number INTEGER NOT NULL,
    timestamp INTEGER NOT NULL,
    steps_number INTEGER NOT NULL,
    sender_address VARCHAR(66) NOT NULL,
    _cursor BIGINT
);

create role starkflare_web_anon nologin;

grant usage on schema starkflare_api to starkflare_web_anon;
grant select on starkflare_api.transactions to starkflare_web_anon;

CREATE
OR REPLACE FUNCTION starkflare_api.get_user_stats() RETURNS TABLE (
    unique_users_last_7_days INTEGER,
    new_users_last_7_days INTEGER,
    lost_users_last_7_days INTEGER
) AS $$ DECLARE current_period_start TIMESTAMP := DATE_TRUNC('day', NOW() - INTERVAL '7 days');

current_period_end TIMESTAMP := DATE_TRUNC('day', NOW());

previous_period_start TIMESTAMP := DATE_TRUNC('day', NOW() - INTERVAL '14 days');

previous_period_end TIMESTAMP := DATE_TRUNC('day', NOW() - INTERVAL '7 days');

BEGIN -- 1. Get unique number of users for the last period
SELECT
    COUNT(DISTINCT sender_address) INTO unique_users_last_7_days
FROM
    starkflare_api.transactions
WHERE
    timestamp >= EXTRACT(
        EPOCH
        FROM
            current_period_start
    )
    AND timestamp < EXTRACT(
        EPOCH
        FROM
            current_period_end
    );

-- 2. Get number of new users for the last period relative to the previous period
SELECT
    COUNT(DISTINCT t1.sender_address) INTO new_users_last_7_days
FROM
    starkflare_api.transactions t1
WHERE
    t1.timestamp >= EXTRACT(
        EPOCH
        FROM
            current_period_start
    )
    AND t1.timestamp < EXTRACT(
        EPOCH
        FROM
            current_period_end
    )
    AND NOT EXISTS (
        SELECT
            1
        FROM
            starkflare_api.transactions t2
        WHERE
            t2.sender_address = t1.sender_address
            AND t2.timestamp >= EXTRACT(
                EPOCH
                FROM
                    previous_period_start
            )
            AND t2.timestamp < EXTRACT(
                EPOCH
                FROM
                    previous_period_end
            )
    );

-- 3. Get number of lost users (active in the previous period but not active in the current period)
SELECT
    COUNT(DISTINCT t2.sender_address) INTO lost_users_last_7_days
FROM
    starkflare_api.transactions t2
WHERE
    t2.timestamp >= EXTRACT(
        EPOCH
        FROM
            previous_period_start
    )
    AND t2.timestamp < EXTRACT(
        EPOCH
        FROM
            previous_period_end
    )
    AND NOT EXISTS (
        SELECT
            1
        FROM
            starkflare_api.transactions t1
        WHERE
            t1.sender_address = t2.sender_address
            AND t1.timestamp >= EXTRACT(
                EPOCH
                FROM
                    current_period_start
            )
            AND t1.timestamp < EXTRACT(
                EPOCH
                FROM
                    current_period_end
            )
    );

RETURN QUERY
SELECT
    unique_users_last_7_days,
    new_users_last_7_days,
    lost_users_last_7_days;

END;

$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION starkflare_api.get_common_data()
RETURNS json
AS $$
DECLARE
    user_stats json;
BEGIN
    SELECT json_build_object(
        'unique_users_last_7_days', user_stats.unique_users_last_7_days,
        'new_users_last_7_days', user_stats.new_users_last_7_days,
        'lost_users_last_7_days', user_stats.lost_users_last_7_days
    ) INTO user_stats
    FROM starkflare_api.get_user_stats() AS user_stats;

    RETURN json_build_object('user_stats', user_stats);
END;
$$ LANGUAGE plpgsql;

grant execute on function starkflare_api.get_common_data to starkflare_web_anon;