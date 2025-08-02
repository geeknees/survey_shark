# SQLite PRAGMAs for production-safe configuration
ActiveSupport.on_load(:active_record) do
  if ActiveRecord::Base.connection.adapter_name == "SQLite"
    ActiveRecord::Base.connection.execute "PRAGMA journal_mode = WAL"
    ActiveRecord::Base.connection.execute "PRAGMA synchronous = NORMAL" 
    ActiveRecord::Base.connection.execute "PRAGMA busy_timeout = 5000"
  end
end