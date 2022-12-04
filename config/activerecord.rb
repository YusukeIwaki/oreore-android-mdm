# frozen_string_literal: true

ActiveRecord::Base.logger = Logger.new($stdout)
ActiveRecord.verbose_query_logs = true
