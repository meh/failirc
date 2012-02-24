#! /usr/bin/env ruby
require 'eventmachine'
require 'thread'
require 'optparse'

begin
	require 'readline'
	require 'colorb'

	module Readline
		Commands  = ['!exit', '!quit', '!clients']
		Prefix    = '>> '.bold

		def self.supported?
			true
		end

		self.completion_proc = proc {|s|
			next unless s.start_with?('!')

			Commands.grep(/^#{Regexp.escape(s)}/)
		}
	end
rescue LoadError
	module Readline
		def self.supported?
			false
		end
	end
end

options = {}

OptionParser.new do |o|
	options[:verbose] = false
	options[:number] = 1000
	options[:prefix] = 'S_'
	options[:port] = 6667

	o.on '-V', '--version' do
		puts "Fail IRC stress test #{IRC.version}"
		exit 0
	end

	o.on '-v', '--[no-]verbose' do |value|
		options[:verbose] = value
	end

	o.on '-n', '--number VALUE', Integer do |value|
		options[:number] = value.to_i
	end

	o.on '-s', '--server VALUE' do |value|
		options[:server] = value
	end

	o.on '-p', '--port VALUE' do |value|
		options[:port] = value.to_i
	end

	o.on '-P', '--prefix VALUE' do |value|
		options[:prefix] = value
	end
end.parse!

module Readline
	def self.puts (text)
		print "\r#{text}#{' ' * (Readline.get_screen_size.last - text.length - 1)}\n"
		print Prefix
	end

	def self.readline_with_hist_management
		begin
			line = Readline.readline(Prefix, true)
		rescue Exception
			return
		end

		return unless line

		if line =~ /^\s*$/ or Readline::HISTORY.to_a[-2] == line
			Readline::HISTORY.pop
		end

		line
	end
end

class StressBot < EventMachine::Connection
	include EventMachine::Protocols::LineText2

	def initialize(host, port, name, channel)
		@host, @port, @name, @channel = host, port, name, channel
		@closing = false

		@sid = channel.subscribe {|msg|
			send_data(msg)
		}
	end

	def connection_completed
		send_data "NICK #{@name}\r\nUSER #{@name} #{@name} #{@name} :#{@name}\r\n"
	end

	def receive_line(line)
		if line =~ /^PI(NG.*)$/
			send_data("PO#{$1}\r\n")
		end
	end

	def game_over
		@closing = true
		send_data("QUIT :GAME OVER\r\n")
		@channel.unsubscribe(@sid)
		close_connection
	end

	def reconnect
		EventMachine.reconnect @host, @port, self
	end

	def unbind
		EventMachine.add_timer(5) do
			reconnect
		end unless @closing
	end
end

class Stresser
	def initialize(host, port, prefix, number)
		@host, @port, @prefix, @number = host, port, prefix, number
		@channel = EventMachine::Channel.new
	end

	def start
		blk = proc {
			@clients = (1..@number).map {|no|
				EventMachine.connect @host, @port, StressBot, @host, @port, "#{@prefix}#{no}", @channel
			}
		}

		EventMachine.reactor_running? ? blk.call : EventMachine.run(&blk)
	end

	def number=(num)
		return if num == @clients.size

		if num < @clients.size
			(num ... @clients.size).to_a.reverse.each do |i|
				@clients[i].game_over
				@clients.delete(i)
			end
		else
			(@clients.size ... num).each do |i|
				EventMachine.schedule do
					p i
					@clients[i] = EventMachine.connect @host, @port, StressBot, @host, @port, "#{@prefix}#{i + 1}", @channel
				end
			end
		end
	end

	def puts(data)
		@channel.push("#{data.gsub(/\r?\n$/, '')}\r\n")
	end

	def close
		@clients.each(&:game_over)
		EventMachine.stop_event_loop
	end
end

stresser = nil
Thread.abort_on_exception = true
thread = Thread.new do
	(stresser = Stresser.new(options[:server], options[:port], options[:prefix], options[:number])).start
end

['TERM', 'KILL', 'INT'].each do |sig|
	trap sig do
		stresser.close
		thread.join
		exit 0
	end
end

if Readline.supported?
	while line = Readline.readline_with_hist_management
		if line.start_with?('!')
			case line[1..-1]
			when 'exit', 'quit'
				stresser.close
				thread.join
				exit!
			when /^clients\s*(.*)$/
				number = $1.to_i
				next if number.zero?
				stresser.number = number
			end
		else
			stresser.puts(line)
		end
	end
else
	thread.join
end

