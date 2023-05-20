class AdminUser < Data.define(:google_oauth2_uid, :enterprise_name)
  def self.all
    Enumerator.new do |out|
      ENV['ADMIN_USERS'].split(';').each do |keyvalues|
        key, values = keyvalues.split(':')
        values.split(",").each do |value|
          out << new(google_oauth2_uid: key, enterprise_name: value)
        end
      end
    end
  end

  def self.for_user(uid)
    all.select do |admin_user|
      admin_user.google_oauth2_uid == uid
    end
  end
end
