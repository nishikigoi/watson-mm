# -*- coding: utf-8 -*-
require 'sinatra'   # gem 'sinatra'
require 'sinatra/reloader'   # gem 'sinatra-contrib'
require 'line/bot'  # gem 'line-bot-api'
require 'json'
require 'rest-client'
require 'addressable/uri'
require 'dotenv'
require './youtube_search.rb'

Dotenv.load

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
  elsif req == "マイケルのスリラー"
    return "Michael Jackson - Thriller でよろしいでしょうか？"
  elsif req == "はい"
    return "Michael Jackson - Thriller を予約しました"
  elsif req == "今の曲は何？"
    return "宇多田ヒカル - 花束を君に を再生中です"
  else
    return get_userlocal_bot_resp(req)
  end
end

$request_prefix = "action=request&v="
$nowplaying_prefix = "action=nowplaying"
$playlist_prefix = "action=playlist"
$uri_prefix = "https://www.youtube.com/watch?v="
$key_recommended = "key_recommended"
$id_list = []

def push_id(id)
  unless $id_list.find {|user| user[:id] == id}
    $id_list.push({:id => id, :q => nil, :next_page_token => nil})
  end
end

def remove_id(id)
  if user = $id_list.find {|x| x[:id] == id}
    $id_list.delete(user)
  end
end

def has_id(id)
  if user = $id_list.find {|x| x[:id] == id}
    return true
  else
    return false
  end
end

def set_q(id, q, next_page_token)
  if user = $id_list.find {|x| x[:id] == id}
    user[:q] = q
    user[:next_page_token] = next_page_token
  end
end

def get_user(id)
  return $id_list.find {|x| x[:id] == id}
end

def get_youtube_list(id, q, next_page_token)
  column = []

  if q == $key_recommended
    search_results = youtube_retrieve_playlist(next_page_token)
    set_q(id, q, search_results.nextPageToken)
    search_results.items.each do |result|
      case result.snippet.resourceId.kind
      when 'youtube#video'
        title = result.snippet.title[0..39]
        description = result.snippet.description[0..59]
        if description.empty?
          description = "No description"
        end

        item = {
          "thumbnailImageUrl": result.snippet.thumbnails.high.url,
          # "title": result.snippet.title[0..39],
          # "text": result.snippet.description[0..59],
          "title": title,
          "text": description,
          "actions": [
                      {
                        "type": "postback",
                        "label": "Request",
                        "data": $request_prefix + result.snippet.resourceId.videoId
                      },
                      {
                        "type": "uri",
                        "label": "View on YouTube",
                        "uri": $uri_prefix + result.snippet.resourceId.videoId
                      }
                     ]
        }
        column.push(item)
      end
    end
  else
    search_results = youtube_search(q, next_page_token)
    set_q(id, q, search_results.nextPageToken)
    search_results.items.each do |result|
      case result.id.kind
      when 'youtube#video'
        title = result.snippet.title[0..39]
        description = result.snippet.description[0..59]
        if description.empty?
          description = "No description"
        end

        item = {
          "thumbnailImageUrl": result.snippet.thumbnails.high.url,
          # "title": result.snippet.title[0..39],
          # "text": result.snippet.description[0..59],
          "title": title,
          "text": description,
          "actions": [
                      {
                        "type": "postback",
                        "label": "Request",
                        "data": $request_prefix + result.id.videoId
                      },
                      {
                        "type": "uri",
                        "label": "View on YouTube",
                        "uri": $uri_prefix + result.id.videoId
                      }
                     ]
        }
        column.push(item)
      end
    end
  end

  return column
end

def id_to_title(id)
  youtube_search(id, nil).items.each do |result|
    case result.id.kind
    when 'youtube#video'
      return result.snippet.title
    end
  end

  return ""
end


$default_content = [{ url: "https://www.youtube.com/watch?v=fa8QlkEyukc" },
                    { url: "https://www.youtube.com/watch?v=0HUEiUOCLeI" },
                    { url: "https://www.youtube.com/watch?v=u-o2s2GSl0c" }]
$default_count = 0
$playlist = [$default_content[$default_count]]

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)

  events.each { |event|
    user_id = event['source']['userId']
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        if event.message['text'] == "#connect?host=" + ENV["SAMPLE_UUID"]
          push_id(user_id)
          message = {
            "type": 'text',
            "text": "ホストと接続しました"
          }
        elsif event.message['text'] == "#disconnect"
          remove_id(user_id)
          message = {
            "type": 'text',
            "text": "ホストから切断しました"
          }
        else
          unless has_id(user_id)
            message = {
              "type": 'text',
              "text": "ホストと接続されていません"
            }
            client.reply_message(event['replyToken'], message)
            break
          end

          if event.message['text'] == "#nowplaying"
            title = id_to_title($playlist[0][:url].sub($uri_prefix, ""))
            unless title.empty?
              message = {
                type: 'text',
                text: title + " を再生中です"
              }
            end
          elsif event.message['text'] == "#playlist"
            title = "[再生曲リスト]"
            count = 1
            $playlist.each do |track|
              title += "\n" + count.to_s + ". " + id_to_title(track[:url].sub($uri_prefix, ""))
              count += 1
            end
            message = {
              type: 'text',
              text: title
            }
          elsif event.message['text'] == "#recommended"
            message = {
              "type": "template",
              "altText": "おすすめ曲リスト",
              "template": {
                "type": "carousel",
                "columns": get_youtube_list(user_id, $key_recommended, nil),
              }
            }
          elsif event.message['text'] == "#nextlist"
            user = get_user(user_id)
            if user == nil
              next_q = nil
              next_page_token = nil
            else
              next_q = user[:q]
              next_page_token = user[:next_page_token]
            end
            message = {
              "type": "template",
              "altText": "次のリスト",
              "template": {
                "type": "carousel",
                "columns": get_youtube_list(user_id, next_q, next_page_token),
              }
            }
          else
            message = {
              "type": "template",
              "altText": "楽曲リスト表示",
              "template": {
                "type": "carousel",
                "columns": get_youtube_list(user_id, event.message['text'], nil),
              }
            }
          end
        end
        client.reply_message(event['replyToken'], message)
      end
    when Line::Bot::Event::Postback
      unless has_id(user_id)
        message = {
          "type": 'text',
          "text": "ホストと接続されていません"
        }
        client.reply_message(event['replyToken'], message)
        break
      end

      content = event['postback']['data']
      if content.start_with?($request_prefix)
        $playlist.push({ url: content.sub($request_prefix, $uri_prefix) })

        title = id_to_title(content.sub($request_prefix, ""))
        unless title.empty?
          title += " を"
        end
        message = {
          type: 'text',
          text: title + "リクエストしました"
        }
        client.reply_message(event['replyToken'], message)
      end
    end
  }

  "OK"
end

post '/done' do
  $playlist = $playlist[1..$playlist.size - 1]
end

get '/playlist' do
  if $playlist.empty?
    $default_count += 1
    $playlist.push($default_content[$default_count % 3])
  end

  content_type :json
  $playlist.to_json
end
