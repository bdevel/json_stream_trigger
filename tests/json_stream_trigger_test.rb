require_relative '../lib/json_stream_trigger'
require "minitest/autorun"
begin
  require 'pry'
rescue
end

def refute_trigger(pattern, bytes)
  stream = JsonStreamTrigger.new
  did_trigger = false
  stream.on(pattern) {did_trigger = true}
  stream << bytes
  refute did_trigger, "'#{pattern}' triggered for '#{bytes}' and expected not to"
end

def assert_trigger(pattern, bytes, expected)
  if expected.is_a?(Array)
    call_seq = expected.dup
  else
    call_seq = [expected.dup]
  end
  
  stream = JsonStreamTrigger.new  
  stream.on(pattern) do |actual_json|
    assert_equal call_seq[0], actual_json, "Did not return right json #{call_seq}"
    call_seq.shift
  end
  
  stream << bytes
  assert call_seq.size == 0, "'#{pattern}' did not trigger for '#{bytes}'. Values not matched: #{call_seq}"
end

  
describe JsonStreamTrigger do
  
  before do
    @stream = JsonStreamTrigger.new
  end
  
  describe "#key_path" do 
    it "should start/end object path properly" do
      @stream << '{"docs": 3'
      assert_equal "$.docs", @stream.key_path
      
      @stream << '}'
      assert_equal "$", @stream.key_path
    end
    
    it "should start/end array path properly" do
      @stream << '['
      assert_equal '$[]', @stream.key_path

      @stream << '{"name": '
      assert_equal "$[1].name", @stream.key_path
      
      @stream << '3}]'
      assert_equal "$", @stream.key_path
    end

    it "should work with nested arrays and objects" do
      @stream << '[{"list": [ {"k1": 1, '
      assert_equal "$[1].list[1].k1", @stream.key_path
      
      @stream << '"k2": 2, '
      assert_equal "$[1].list[1].k2", @stream.key_path

      # test straight values
      @stream << '"k3": [0, '
      assert_equal "$[1].list[1].k3[1]", @stream.key_path

      # test mixed Integers and objects
      @stream << '{"sk1": '
      assert_equal "$[1].list[1].k3[2].sk1", @stream.key_path

      # close out the object
      @stream << '3} ] } ]  }]'
      assert_equal "$", @stream.key_path, @stream.full_buffer
    end
    
  end


  describe "trigger matching" do
    it "triggers for straight keys" do
     assert_trigger('$.foo.bar', '{"foo": {"bar": 3}', "3")
    end

    it "buffers objects properly" do
      assert_trigger('$..foo', '{"foo": {"bar": {"baz": "xyz"}}  }', '{"bar":{"baz":"xyz"}}')
    end
    
    it "it escapes values properly" do
      assert_trigger('$.mystring', '{"mystring": "foo\"bar"}', '"foo\"bar"')
      assert_trigger('$.myint', '{"myint": 1234}', '1234')
      assert_trigger('$.myfloat', '{"myfloat": 1234.567}', '1234.567')
      assert_trigger('$.mynull', '{"mynull": null}', 'null')
    end
    
    it "it triggers on array items" do
      assert_trigger('$.my-array[*]', '{"my-array": [1,2,3]}', ['1', '2', '3'])
    end    

    it "it triggers with whole array" do
      assert_trigger('$.foo.my-array', '{"foo": {"my-array": [1,2,3]} }', '[1,2,3]')
      assert_trigger('$.foo.my-array', '{"foo": {"my-array": ["x", 1, "y", 2] }', '["x",1,"y",2]')
      assert_trigger('$.foo.my-array', '{"foo": {"my-array": [{"x": "a"}, {"y": "b"}, {"z": 0}]} }', '[{"x":"a"},{"y":"b"},{"z":0}]')
    end
    
    it "it triggers with empty arrays" do
      assert_trigger('$.my-array', '{"my-array": []}', '[]')
      assert_trigger('$.my-array', '{"my-array": [[],[]]}', '[[],[]]')
      assert_trigger('$.my-array[*]', '{"my-array": [[],[]] }', ['[]', '[]'])
    end

    it "it triggers with arrays of empty objects" do
      assert_trigger('$.my-array', '{"my-array": [{},{}]}', '[{},{}]')
      assert_trigger('$.my-array[*]', '{"my-array": [{},{}] }', ['{}', '{}'])
    end
    
  end
  
end

