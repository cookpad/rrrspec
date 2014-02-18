class ActiveSupport::TimeWithZone
  def as_json(*arg)
    iso8601
  end
end

