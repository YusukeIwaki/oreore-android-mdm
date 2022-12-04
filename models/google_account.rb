class GoogleAccount < ActiveRecord::Base
  has_many :admin_users
  has_many :enterprises, through: :admin_users # 管理対象のenterprise
end
