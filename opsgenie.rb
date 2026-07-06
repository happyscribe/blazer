require "net/http"
require "uri"
require "json"

# Routes Blazer check alerts to Opsgenie instead of Slack.
#
# Priority is derived from the check's `slack_channels` value, which we now treat
# as a severity bucket (e.g. "critical-alerts" -> P1). This keeps the DB schema
# stock — no extra column — so the Blazer schema stays reproducible from the gem.
module OpsgenieNotifier
  API_URL          = "https://api.opsgenie.com/v2/alerts".freeze
  API_KEY          = ENV["OPSGENIE_API_KEY"]
  DEFAULT_PRIORITY = "P3".freeze

  # Severity bucket (stored in the check's slack_channels field) -> Opsgenie priority.
  CHANNEL_PRIORITY = {
    "critical-alerts" => "P1",
    "alerts"          => "P3",
  }.freeze

  class << self
    # Keeps the field rendered in the check form and permitted as a param.
    def fields
      [:slack_channels]
    end

    # Fired on each check state transition (passing <-> failing).
    def state_change(check:, state:, state_was:, result:, message:, check_type:)
      return unless API_KEY

      case state
      when "failing" then create_alert(check, message)
      when "passing" then close_alert(check)
      end
    end

    # Fired by `rake blazer:send_failing_checks` (digest of still-failing checks).
    def failing_checks(checks)
      return unless API_KEY
      checks.each { |check| create_alert(check, check.state) }
    end

    private

      def priority_for(check)
        buckets = check.slack_channels.to_s.split(",").map { |c| c.strip.downcase }
        matched = buckets.map { |b| CHANNEL_PRIORITY[b] }.compact
        # Most urgent wins (P1 < P3); nothing recognised -> safe default.
        matched.min_by { |p| p[1..-1].to_i } || DEFAULT_PRIORITY
      end

      def create_alert(check, message)
        request(API_URL, {
          message: check.query.name,
          alias: "blazer-check-#{check.id}",
          priority: priority_for(check),
          description: message.to_s,
          source: "Blazer",
          tags: ["blazer"],
        })
      end

      def close_alert(check)
        request("#{API_URL}/blazer-check-#{check.id}/close?identifierType=alias", { source: "Blazer" })
      end

      def request(url, payload)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 3
        http.read_timeout = 5

        req = Net::HTTP::Post.new(uri)
        req["Authorization"] = "GenieKey #{API_KEY}"
        req["Content-Type"] = "application/json"
        req.body = payload.to_json

        http.request(req)
      rescue => e
        Rails.logger.error("[OpsgenieNotifier] notify failed: #{e.class}: #{e.message}")
      end
  end
end

# Parallel run: register Opsgenie ALONGSIDE the existing Slack notifier so alerts
# fire to BOTH while we validate Opsgenie routing. This means duplicate
# notifications for now — that's intentional. Once Opsgenie is confirmed working,
# cut over by adding `Blazer.notifiers.delete(Blazer::SlackNotifier)` above.
if OpsgenieNotifier::API_KEY
  Blazer.register_notifier(OpsgenieNotifier)
end
