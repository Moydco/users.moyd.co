$redis_user        = Redis::Namespace.new('users_table', :redis => Redis.new)
$redis_application = Redis::Namespace.new('application_table', :redis => Redis.new)