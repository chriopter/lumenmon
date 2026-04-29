#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../config/environment"
require "socket"

class SmtpReceiver
  def initialize(host: ENV.fetch("SMTP_HOST", "0.0.0.0"), port: ENV.fetch("SMTP_PORT", "25").to_i)
    @host = host
    @port = port
  end

  def run
    server = TCPServer.new(@host, @port)
    puts "smtp receiver listening on #{@host}:#{@port}"

    loop do
      Thread.new(server.accept) { |socket| handle(socket) }
    end
  end

  private

  def handle(socket)
    mail_from = nil
    recipients = []
    write(socket, "220 lumenmon smtp")

    while (line = socket.gets)
      command = line.strip
      verb = command.split(/\s+/, 2).first.to_s.upcase

      case verb
      when "EHLO", "HELO"
        write(socket, "250-lumenmon")
        write(socket, "250 SIZE 1048576")
      when "MAIL"
        mail_from = extract_address(command)
        recipients = []
        write(socket, "250 OK")
      when "RCPT"
        recipients << extract_address(command)
        write(socket, "250 OK")
      when "DATA"
        write(socket, "354 End data with <CR><LF>.<CR><LF>")
        raw_content = read_data(socket)
        message = Message.ingest_smtp!(mail_from: mail_from, recipients: recipients, raw_content: raw_content)

        if message
          puts "stored smtp message #{message.id} for #{message.agent_id}"
          write(socket, "250 Message accepted")
        else
          warn "rejected smtp message for #{recipients.join(", ")}"
          write(socket, "550 No valid recipient")
        end
      when "RSET"
        mail_from = nil
        recipients = []
        write(socket, "250 OK")
      when "NOOP"
        write(socket, "250 OK")
      when "QUIT"
        write(socket, "221 Bye")
        break
      else
        write(socket, "250 OK")
      end
    end
  rescue StandardError => e
    warn "smtp error: #{e.class}: #{e.message}"
  ensure
    socket.close
  end

  def extract_address(command)
    command[/<([^>]+)>/, 1] || command.split(":", 2).last.to_s.strip
  end

  def read_data(socket)
    lines = []
    while (line = socket.gets)
      break if line == ".\r\n" || line == ".\n"

      lines << line.sub(/\A\.\./, ".")
    end
    lines.join
  end

  def write(socket, message)
    socket.write("#{message}\r\n")
  end
end

SmtpReceiver.new.run
