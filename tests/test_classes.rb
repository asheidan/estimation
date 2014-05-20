require_relative '../estimation'
require 'test/unit'

class DurationTest < Test::Unit::TestCase
	def test_should_instantiate
		d = Duration.new
		assert_not_nil(d, "Failed to instantiate")
	end

	def test_should_create_duration_from_fixnum
		d = Duration.new(3600)
		assert_not_nil(d, "Failed to instantiate with fixnum")
	end

	def test_newly_created_duration_shoiuld_have_zero_duration
		d = Duration.new
		assert_equal(0, d.to_i)
	end

	def test_duration_with_duration_should_not_be_zero
		d = Duration.new(3600)
		assert_equal(3600, d.to_i)
	end

	def test_duration_from_string
		d = Duration.new("1h")
		assert_equal(3600, d.to_i)
	end

	def test_more_complex_duration
		d = Duration.new("1d 1h 1m 1s")
		assert_equal(1*3600*8 + 1*3600 + 1*60 + 1,
								 d.to_i)
	end
	
	def test_add_two_durations_should_work
		d1 = Duration.new(8)
		d2 = Duration.new(4)

		result = d1 + d2

		assert_equal(12, result.to_i)
	end

	def test_duration_as_yaml_should_be_pretty
		d = Duration.new("42d 7h")
		expected = "--- 42d 7h\n...\n"
		result = d.to_yaml
		assert_equal(expected, result)
	end
end


class EstimateTest < Test::Unit::TestCase
	def test_should_instantiate
		e = Estimate.new("5d")
		assert_not_nil(e)
	end

	def test_should_have_proper_length
		e = Estimate.new("1235s")
		assert_equal(1235, e.to_i)
	end

	def test_estimate_should_have_duration
		e = Estimate.new("60m")
		assert_equal(3600, e.duration.to_i)
	end

	def test_estimate_with_over_should_set_over
		e = Estimate.new("1h +(25m)")
		assert_equal(1500, e.over.to_i)
	end

	def test_estimate_with_over_and_under_should_set_over
		e = Estimate.new("1h +(25m) -(36s)")
		assert_equal(1500, e.over.to_i)
		assert_equal(36, e.under.to_i)
	end

	def test_estimate_with_fudge_should_set
		e = Estimate.new("100h ~(10m)")
		assert_equal(36E4, e.duration.to_i)
		assert_equal(600, e.fudge.to_i)
	end

	def test_add_estimates_should_add_all_values
		e1 = Estimate.new("42s +(1h) -(1d) ~(1m)")
		e2 = Estimate.new("2s +(1s) -(1m) ~(1d)")

		result = e1 + e2
		assert_equal(44, result.duration.to_i)
		assert_equal(3601, result.over.to_i)
		assert_equal(8*60*60 + 60, result.under.to_i)
		assert_equal(8*60*60 + 60, result.fudge.to_i)
	end

	def test_add_proper_estimate_with_empty
		e1 = Estimate.new("42s +(1h) -(1d) ~(1m)")
		e2 = Estimate.new

		result = e1 + e2
		assert_equal(42, result.duration.to_i)
		assert_equal(3600, result.over.to_i)
		assert_equal(8*60*60, result.under.to_i)
		assert_equal(60, result.fudge.to_i)
	end
end
