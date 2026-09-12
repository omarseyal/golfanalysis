require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
# require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# TrackmanReport lives at lib/trackman_report — a vendored copy of the
# ../lib library at the golfanalysis repo root, kept in sync by hand. It's
# copied in (rather than require_relative'd from ../../lib) so this app is
# self-contained and deployable on its own: `git subtree push` (Heroku) and
# most PaaS git deploys only ship this directory, not its siblings.
require_relative "../lib/trackman_report"

module RoughEstimates
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # trackman_report is ignored here because it's require_relative'd above,
    # eagerly, before Zeitwerk sets up — and its version.rb sets a VERSION
    # constant Zeitwerk's inflector would otherwise expect to be a Version
    # class/module.
    config.autoload_lib(ignore: %w[assets tasks trackman_report.rb trackman_report])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
