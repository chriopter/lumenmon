require "test_helper"

class MessagesTest < ActionDispatch::IntegrationTest
  test "mqtt mail messages are stored for the agent" do
    agent_id = "id_abc123"

    Message.ingest_mqtt!(
      agent_id,
      {
        "mail_from" => "root@example.test",
        "subject" => "Cron output",
        "body" => "hello"
      }
    )

    get "/api/agents/#{agent_id}/messages"

    assert_response :success
    message = response.parsed_body.fetch("messages").first
    assert_equal "root@example.test", message.fetch("mail_from")
    assert_equal "Cron output", message.fetch("subject")
    assert_equal false, message.fetch("read")
  end

  test "smtp mail is matched by recipient and stored" do
    agent_id = "id_abc123"
    MetricSample.create!(
      agent_id: agent_id,
      metric_name: "generic_hostname",
      value: "mailbox",
      data_type: "TEXT",
      interval: 60,
      observed_at: Time.current
    )

    message = Message.ingest_smtp!(
      mail_from: "sender@example.test",
      recipients: ["#{agent_id}@console.example.test"],
      raw_content: <<~MAIL
        From: sender@example.test
        To: #{agent_id}@console.example.test
        Subject: Direct SMTP

        body text
      MAIL
    )

    assert message
    assert_equal agent_id, message.agent_id
    assert_equal "Direct SMTP", message.subject
    assert_equal "body text\n", message.body
  end

  test "message show marks read and delete removes it" do
    message = Message.create!(
      agent_id: "id_abc123",
      mail_from: "root@example.test",
      mail_to: "id_abc123@example.test",
      subject: "Read me",
      body: "body",
      raw_content: "raw",
      received_at: Time.current
    )

    get "/api/messages/#{message.id}"

    assert_response :success
    assert_equal "body", response.parsed_body.fetch("body")
    assert Message.find(message.id).read

    delete "/api/messages/#{message.id}"

    assert_response :success
    assert_not Message.exists?(message.id)
  end
end
