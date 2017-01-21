#!/usr/bin/env ruby

$LOAD_PATH << File.join(File.dirname(__FILE__), "/lib")
require 'lgtv/remote'

class PowerOff
  def initialize(address)
    @address = address
  end

  def run
    LGTV::Remote.new(address: @address, client_key: load_key) do |remote|
      remote.power_off
      exit(0)
    end
  end

  def load_key
    File.read(".client-key-#{@address}").chomp
  end
end

EM.run do
  PowerOff.new(ARGV.first).run
end
