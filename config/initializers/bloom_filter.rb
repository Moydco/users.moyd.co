if Settings.use_bloom_filter.downcase == 'true'
  require 'bloombroom'
  m, k = Bloombroom::BloomHelper.find_m_k(Settings.bloom_filter_capacity, Settings.bloom_filter_error)
  $bf_user = Bloombroom::ContinuousBloomFilter.new(m, k, Settings.bloom_filter_expire)
  $bf_user.start_timer
end