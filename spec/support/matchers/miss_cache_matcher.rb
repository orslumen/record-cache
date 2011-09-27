# Examples:
#  1) lambda{ Person.find(22) }.should miss_cache(Person)
#     _should have at least one miss in any of the cache strategies for the Person model_
#
#  2) lambda{ Person.find(22) }.should miss_cache(Person).on(:id)
#     _should have at least one miss for the ID cache strategy for the Person model_
#
#  3) lambda{ Person.find_by_ids(22, 23, 24) }.should miss_cache(Person).on(:id).times(2)
#     _should have exactly two misses in the :id cache strategy for the Person model_
#
#  4) lambda{ Person.find_by_ids(22, 23, 24) }.should miss_cache(Person).times(3)
#     _should have exactly three misses in any of the cache strategies for the Person model_
RSpec::Matchers.define :miss_cache do |model|

  chain :on do |strategy|
    @strategy = strategy
  end

  chain :times do |nr_of_misses|
    @expected_nr_of_misses = nr_of_misses
  end

  match do |proc|
    # reset statistics for the given model and start counting
    RecordCache::Statistics.reset!(model)
    RecordCache::Statistics.start
    # call the given proc
    proc.call
    # collect statistics for the model
    @stats = RecordCache::Statistics.find(model)
    # check the nr of misses
    @nr_of_misses = @strategy ? @stats[@strategy].misses : @stats.values.map{ |s| s.misses }.sum
    # test nr of misses
    @expected_nr_of_misses ? @nr_of_misses == @expected_nr_of_misses : @nr_of_misses > 0
  end

  failure_message_for_should do |proc|
    prepare_message
    "Expected #{@strategy_msg} for #{model.name} to be missed #{@times_msg}, but found #{@nr_of_misses}: #{@statistics_msg}"
  end

  failure_message_for_should_not do |proc|
    prepare_message
    "Expected #{@strategy_msg} for #{model.name} not to be missed #{@times_msg}, but found #{@nr_of_misses}: #{@statistics_msg}"
  end

  def prepare_message
    @strategy_msg = @strategy ? "the #{@strategy} cache" : "any of the caches"
    @times_msg = @expected_nr_of_misses ? (@expected_nr_of_misses == 1 ? "exactly once" : "exactly #{@expected_nr_of_misses} times") : "at least once"
    @statistics_msg = @stats.map{|strategy, s| "#{strategy} => #{s.inspect}" }.join(", ")
  end

end 