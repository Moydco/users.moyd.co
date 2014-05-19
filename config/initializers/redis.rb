$redis_user = Redis::Namespace.new('users_table', :redis => Redis.new)
$redis_code = Redis::Namespace.new('codes_table', :redis => Redis.new)