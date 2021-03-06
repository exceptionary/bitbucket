# encoding: utf-8

require 'faraday'
require 'bitbucket_api/response'
require 'bitbucket_api/response/mashify'
require 'bitbucket_api/response/jsonize'
require 'bitbucket_api/response/helpers'
require 'bitbucket_api/response/raise_error'
require 'bitbucket_api/request/oauth'
require 'bitbucket_api/request/basic_auth'
require 'bitbucket_api/request/jsonize'

module BitBucket
  module Connection
    extend self
    include BitBucket::Constants

    ALLOWED_OPTIONS = [
        :headers,
        :url,
        :params,
        :request,
        :ssl
    ].freeze

    def default_options(options={})
      {
          :headers => {
              ACCEPT           => "application/json;q=0.1",
              ACCEPT_CHARSET   => "utf-8",
              USER_AGENT       => user_agent,
              CONTENT_TYPE     => 'application/json'
          },
          :ssl => { :verify => false },
          :url => options.fetch(:endpoint) { BitBucket.endpoint }
      }.merge(options)
    end

    # Default middleware stack that uses default adapter as specified at
    # configuration stage.
    #
    def default_middleware(options={})
      Proc.new do |builder|
        builder.use BitBucket::Request::Jsonize
        builder.use Faraday::Request::Multipart
        builder.use Faraday::Request::UrlEncoded
        builder.use BitBucket::Request::OAuth, client, oauth_token, oauth_secret if oauth_token? and oauth_secret?
        builder.use BitBucket::Request::BasicAuth, authentication if basic_authed?

        builder.use Faraday::Response::Logger if ENV['DEBUG']
        builder.use BitBucket::Response::Helpers
        unless options[:raw]
          builder.use BitBucket::Response::Mashify
          builder.use BitBucket::Response::Jsonize
        end
        builder.use BitBucket::Response::RaiseError
        builder.adapter adapter
      end
    end

    @connection = nil

    @stack = nil

    def clear_cache
      @connection = nil
    end

    def caching?
      !@connection.nil?
    end

    # Exposes middleware builder to facilitate custom stacks and easy
    # addition of new extensions such as cache adapter.
    #
    def stack(options={}, &block)
      @stack ||= begin
        if block_given?
          Faraday::Builder.new(&block)
        else
          Faraday::Builder.new(&default_middleware(options))
        end
      end
    end

    # Returns a Fraday::Connection object
    #
    def connection(options = {})
      conn_options = default_options(options)
      clear_cache unless options.empty?
      puts "OPTIONS:#{conn_options.inspect}" if ENV['DEBUG']

      @connection ||= Faraday.new(conn_options.merge(:builder => stack(options)))
    end

  end # Connection
end # BitBucket
