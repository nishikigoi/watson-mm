# -*- coding: utf-8 -*-
require 'sinatra'   # gem 'sinatra'
require 'line/bot'  # gem 'line-bot-api'

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)

  events.each { |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        # message = {
        #   type: 'text',
        #   text: event.message['text'] + 'なのよ'
        # }
        message = {
          "type": "audio",
          "originalContentUrl": "http://www.ne.jp/asahi/music/myuu/wave/kanpai.mp3",
          "duration": 45000
        }
        client.reply_message(event['replyToken'], message)
      end
    end
  }
# http://www.d-elf.com/freebgm/Savior-of-the-Cyberspace_free_ver.mp3
http://www.ne.jp/asahi/music/myuu/wave/kanpai.mp3
  "OK"
end
