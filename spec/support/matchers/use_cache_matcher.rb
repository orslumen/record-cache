# Examples:
#  1) lambda{ Person.find(22) }.should use_cache(Person)
#     _should perform at least one call (hit/miss) to any of the cache strategies for the Person model_
#
#  2) lambda{ Person.find(22) }.should use_cache(Person).on(:id)
#     _should perform at least one call (hit/miss) to the ID cache strategy for the Person model_
#
#  3) lambda{ Person.find_by_ids(22, 23, 24) }.should use_cache(Person).on(:id).times(2)
#     _should perform exactly two calls (hit/miss) to the :id cache strategy for the Person model_
#
#  4) lambda{ Person.find_by_ids(22, 23, 24) }.should use_cache(Person).times(3)
#     _should perform exactly three calls (hit/miss) to any of the cache strategies for the Person model_
RSpec::Matchers.define :use_cache do |model|

  chain :on do |strategy|
    @strategy = strategy
  end

  chain :times do |nr_of_calls|
    @expected_nr_of_calls = nr_of_calls
  end

  match do |proc|
    # reset statistics for the given model and start counting
    RecordCache::Statistics.reset!(model)
    RecordCache::Statistics.start
    # call the given proc
    proc.call
    # collect statistics for the model
    @stats = RecordCache::Statistics.find(model)
    # check the nr of calls
    @nr_of_calls = @strategy ? @stats[@strategy].calls : @stats.values.map{ |s| s.calls }.sum
    # test nr of calls
    @expected_nr_of_calls ? @nr_of_calls == @expected_nr_of_calls : @nr_of_calls > 0
  end

  failure_message_for_should do |proc|
    prepare_message
    "Expected #{@strategy_msg} for #{model.name} to be called #{@times_msg}, but found #{@nr_of_calls}: #{@statistics_msg}"
  end

  failure_message_for_should_not do |proc|
    prepare_message
    "Expected #{@strategy_msg} for #{model.name} not to be called #{@times_msg}, but found #{@nr_of_calls}: #{@statistics_msg}"
  end

  def prepare_message
    @strategy_msg = @strategy ? "the #{@strategy} cache" : "any of the caches"
    @times_msg = @expected_nr_of_calls ? (@expected_nr_of_calls == 1 ? "exactly once" : "exactly #{@expected_nr_of_calls} times") : "at least once"
    @statistics_msg = @stats.map{|strategy, s| "#{strategy} => #{s.inspect}" }.join(", ")
  end

end 