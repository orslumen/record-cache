# Examples:
#  1) lambda{ Person.find(22) }.should log(:debug, %(UniqueIndexCache on 'id' hit for ids 1)
#     _should have at least one debug log statement as given above_
#
#  2) lambda{ Person.find(22) }.should log(:debug, /^UniqueIndexCache/)
#     _should have at least one debug log statement starting with UniqueIndexCache_
RSpec::Matchers.define :log do |severity, expected|

  match do |proc|
    logger = RecordCache::Base.logger
    # override the debug/info/warn/error method
    logger.instance_variable_set(:@found_messages, [])
    logger.instance_variable_set(:@found, false)
    logger.class.send(:alias_method, "orig_#{severity}", severity)
    logger.class.send(:define_method, severity) do |progname = nil, &block|
      unless @found
        actual= progname.is_a?(String) ? progname : block ? block.call : nil
        unless actual.blank?
          @found = actual.is_a?(String) && expected.is_a?(Regexp) ? actual =~ expected : actual == expected
          @found_messages << actual
        end
      end
    end
    # call the given proc
    proc.call
    # redefine
    logger.class.send(:alias_method, severity, "orig_#{severity}")
    # the result
    @found_messages = logger.instance_variable_get(:@found_messages)
    @found = logger.instance_variable_get(:@found)
  end

  failure_message_for_should do |proc|
    "Expected #{@found_messages.inspect} to include #{expected.inspect}"
  end

  failure_message_for_should_not do |proc|
    "Expected #{@found_messages.inspect} not to include #{expected.inspect}"
  end

end 