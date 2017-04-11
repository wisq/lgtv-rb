#!/usr/bin/env ruby

require 'bundler/setup'
require 'websocket-eventmachine-client'
require 'json'

$current_cid = 0x100

def next_cid
  $current_cid += 1
  return $current_cid.to_s(16)
end

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

EM.run do

  ws = WebSocket::EventMachine::Client.connect(:uri => 'ws://192.168.68.11:3000')

  ws.onopen do
    puts "Connected"
    ws.send({id: 'test1', type: 'register', payload: HANDSHAKE_PAYLOAD.merge('client-key': '801361a2c88459d287a1b9b4f01822dd')}.to_json)
  end

  ws.onmessage do |msg, type|
    puts "Received message: #{msg}"
    data = JSON.load(msg)

    if data['id'] == 'test1'
      ws.send({id: 'test2', type: 'request', uri: 'ssap://system/turnOff'}.to_json)
    end
  end

  ws.onclose do |code, reason|
    puts "Disconnected with status code: #{code} #{reason.inspect}"
  end
end
