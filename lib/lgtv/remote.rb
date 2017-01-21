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
      permissions: %w(
        APP_TO_APP
        CLOSE
        CONTROL_AUDIO
        CONTROL_DISPLAY
        CONTROL_INPUT_JOYSTICK
        CONTROL_INPUT_MEDIA_PLAYBACK
        CONTROL_INPUT_MEDIA_RECORDING
        CONTROL_INPUT_TEXT
        CONTROL_INPUT_TV
        CONTROL_MOUSE_AND_KEYBOARD
        CONTROL_POWER
        LAUNCH
        LAUNCH_WEBAPP
        READ_APP_STATUS
        READ_COUNTRY_INFO
        READ_CURRENT_CHANNEL
        READ_INPUT_DEVICE_LIST
        READ_INSTALLED_APPS
        READ_LGE_SDX
        READ_LGE_TV_INPUT_EVENTS
        READ_NETWORK_STATE
        READ_NOTIFICATIONS
        READ_POWER_STATE
        READ_RUNNING_APPS
        READ_TV_CHANNEL_LIST
        READ_TV_CURRENT_TIME
        READ_UPDATE_INFO
        SEARCH
        TEST_OPEN
        TEST_PROTECTED
        TEST_SECURE
        UPDATE_FROM_REMOTE_APP
        WRITE_NOTIFICATION_ALERT
        WRITE_NOTIFICATION_TOAST
        WRITE_SETTINGS
      ),
    }
  }

  attr_reader :client_key

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
    payload = payload.merge(:'client-key' => @client_key) if @client_key
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
      callback(cid) do |type, resp_payload|
        if type == 'error'
          raise resp_payload
        elsif type == 'response'
          yield resp_payload
        else
          raise "Unknown type: #{type}"
        end
      end
    end
  end

  def volume_up(&block)
    request('audio/volumeUp', &block)
  end

  def volume_down(&block)
    request('audio/volumeDown', &block)
  end

  def delete_characters(count, &block)
    request('com.webos.service.ime/deleteCharacters', {count: count}, &block)
  end

  def insert_text(text, replace=0, &block)
    request('com.webos.service.ime/insertText',
      {text: text, replace: replace}, &block)
  end

  def power_off(&block)
    request('system/turnOff', &block)
  end

  def list_inputs
    request('tv/getExternalInputList') do |response|
      p response
    end
  end
end
