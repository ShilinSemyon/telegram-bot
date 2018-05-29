require 'faraday'

module Telegram
  module Bot
    class Adapter
      class UnknownAdapter < StandardError; end

      class << self
        attr_accessor :kind, :url, :user, :password

        def config(store)
          self.kind =
            if store.key?(:http)
              :http
            elsif store.key?(:socks5)
              :socks5
            elsif store.empty?
              nil
            else
              raise UnknownAdapter, "Unknown adapter key - #{store.keys.first}. Allowed: http, socks5"
            end
          self.proxy = store
        end

        def proxy=(store)
          self.url = store.dig(@kind, :url)
          self.user = store.dig(@kind, :user)
          self.password = store.dig(@kind, :password)
        end

        def proxy
          {
            url: @url,
            user: @user,
            password: @password
          }
        end

        def http_proxy
          {
            uri: URI.parse(@url),
            user: @user,
            password: @password
          }
        end

        def socks5_proxy
          http_proxy.merge!(socks: true)
        end
      end

      def client
        @client ||=
          if self.class.kind == :http
            set_http_proxy_connection
          elsif self.class.kind == :socks5
            set_socks5_proxy_connection
          else
            set_default_connection
          end
      end

      private

      def set_default_connection
        ::Faraday.new(url: 'https://api.telegram.org', ssl: {verify: false}) do |faraday|
          faraday.request :multipart
          faraday.request :url_encoded
          faraday.adapter ::Faraday.default_adapter
        end
      end

      def set_http_proxy_connection
        ::Faraday.new(url: 'https://api.telegram.org', ssl: {verify: false}) do |faraday|
          faraday.request :multipart
          faraday.request :url_encoded
          faraday.adapter ::Faraday.default_adapter
          faraday.proxy self.class.http_proxy
        end
      end

      def set_socks5_proxy_connection
        ::Faraday.new(url: 'https://api.telegram.org',
                      ssl: {verify: false},
                      request: {proxy: self.class.socks5_proxy}) do |c|
          c.request :multipart
          c.request :url_encoded
          c.headers['Content-Type'] = 'application/json'
          ::Faraday::Adapter.register_middleware socks5: Telegram::Bot::Socks5
          c.adapter :socks5
        end
      end
    end
  end
end
