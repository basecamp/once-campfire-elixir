puts JSON.pretty_generate(%w[foreign_keys journal_mode synchronous cache_size busy_timeout mmap_size].to_h { |name| [name, ActiveRecord::Base.connection.select_value("PRAGMA #{name}")] })
