class AdminUser < ActiveRecord::Base
  belongs_to :enterprise
  belongs_to :google_account
end
