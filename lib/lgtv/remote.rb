#!/usr/bin/env ruby

require 'lgtv'

require 'websocket-eventmachine-client'
require 'json'
require 'uri'

class LGTV::Remote
  HANDSHAKE_PAYLOAD = {
    forcePairing: false,
    pairingType: "PROMPT",
    :"client-key"=>"",
    manifest: {
      manifestVersion: 1,
      appVersion: "1.1",
      signed: {
        created: "20140509",
        appId: "com.lge.test",
        vendorId: "com.lge",
        localizedAppNames: {:""=>"LG Remote App"},
        localizedVendorNames: {:""=>"LG Electronics"},
        permissions: %w(
            TEST_SECURE
            CONTROL_INPUT_TEXT
            CONTROL_MOUSE_and_KEYBOARD
            READ_INSTALLED_APPS
            READ_LGE_SDX
            READ_NOTIFICATIONS
            SEARCH
            WRITE_SETTINGS
            WRITE_NOTIFICATION_ALERT
            CONTROL_POWER
            READ_CURRENT_CHANNEL
            READ_RUNNING_APPS
            READ_UPDATE_INFO
            UPDATE_FROM_REMOTE_APP
            READ_LGE_TV_INPUT_EVENTS
            READ_TV_CURRENT_TIME
        ),
        serial: "2f930e2d2cfe083771f68e4fe7bb07",
      },
      permissions: %w(
        LAUNCH
        LAUNCH_WEBAPP
        APP_TO_APP
        CLOSE
        TEST_OPEN
        TEST_PROTECTED
        CONTROL_AUDIO
        CONTROL_DISPLAY
        CONTROL_INPUT_JOYSTICK
        CONTROL_INPUT_MEDIA_RECORDING
        CONTROL_INPUT_MEDIA_PLAYBACK
        CONTROL_INPUT_TV
        CONTROL_POWER
        READ_APP_STATUS
        READ_CURRENT_CHANNEL
        READ_INPUT_DEVICE_LIST
        READ_NETWORK_STATE
        READ_RUNNING_APPS
        READ_TV_CHANNEL_LIST
        WRITE_NOTIFICATION_TOAST
        READ_POWER_STATE
        READ_COUNTRY_INFO
      ),
      signatures: [
        {
          signatureVersion: 1,
          signature:
          "eyJhbGdvcml0aG0iOiJSU0EtU0hBMjU2Iiwia2V5SWQiOiJ0ZXN0LXNpZ25pbmctY2VydCIsInNpZ25hdHVyZVZlcnNpb24iOjF9.hrVRgjCwXVvE2OOSpDZ58hR+59aFNwYDyjQgKk3auukd7pcegmE2CzPCa0bJ0ZsRAcKkCTJrWo5iDzNhMBWRyaMOv5zWSrthlf7G128qvIlpMT0YNY+n/FaOHE73uLrS/g7swl3/qH/BGFG2Hu4RlL48eb3lLKqTt2xKHdCs6Cd4RMfJPYnzgvI4BNrFUKsjkcu+WD4OO2A27Pq1n50cMchmcaXadJhGrOqH5YmHdOCj5NSHzJYrsW0HPlpuAx/ECMeIZYDh6RMqaFM2DXzdKX9NmmyqzJ3o/0lkk/N97gfVRLW5hA29yeAwaCViZNCP8iC9aO0q9fQojoa7NQnAtw=="
        }
      ]
    }
  }

  def initialize(address:, client_key: nil, &block)
    @current_cid = 0x100
    @client_key = client_key
    @callbacks = {}
    @register_callback = block

    uri = URI.parse('ws://dummy:3000')
    uri.host = address
    puts "Connecting to #{uri} ..."
    @socket = WebSocket::EventMachine::Client.connect(:uri => uri.to_s)

    @socket.onopen { |*args| on_open(*args) }
    @socket.onclose { |*args| on_close(*args) }
    @socket.onerror { |*args| on_error(*args) }
    @socket.onmessage { |*args| on_message(*args) }
  end

  def on_open(handshake)
    puts "Connected.  Registering ..."
    register
  end

  def on_close(*args)
    p [:on_close, args]
  end

  def on_error(*args)
    p [:on_error, args]
  end

  def on_message(json, type)
    data = JSON.parse(json)
    id = data['id']
    if callback = @callbacks.delete(id)
      type = data['type']
      payload = data[if type == 'error' then 'error' else 'payload' end]
      retval = callback.call(type, payload)
      @callbacks[id] = callback if retval == :keep
    end
  end

  def callback(id, &block)
    raise "Duplicate callback: #{id}" if @callbacks.has_key?(id)
    @callbacks[id] = block
  end

  def register
    payload = HANDSHAKE_PAYLOAD
    payload = payload.merge('client-key': @client_key) if @client_key
    raw_send('register', 'reg0', nil, payload)
    callback('reg0') do |type, payload|
      if type == 'response'
        puts "Waiting for TV user response ..."
        :keep
      elsif type == 'registered'
        puts "Ready!"
        @client_key = payload['client-key']
        @register_callback.call(self) if @register_callback
      else
        raise "Weird message during register: #{type}"
      end
    end
  end

  def raw_send(type, cid, uri=nil, payload={})
    @socket.send({
      type: type,
      id: cid,
      uri: uri,
      payload: payload,
    }.to_json)
  end

  def next_cid
    @current_cid += 1
    return @current_cid.to_s(16)
  end

  def request(uri, payload={})
    cid = next_cid
    raw_send('request', cid, "ssap://#{uri}", payload)
    if block_given?
      callback(cid) do |type, payload|
        if type == 'error'
          raise payload
        elsif type == 'response'
          yield payload
        else
          raise "Unknown type: #{type}"
        end
      end
    end
  end
end
