require "net/http"
require "uri"
require "json"

# Routes Blazer check alerts to Opsgenie, registered next to Blazer's Slack and
# email notifiers (parallel run). Cutover to Opsgenie-only = unset
# BLAZER_SLACK_WEBHOOK_URL (Slack goes quiet, Opsgenie keeps firing).
# Priority comes from the check's slack_channels bucket (critical-alerts -> P1,
# alerts -> P3), which keeps the DB schema stock.
# "timed out" and "error" mean the query couldn't run (e.g. the follower is down
# or lagging), not that the check failed, so they never open an Opsgenie alert.
module OpsgenieNotifier
  API_URL          = "https://api.opsgenie.com/v2/alerts".freeze
  API_KEY          = ENV["OPSGENIE_API_KEY"]
  DEFAULT_PRIORITY = "P3".freeze

  CHANNEL_PRIORITY = {
    "critical-alerts" => "P1",
    "alerts"          => "P3",
  }.freeze

  QUERY_DID_NOT_RUN_STATES = ["timed out", "error"].freeze

  class << self
    def state_change(check:, state:, message:, **)
      return unless API_KEY
      return if QUERY_DID_NOT_RUN_STATES.include?(state)

      if state == "passing"
        close_alert(check)
      else
        create_alert(check, message)
      end
    end

    # The digest of failing checks stays on Slack/email; Opsgenie only tracks state changes.
    def failing_checks(_checks); end

    def notify_list(_check)
      []
    end

    def fields
      []
    end

    private

      def priority_for(check)
        buckets = check.slack_channels.to_s.split(",").map { |c| c.strip.downcase }
        matched = buckets.map { |b| CHANNEL_PRIORITY[b] }.compact
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

Blazer.register_notifier(OpsgenieNotifier)
