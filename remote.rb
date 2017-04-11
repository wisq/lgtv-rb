#!/usr/bin/env ruby

$LOAD_PATH << File.join(File.dirname(__FILE__), "/lib")
require 'lgtv/remote'
require 'io/console'
require 'pp'
require 'pry'

class Remote
  REGULAR_COMMANDS = {
    'q' => :cmd_quit,
    't' => :cmd_text,
    'p' => :cmd_pry,
    '[' => :cmd_volume_down,
    ']' => :cmd_volume_up,
    'i' => :cmd_input,
    'a' => :cmd_app,
    'h' => :cmd_help,
    "\e" => :cmd_escape,
    "\r" => :cmd_click,
    "\u007F" => [:cmd_button, 'BACK'],
  }

  ESCAPE_COMMANDS = {
    "[A" => [:cmd_button, 'UP'],
    "[B" => [:cmd_button, 'DOWN'],
    "[D" => [:cmd_button, 'LEFT'],
    "[C" => [:cmd_button, 'RIGHT'],
  }
  ESCAPE_MAX_LEN = ESCAPE_COMMANDS.keys.map(&:length).max

  TEXT_ENTRY_COMMANDS = {
    "\e" => :cmd_text_exit,
    "\u007F" => :cmd_text_backspace,
  }
  TEXT_ENTRY_COMMANDS.default = :cmd_text_entry

  def initialize(address)
    @address = address
  end

  def run
    LGTV::Remote.new(address: @address, client_key: load_key) do |remote|
      save_key(remote.client_key)
      @remote = remote
      @commands = REGULAR_COMMANDS
      Thread.new do
        loop do
          interact
        end
      end
    end
  end

  def load_key
    return @old_key = File.read(".client-key-#{@address}").chomp
  rescue Errno::ENOENT
    return @old_key = nil
  end

  def save_key(new_key)
    if new_key != @old_key
      File.open(".client-key-#{@address}", 'w') do |fh|
        fh.puts(new_key)
      end
      puts "Saved new client key."
    end
  end

  def interact
    command($stdin.getch)
  end

  def command(char)
    method = @commands[char]

    if method
      send(*method, char)
    else
      puts "Unknown key: #{char.inspect}"
    end
  #rescue SystemExit
  #  raise
  #rescue Exception => e
  #  p e
  rescue StandardError => e
    p e
  end

  def cmd_quit(char)
    puts "Exiting."
    exit(0)
  end

  def cmd_text(char)
    puts "Entering text entry mode (escape to exit)."
    @commands = TEXT_ENTRY_COMMANDS
  end

  def cmd_text_entry(char)
    @remote.insert_text(char)
  end

  def cmd_text_exit(char)
    puts "Text entry finished."
    @commands = REGULAR_COMMANDS
  end

  def cmd_text_backspace(char)
    @remote.delete_characters(1)
  end

  def cmd_pry(char)
    binding.pry
  end

  def cmd_volume_down(char)
    @remote.volume_down
  end

  def cmd_volume_up(char)
    @remote.volume_up
  end

  def cmd_input(char)
    @inputs = @remote.list_inputs
    puts "Select an input:"
    p @inputs
  end

  class UnknownCommand < StandardError; end

  def cmd_escape(char)
    sequence = ""
    next_char = nil

    Timeout.timeout(0.05) do
      loop do
        next_char = $stdin.getch
        break if next_char == '\e'

        sequence += next_char
        next_char = nil

        cmd = ESCAPE_COMMANDS[sequence]
        return send(*cmd, sequence) if cmd

        raise UnknownCommand if sequence.length >= ESCAPE_MAX_LEN
      end
    end
  rescue Timeout::Error, UnknownCommand
    if sequence.empty?
      puts "Empty escape sequence.  (To quit, press 'q'.)"
    else
      puts "Unknown escape sequence: #{sequence.inspect}"
    end
  end

  def cmd_button(name, sequence)
    #puts "Sending key: #{name}"
    @remote.button(name)
  end

  def cmd_click(char)
    #puts "Sending click."
    @remote.click
  end
end

EM.run do
  Remote.new(ARGV.first).run
end
