# -*- coding: utf-8 -*-
require 'sinatra'   # gem 'sinatra'
require 'line/bot'  # gem 'line-bot-api'
require 'json'
require 'rest-client'
require 'addressable/uri'

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

def get_userlocal_bot_resp(req)
  request_content = {'key' => ENV["USER_LOCAL_API_KEY"], 'message' => req}
  request_params = request_content.reduce([]) do |params, (key, value)|
    params << "#{key.to_s}=#{value}"
  end
  url = 'https://chatbot-api.userlocal.jp/api/chat?' + request_params.join('&').to_s
  rest = RestClient.get(Addressable::URI.parse(url).normalize.to_str)
  resp = JSON.parse(rest)
  return resp['result']
end

def get_music_scenario_resp(req)
  if req == "リクエスト"
    return "曲をリクエストしてください"
  else if req == "マイケルのスリラー"
    return "Michael Jackson - Thriller でよろしいでしょうか？"
  else if req == "はい"
    return "Michael Jackson - Thriller を予約しました"
  else if req == "今の曲は何？"
    return "宇多田ヒカル - 花束を君に です"
  else
    return get_userlocal_bot_resp(req)
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
        message = {
          type: 'text',
          # text: get_userlocal_bot_resp(event.message['text'])
          text: get_music_scenario_resp(event.message['text'])
        }
        client.reply_message(event['replyToken'], message)
      end
    end
  }

  "OK"
end

get '/playlist' do
  content_type :json
  output = {
    url: "https://www.youtube.com/watch?v=mFnqEo9367s"
  }
  output.to_json
end
