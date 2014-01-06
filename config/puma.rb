rails_env = ENV['RAILS_ENV'] || 'development'

threads 4,4

bind  "unix:///tmp/alwaysresolve-puma.sock"
pidfile "/tmp/alwaysresolve-puma.pid"
state_path "/tmp/alwaysresolve-puma.state"

activate_control_app