require "json"
values = [0.0,-0.0,1.0,0.25,1.2,10.0,100.0,12.0,120.0,123.0,1230.0,0.01,0.001,0.0001,0.00001,12.34,1001.0,100.25,1e15,1e16,1e20,1e-20,1.2345678901234567,-12.5]
puts JSON.pretty_generate(values.map { |number| { number: number, hex: Marshal.dump(number).unpack1("H*") } })
