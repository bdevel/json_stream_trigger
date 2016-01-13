
class JsonPath

  def self.matches?(path, pattern)
    re = self.convert_to_re(pattern)
    !path.match(re).nil?
  end

  def self.convert_to_re(pattern)
    re = pattern.dup
    re = re.gsub('[', '\[').gsub(']', '\]')# escape brackets
    re.gsub!(/^\$/, '^\$') # escape $ and fix it to root
    re.gsub!(/ \\\[  \*  \\\] /x, '\[\d+\]') # change [*] to [\d+]
    re.gsub!('..', '(?<=[\.\$\]]).*[\.\]]') # change .. to match a dot, $, or ] followed by anything, and ending in a . or ]
    re.gsub!('.*.', '\.[^\.\[\]]+\.') # wild card will match any key
    
    re += '(?=$)' #'(?=$|\.)
    return Regexp.new(re)
  end
  
end

