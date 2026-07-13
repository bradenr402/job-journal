ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def sign_in_as(user)
      session = user.sessions.create!
      Current.session = session
      request = ActionDispatch::Request.new(Rails.application.env_config)
      cookies = request.cookie_jar
      cookies.signed[Authentication::SESSION_COOKIE_NAME] = { value: session.id, httponly: true, same_site: :lax }
    end

    # Parses an HTML fixture, serving any secondary pages the parser fetches
    # via fetch_document from a sibling fixture instead of hitting the network.
    def parse_page_fixture(parser_class, dir, name)
      base = Rails.root.join("test/fixtures/files", dir)
      parser = parser_class.new(Nokolexbor::HTML(base.join("#{name}.html").read))

      parser.define_singleton_method(:fetch_document) do |_url, **|
        label = caller_locations(1, 1).first.base_label.dasherize
        page = base.join("#{name}_#{label}.html")
        Nokolexbor::HTML(page.read) if page.exist?
      end

      parser.to_h
    end
  end
end
