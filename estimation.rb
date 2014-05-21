#!/usr/bin/env ruby

require 'yaml'
require 'optparse'
require 'pp'

options = {}

###############################################################################

class EstimationReport
	def initialize(data)
		parse_data(data)
	end

	def to_structure
		@sub_tasks.map{ |t| t.to_structure }
	end

	def encode_with(coder)
		coder.tag = nil
		coder.style = 1
		coder.implicit = true
		coder.seq = @sub_tasks
	end

	private
	def parse_data(data)
		@sub_tasks = Task.parse_tasks(data)
	end
end

class Task
	def initialize(name, data=nil)
		@name = name
		@data = {}
		@sub_tasks = []

		if not data.nil?
			parse_data(data)
		end
	end

	def encode_with(coder)
		coder.tag = nil
		if @data.length > 0
			structure = @data.clone()
			structure["tasks"] = @sub_tasks if @sub_tasks.length > 0

			if structure.has_key?("estimate")
				structure["estimate"] = estimate
			end

			coder.map = {@name => structure}
		elsif @sub_tasks.length > 0
			coder.map = {@name => @sub_tasks}
		else
			coder.scalar = @name
		end
	end

	def self.parse_tasks(data)
		sub_tasks = []
		data.each do |task|
			if task.is_a?(Hash)
				task.each do |name, task_data|
					sub_tasks <<= Task.new(name, task_data)
				end
			else
				sub_tasks <<= Task.new(task)
			end
		end

		return sub_tasks
	end

	def estimate
		estimates = @sub_tasks.collect{ |t| t.estimate }.compact
		if estimates.length > 0
			return estimates.reduce(Estimate.new, :+)
		elsif @data.has_key?("estimate")
			return @data["estimate"]
		else
			return nil
		end
	end

	private
	def parse_data(data)
		if data.is_a?(Hash)
			if data.has_key?("tasks")
				@sub_tasks = Task.parse_tasks(data["tasks"])
				data.delete("tasks")
			end

			if data.has_key?("estimate")
				data["estimate"] = Estimate.new(data["estimate"])
			end

			@data = data
		elsif data.is_a?(Array)
			@sub_tasks = Task.parse_tasks(data)
		end
	end

end

class Duration
	UNIT_LENGTHS = {
		"w" => 3600 * 8 * 5,
		"d" => 3600 * 8,
		"h" => 3600,
		"m" => 60,
		"s" => 1
	}

	def initialize(duration=nil)
		@duration = 0
		if duration.is_a?(String)
			@duration = duration.split(%r{\s+}).collect do |token|
				unit = token[-1]
				next token[0..-2].to_i * Duration::UNIT_LENGTHS.fetch(unit, 0)
			end.inject{|sum,x| sum + x}
		elsif duration.is_a?(Fixnum)
			@duration = duration
		end
	end

	def to_i
		return @duration
	end

	def to_s
		duration = @duration
		return Duration::UNIT_LENGTHS.to_a.collect do |unit,length|
			count = duration / length
			duration %= length

			next [count,unit].join() if count > 0
		end.compact.join(" ")
	end

	def +(other)
		Duration.new(@duration + other.to_i)
	end

	def encode_with(coder)
		coder.tag = nil
		coder.scalar = to_s
	end
end

class Estimate
	attr_accessor :duration, :over, :under, :fudge

	PARSER = /(?<duration>[^-+~]+)(?:\s*(?:(?:~\((?<fudge>[^\)]*)\))|(?:-\((?<under>[^\)]*)\))|(?:\+\((?<over>[^\)]*)\))))*/

	def initialize(string=nil)
		match = Estimate::PARSER.match(string)
		
		if match
			@duration = Duration.new(match[:duration]) if match[:duration]
			@over = Duration.new(match[:over]) if match[:over]
			@under = Duration.new(match[:under]) if match[:under]
			@fudge = Duration.new(match[:fudge]) if match[:fudge]
		else
			@duration = Duration.new
			@over = Duration.new
			@under = Duration.new
			@fudge = Duration.new
		end
	end

	def encode_with(coder)
		coder.tag = nil
		coder.scalar = to_s
	end

	def to_s
		result = [@duration.to_s]
		result << "~(#{@fudge})" if @fudge.to_i > 0
		result << "+(#{@over})" if @over.to_i > 0
		result << "-(#{@under})" if @under.to_i > 0

		result.join(" ")
	end

	def to_i
		@duration.to_i
	end

	def +(other)
		result = Estimate.new

		result.duration = self.duration + other.duration
		result.over = self.over + other.over
		result.under = self.under + other.under
		result.fudge = self.fudge + other.fudge

		return result
	end
end

###############################################################################
def parse_options
	options = {}
	OptionParser.new do |opts|
		opts.banner = "Usage #{ARGV[0]} [options] < datafile.yaml"

		options[:verbose] = false
		opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
			options[:verbose] = v
		end
	end.parse!

	return options
end
	
def main(options)
	data = YAML.load_stream(STDIN.read())[0]

	PP.pp(data) if options[:verbose]

	estimate = EstimationReport.new(data)
	puts(estimate.to_yaml())
end

###############################################################################

if __FILE__ == $0
	options = parse_options
	if options[:test]
		run_tests
		exit
	else
		main options
	end
end
