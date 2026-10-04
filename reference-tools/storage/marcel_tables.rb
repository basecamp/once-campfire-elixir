# Reference-only export of Marcel's immutable MIME definitions for the native port.
require 'marcel'
require 'json'
def matches(entries)
  entries.map do |offset, value, children|
    { offset: offset.is_a?(Range) ? offset.begin : offset,
      range_end: offset.is_a?(Range) ? offset.end : nil,
      hex: value&.b&.unpack1('H*'), children: children ? matches(children) : [] }
  end
end
puts JSON.generate(version: Marcel::VERSION, extensions: Marcel::EXTENSIONS,
  type_exts: Marcel::TYPE_EXTS, parents: Marcel::TYPE_PARENTS,
  magic: Marcel::MAGIC.map { |type, entries| [type, matches(entries)] })
