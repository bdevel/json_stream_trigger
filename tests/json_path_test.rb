require_relative '../lib/json_path'
require "minitest/autorun"
begin
  require 'pry'
rescue
end

def assert_path_match(path, pattern)
  assert JsonPath.matches?(path, pattern), "Pattern #{pattern.inspect} does not match #{path.inspect} (#{JsonPath.convert_to_re(pattern)})"
end

def refute_path_match(path, pattern)
  assert !JsonPath.matches?(path, pattern), "Pattern #{pattern.inspect} does match #{path.inspect} but expected not to (#{JsonPath.convert_to_re(pattern)})"
end

describe JsonPath do

  describe "#matches?" do 
    it "does basic matching" do
      assert_path_match '$.foo.bar', '$.foo.bar'
      assert_path_match '$.foo', '$..foo'
      assert_path_match('$.foo[1].bar', '$.foo[*].bar')
      assert_path_match('$.foo[1]', '$.foo[*]')
      assert_path_match('$.foo[1].xxx.yyy.bar', '$.foo[*]..bar')
      assert_path_match('$.foo[1].xxx.bar', '$.foo[*].*.bar')
      assert_path_match('$.foo[1].bar', '$..bar')
      assert_path_match('$.foo[1]', '$.*[*]')
      
      assert_path_match('$.foo.bar', '$.*.bar')
      assert_path_match('$.foo', '$.*')
      
    end
    
    it "does not match things it shouldn't" do
      refute_path_match '$.foobar', '$.foo'
      refute_path_match '$.food.bar', '$.foo..bar'
      refute_path_match '$.foo.bar', '$..foo'
      refute_path_match('$.foo.xxx.yyy.bar', '$.foo.*.bar')
      refute_path_match('$.foo.bar[1]', '$.*[*]')
      refute_path_match('$.foo.bar', '$.*')
    end
    
  end
  
  
end

