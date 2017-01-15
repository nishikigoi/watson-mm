#!/usr/bin/ruby

require 'rubygems'
require 'google/api_client'
require 'dotenv'

Dotenv.load

# Set DEVELOPER_KEY to the API key value from the APIs & auth > Credentials
# tab of
# Google Developers Console <https://console.developers.google.com/>
# Please ensure that you have enabled the YouTube Data API for your project.
DEVELOPER_KEY = ENV["YOUTUBE_API_DEVELOPER_KEY"]
YOUTUBE_API_SERVICE_NAME = 'youtube'
YOUTUBE_API_VERSION = 'v3'

def get_service
  client = Google::APIClient.new(
    :key => DEVELOPER_KEY,
    :authorization => nil,
    :application_name => $PROGRAM_NAME,
    :application_version => '1.0.0'
  )
  youtube = client.discovered_api(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION)

  return client, youtube
end

def youtube_retrieve_playlist(next_page_token)
  client, youtube = get_service

  begin
    # Call the search.list method to retrieve results matching the specified
    # query term.
    search_response = client.execute!(
      :api_method => youtube.playlist_items.list,
      :parameters => {
        :part => 'snippet',
        :playlistId => 'PLFgquLnL59alxIWnf4ivu5bjPeHSlsUe9',
        :maxResults => 5,
        :pageToken => next_page_token,
      }
    )

    videos = []

    # Add each result to the appropriate list, and then display the lists of
    # matching videos, channels, and playlists.
    search_response.data.items.each do |search_result|
      case search_result.snippet.resourceId.kind
        when 'youtube#video'
          videos << "#{search_result.snippet.title} (#{search_result.snippet.resourceId.videoId}) [#{search_result.snippet.description}]"
      end
    end

    puts "Videos:\n", videos, "\n"
  rescue Google::APIClient::TransmissionError => e
    puts e.result.body
  end

  return search_response.data
end

def youtube_search(req, next_page_token)
  client, youtube = get_service

  begin
    # Call the search.list method to retrieve results matching the specified
    # query term.
    search_response = client.execute!(
      :api_method => youtube.search.list,
      :parameters => {
        :part => 'snippet',
        :forMine => 'true',
        :regionCode => 'jp',
        :pageToken => next_page_token,
        :q => req,
        :maxResults => 5,
        :type => 'video',
        :safeSearch => 'strict',
      }
    )

    videos = []

    # Add each result to the appropriate list, and then display the lists of
    # matching videos, channels, and playlists.
    search_response.data.items.each do |search_result|
      case search_result.id.kind
        when 'youtube#video'
          videos << "#{search_result.snippet.title} (#{search_result.id.videoId}) [#{search_result.snippet.description}]"
      end
    end

    puts "Videos:\n", videos, "\n"
  rescue Google::APIClient::TransmissionError => e
    puts e.result.body
  end

  return search_response.data
end
