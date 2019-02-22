# 0.4.6

Re-releasing due to fix inconsistency between the gems

# 0.4.5

## web

- Bump grape gem for CVE-2018-3769 (#77, @yasaichi)

# 0.4.4
## client
- Fix capturing output stream

## server
- Nothing

## web
- Nothing

# 0.4.3
## client
- Fix dependency on thor
- Fix output stream redirection
    - When filters are configured, they initializes the reporter in setup phase
    - So the output stream must be configured in setup phase

## server
- Fix dependency on thor
- Use activerecord 4.2
- Fix persister for activerecord-import >= 0.7.0

## web
- Use activerecord 4.2

# 0.4.2
## client
- Add `--max-workers` option to overwrite default max_workers

## server
- Nothing

## web
- Nothing

# 0.4.1
## client
- Add `--show-errors` option that shows outputs of failed examples
- Show slave status as process name for admin

## server
- Nothing

## web
- Nothing

# 0.4.0
## client
- Nothing

## server
- Drop `json_cache_path` configuration

## web
- Drop API v1 support

# 0.3.0
## client
- RRRSpec now requires RSpec 3.x
    - Drop support for RSpec 2.x

## server
- Nothing

## web
- Nothing

# 0.2.4
## client
- Fix for RSpec 2.99

## server
- Nothing

## web
- Fix api-pagination dependency

# 0.2.3
## client
- `rrrspec waitfor` quits right after cancel
- `rrrspec nodes` shows worker type with node name
- Fix NameError with activesupport 4.2.x

## server
- Support stdout and stderr redirection on daemonize
- Fix error on automatic restart

## web
- Display details of active tasksets

# 0.2.2
## client
- Fix for activesupport 4.1.x

## server
- Do average calculation in another thread

## web
- Fix for api-pagination >= 3.0.0

# 0.2.1
## server
- ActiveRecord has updated to ~> 4.0.2
- logs are now stored as file
  - DB has length limit...
  - be careful to inode limit
- Support facter 2

## web
- API v2
  - now rrrspec-api requests trial, worker and slave logs based on user's
    request

## client
- fixed a bug where raise ArgumentError when searching configuration file
  - this had caused when process' user doesn't have home directory

# 0.2.0
Initial OSS release.
