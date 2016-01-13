require 'json'
require 'json/stream'
require_relative 'json_path'

class JsonStreamTrigger
  attr_reader :key_path, :triggers
  DEBUG=true
  
  def initialize()
    @parser = JSON::Stream::Parser.new
    
    #start_document
    #end_document
    @parser.start_object   &method(:start_object)
    @parser.end_object     &method(:end_object)
    @parser.start_array    &method(:start_array)
    @parser.end_array      &method(:end_array)
    @parser.key            &method(:key)
    @parser.value          &method(:value)
    
    @key_path       = ''
    @triggers       = {}
    @active_buffers = {}
  end

  def on(pattern, &block)
    @triggers[pattern] = block
  end
  
  def <<(bytes)
    debug "bytes: #{bytes.inspect}"
    @parser << bytes
  end
  
  def path_matches?(pattern)
    JsonPath.matches?(@key_path, pattern)
  end
  
  protected


  ################################  PARSING TRIGGERS ###########################
  #def start_document
  #end
  #def end_document
  #end
  
  def start_object
    debug "start object"
    append_buffers ',{'
    increment_path_array() do
      activate_buffers_for_matching()
    end
    @key_path << (@key_path.empty? ? "$." : '.')
  end
  
  def end_object
    debug "end object"
    trigger_block_for_matching()
    append_buffers '}'
    trim_segment(/[\.\$][^\.]+$/) # remove last .key
  end
  
  def start_array
    debug "start array"
    append_buffers ',['
    @key_path << (@key_path.empty? ? "$[]" : "[]")
    activate_buffers_for_matching()
  end
  
  def end_array
    debug "end array"
    append_buffers ']'
    
    trim_segment(/\[\d*\]+$/) # remove last [\d] and check triggers
    trigger_block_for_matching()
    trim_segment(/[\.$][^\.]+$/) # remove last .key
  end
  
  def key(k)
    debug "new key '#{k}'"
    trim_segment(/[^\.\[\]]+$/) # remove last .key[\d]
    @key_path << k
    append_buffers ",\"#{k}\":"
    activate_buffers_for_matching()
  end
  
  def value(v)
    debug "value '#{v}'"
    increment_path_array() do
      activate_buffers_for_matching()
    end
    
    append_buffers ','
    append_buffers JSON.dump(v)
    
    trigger_block_for_matching()
  end
  
  ################################ BUFFER STUFF ###########################
  
  # Called when we know the name of the object/array we are workign with
  def activate_buffers_for_matching
    @triggers.keys.each do |pattern|
      debug "checking #{@key_path} matches #{pattern}"
      if JsonPath.matches?(@key_path, pattern) && !@active_buffers.keys.include?(pattern)
        debug "Activating buffer for #{pattern.inspect}"
        @active_buffers[pattern] = ''
      end
    end
  end

  # To be called when exiting an object or array so the buffer is completed
  def trigger_block_for_matching
    active_patterns = @active_buffers.keys
    active_patterns.each do |pattern|
      if JsonPath.matches?(@key_path, pattern)
        debug "Calling trigger for '#{pattern}'"
        @triggers[pattern].call @active_buffers[pattern]
        @active_buffers.delete(pattern)
        debug "Clearing buffer for '#{pattern}'"
        #@active_buffers[pattern] = ''
      end
    end
  end

  def append_buffers(bytes)
    @active_buffers.keys.each do |k|
      # remove comma if it's not needed
      if bytes[0] == ',' && [nil, '[', '{', ':'].include?(@active_buffers[k][-1, 1])
        bytes = bytes[1..-1]
      end
      @active_buffers[k] += "#{bytes}" 
      # if ['[',']','{','}'].include?(bytes)
      #   @active_buffers[k].sub!(/,$/, '') # remove trailing comma
      #   @active_buffers[k] += "#{bytes}"
      # elsif add_comma
      #   @active_buffers[k] += "#{bytes}," # also append a comma incase in array
      # else
      #   @active_buffers[k] += "#{bytes}"
      # end
      
      debug "Appended to #{k} => '#{bytes}' to buffer '#{@active_buffers[k]}'"
    end
  end
  
  # def assign_value(obj, path, value)
  #   parts     = path.split('.').first
  #   index     = parts.shift
  #   next_path = parts.join('.')
    
  #   # Only do assigment on last value of path
  #   if next_path == ''
  #     if at_index.is_a?(Array)
  #       obj[index].push(value)
  #     else
  #       obj[index] = value
  #     end
  #   else
  #     # Go to next level of path
  #     assign_value(at_index, next_path, value)
  #   end
  # end


  ############################### PATH STUFF #######################
  
  # trim off the last segment of the key_path
  def trim_segment(re)
    @key_path.sub!(re, '')
    @key_path << '$' if @key_path == '' # add back the $ if we trimmed it off
  end
  
  def increment_path_array(&block)
    # Increment the array index if we are in an array
    # Note: Xpath indexes start at 1
    # pull out the [\d] from the last array index
    did_update = false
    @key_path.sub!(/\[(\d*)\]$/) do |m, x|
      debug "incrementing path array: #{@key_path}"
      new_i = m.match(/\[(\d*)\]/)[1].to_i + 1
      did_update = true
      debug "  new array i = #{new_i}"
      '[' + new_i.to_s + ']'
    end

    if did_update
      block.call()
    end
    
  end


  
  def debug(msg)
    indent = 60
    puts msg + (" " * [0, (indent - msg.length)].max ) + "PATH: #{@key_path}" if DEBUG
  end
  
end
