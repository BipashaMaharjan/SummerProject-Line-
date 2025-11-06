-- Quick check: Are there any waiting tokens?

-- 1. Count all tokens by status
SELECT status, COUNT(*) as count
FROM tokens
GROUP BY status;

-- 2. Show all waiting tokens
SELECT 
    id,
    token_number,
    status,
    current_room_id,
    user_id,
    service_id,
    created_at,
    booked_at
FROM tokens
WHERE status = 'waiting'
ORDER BY created_at DESC;

-- 3. Show ALL tokens (last 10)
SELECT 
    id,
    token_number,
    status,
    current_room_id,
    user_id,
    created_at
FROM tokens
ORDER BY created_at DESC
LIMIT 10;

-- 4. If no waiting tokens exist, check if they were created but with different status
SELECT 
    token_number,
    status,
    created_at
FROM tokens
ORDER BY created_at DESC
LIMIT 5;
