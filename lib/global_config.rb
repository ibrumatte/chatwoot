class GlobalConfig
  VERSION = 'V1'.freeze
  KEY_PREFIX = 'GLOBAL_CONFIG'.freeze
  DEFAULT_EXPIRY = 1.day
  BRANDING_CONFIG_OVERRIDES = {
    'INSTALLATION_NAME' => ENV.fetch('CHATWOOT_INSTALLATION_NAME', 'BrChat by BrJoy Tecnologia'),
    'BRAND_NAME' => ENV.fetch('CHATWOOT_BRAND_NAME', 'BrChat by BrJoy Tecnologia'),
    'BRAND_URL' => ENV.fetch('CHATWOOT_BRAND_URL', 'https://www.brjoy.com.br'),
    'WIDGET_BRAND_URL' => ENV.fetch('CHATWOOT_WIDGET_BRAND_URL', 'https://www.brjoy.com.br'),
    'TERMS_URL' => ENV.fetch('CHATWOOT_TERMS_URL', 'https://www.brjoy.com.br'),
    'PRIVACY_URL' => ENV.fetch('CHATWOOT_PRIVACY_URL', 'https://www.brjoy.com.br')
  }.freeze

  class << self
    def get(*args)
      config_keys = *args
      config = {}

      config_keys.each do |config_key|
        config[config_key] = load_from_cache(config_key)
      end

      typecast_config(config)
      config.with_indifferent_access
    end

    def get_value(arg)
      load_from_cache(arg)
    end

    def clear_cache
      cached_keys = $alfred.with { |conn| conn.keys("#{VERSION}:#{KEY_PREFIX}:*") }
      (cached_keys || []).each do |cached_key|
        $alfred.with { |conn| conn.expire(cached_key, 0) }
      end
    end

    private

    def typecast_config(config)
      general_configs = ConfigLoader.new.general_configs
      config.each do |config_key, config_value|
        config_type = general_configs.find { |c| c['name'] == config_key }&.dig('type')
        config[config_key] = ActiveRecord::Type::Boolean.new.cast(config_value) if config_type == 'boolean'
      end
    end

    def load_from_cache(config_key)
      override_value = BRANDING_CONFIG_OVERRIDES[config_key]
      return override_value if override_value.present?

      cache_key = "#{VERSION}:#{KEY_PREFIX}:#{config_key}"
      cached_value = $alfred.with { |conn| conn.get(cache_key) }

      if cached_value.blank?
        value_from_db = db_fallback(config_key)
        cached_value = { value: value_from_db }.to_json
        $alfred.with { |conn| conn.set(cache_key, cached_value, { ex: DEFAULT_EXPIRY }) }
      end

      JSON.parse(cached_value)['value']
    end

    def db_fallback(config_key)
      InstallationConfig.find_by(name: config_key)&.value
    end
  end
end
