UsersMoydCo::Application.config.session_store :redis_session_store, {
    key: Settings.session_key,
    redis: {
        db: 2,
        expire_after: 120.minutes,
        key_prefix: 'myapp:session:'
        #host: 'host', # Redis host name, default is localhost
        #port: 12345   # Redis port, default is 6379
    }
}