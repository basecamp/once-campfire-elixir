require "json"
inputs = ['[1.2,1.2]','[0.0,0.0]','[-0.0,-0.0]','[1e20,1e20]','[1e100,1e100]','[1e-100,1e-100]','[2147483648,1.2,1.2]','[[1.2],"png",1.2]', '{"format":"png","linear":[0.25,0.25]}']
def symbolize(v)
 case v; when Hash; v.to_h { |k,x| [k.to_sym,symbolize(x)] }; when Array; v.map { |x| symbolize(x) }; else; v; end
end
def typed(v)
 case v; when Hash; {hash: v.map { |k,x| [k,typed(x)] }}; when Array; v.map { |x| typed(x) }; when String; {str: v}; else; v; end
end
puts JSON.pretty_generate(inputs.map { |text| data=JSON.parse(text); {typed: typed(data), hex: Marshal.dump(symbolize(data)).unpack1("H*")} })
