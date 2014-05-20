#!/usr/bin/env ruby

require 'yaml'
require 'pp'

###############################################################################
# class Hash
# 	def encode_with(coder, *args)
# 		coder.tag = nil
# 		coder.implicit = true
# 		coder.map = self
# 	end
# end

class Estimate
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
		#sub_task_list = @sub_tasks.map { |t| t.to_structure } if @sub_tasks.length > 0
		if @data.length > 0
			structure = @data.clone()
			structure["tasks"] = @sub_tasks if @sub_tasks.length > 0
			if structure.has_key?("estimate")
				structure["estimate"] = EstimatedTime.new(estimate)
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
			return estimates.inject{ |sum,x| sum + x }
		elsif @data.has_key?("estimate")
			return @data["estimate"].time
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
				data["estimate"] = EstimatedTime.new(data["estimate"])
			end

			@data = data
		elsif data.is_a?(Array)
			@sub_tasks = Task.parse_tasks(data)
		end
	end

end

class Duration
end

class EstimatedTime
	UNIT_LENGTHS = {
		"d" => 3600 * 8,
		"h" => 3600,
		"m" => 60,
		"s" => 1
	}

	def initialize(time)
		@time = 0
		if time.is_a?(String)
			@time = time.split(%r{\s+}).collect do |token|
				unit = token[-1]
				next token[0..-2].to_i * EstimatedTime::UNIT_LENGTHS.fetch(unit, 0)
			end.inject{ |sum,x| sum + x }
		elsif time.is_a?(Fixnum)
			@time = time
		end
	end

	def to_structure
		time = @time
		EstimatedTime::UNIT_LENGTHS.to_a.collect do |key,val|
			count = time / val
			time %= val
			next [count,key].join() if count > 0
		end.compact.join(" ")
	end

	def encode_with(coder)
		coder.tag = nil
		coder.scalar = to_structure
	end

	def time
		@time
	end
end

###############################################################################

data = YAML.load_stream(STDIN.read())[0]

#PP.pp(data)
#puts("-"*80)

estimate = Estimate.new(data)
#PP.pp(estimate.to_structure)
#puts("-"*80)
puts(estimate.to_yaml())
