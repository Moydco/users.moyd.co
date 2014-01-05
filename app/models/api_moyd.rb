class ApiMoyd
  include HTTParty
  base_uri ("#{Settings.moyd_base_url}/#{Settings.moyd_api_version}")

  def create_user(st)
    begin
      self.class.get(Settings.moyd_user_path, :query => {:st => st})
    rescue
      false
    end
  end

  def delete_user(st)
    begin
      self.class.delete(Settings.moyd_user_path, :query => {:st => st})
    rescue
      false
    end
  end

  def create_free_ddns(zone,ip)
    begin
      data = self.class.post("/#{Settings.moyd_user_path}/#{Settings.moyd_free_api_user_id}/domains/#{Settings.moyd_free_api_domain_id}/records/", :query => {
          :api_key => Settings.moyd_free_api_access_id,
          :api_secret => Settings.moyd_free_api_secret,
          :type => 'A',
          :name => zone,
          :ip => ip,
          :enabled => true,
          :format => 'json'
      })
      return data["_id"]["$oid"]
    end
  end

  def update_free_ddns(id,zone,ip)
    begin
      data = self.class.put("/#{Settings.moyd_user_path}/#{Settings.moyd_free_api_user_id}/domains/#{Settings.moyd_free_api_domain_id}/records/#{id}", :query => {
          :api_key => Settings.moyd_free_api_access_id,
          :api_secret => Settings.moyd_free_api_secret,
          :type => 'A',
          :name => zone,
          :ip => ip,
          :enabled => true,
          :format => 'json'
      })
      return data["_id"]["$oid"]
    end
  end

  def delete_free_ddns(id)
    begin
      data = self.class.delete("/#{Settings.moyd_user_path}/#{Settings.moyd_free_api_user_id}/domains/#{Settings.moyd_free_api_domain_id}/records/#{id}", :query => {
          :api_key => Settings.moyd_free_api_access_id,
          :api_secret => Settings.moyd_free_api_secret,
          :type => 'A',
          :format => 'json'
      })
    end
  end
end