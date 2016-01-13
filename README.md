# json_stream_trigger

Instead of parsing a huge JSON files and loading it into memory,
this library will stream the bytes through
[json-stream](https://github.com/dgraham/json-stream) and only
creates a small buffer for objects whose JSONPath matches a pattern you specify.
When the object is completed, the specified block will be called.

## Example:

```ruby
f = File.open('really_big_file.json')
stream = JsonStreamTrigger.new()

# Match each array item. Note, $.data would give you the whole array
stream.on('$.data[*]') do |hash|
  import(hash)
end

# Will match for $.any.sub[*].item.meta
stream.on('$..meta') do |hash|
  save_meta(hash)
end

# read in 1MB chunks
while chunk = f.read(1024)
  stream << chunk
end

```

## Path Details
The JSONPaths are similar to XPath notation. `$` is the root,
single wild card keys can be done with `$.docs[*].*.name`,
or you can do muli-level wildcard with `$.docs..name`.
[More info on JSONPath](http://goessner.net/articles/JsonPath/)

A few more examples:

```json
{
  docs: [
    {id: 1},
    {id: 2},
    {id: 3},
    {id: 4},
    {
      id: 5,
      user: {
        name: "Tyler"
      }
    }
  ]
}
```

```ruby
on('$.docs[*].id') # triggers for id property of every item in docs array
on('$.docs') # returns full array of items
on('$.docs[*]') # triggers for each item in the array
on('$.docs[1].id') # returns value of ID 1
on('$.docs[*].*.name') # returns 'Tyler'
on('$..name') # matches any value who's key is 'name'
```

