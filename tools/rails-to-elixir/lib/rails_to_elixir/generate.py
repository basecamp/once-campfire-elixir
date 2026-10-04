from __future__ import annotations
import json,re
from .common import Error,write,generated_path
from .oracle import vector

def literal(value):
    if value is None:return 'nil'
    if value is True:return 'true'
    if value is False:return 'false'
    if isinstance(value,(str,int,float)):return json.dumps(value,ensure_ascii=False).replace('#{','\\#{')
    if isinstance(value,list):return '['+', '.join(map(literal,value))+']'
    if isinstance(value,dict):return '%{'+', '.join(literal(k)+' => '+literal(v) for k,v in value.items())+'}'
    raise Error('unsupported Elixir literal')

def ident(name):
    if not re.fullmatch('[a-z][a-z0-9_]*',name):raise Error(f'{name!r} needs an explicit Elixir name mapping')
    return name

def records(root,source='vectors/schema.json',output='lib/campfire/generated/records.ex',*,force=False,tables=None):
    root,envelope=vector(root,source,'schema')
    data=envelope['data']
    if tables:
        missing=set(tables)-{t['name'] for t in data}
        if missing:raise Error('unknown tables: '+', '.join(sorted(missing)))
        data=[t for t in data if t['name'] in tables]
    out=[f'# Generated from {source}; pinned Rails {envelope["reference_sha"]}.']
    supported={'integer','bigint','primary_key','string','text','boolean','binary','datetime','timestamp','date','time','decimal','float','json','jsonb','uuid'}
    for table in data:
        name=ident(table['name']); cols=table['columns']
        if not cols or len({c['name'] for c in cols}) != len(cols):raise Error(f'{name}: empty or duplicate columns')
        for c in cols:
            ident(c['name'])
            if c.get('array') or c['type'] not in supported:raise Error(f'{name}.{c["name"]}: unsupported storage codec')
            if not isinstance(c.get('null'),bool):raise Error(f'{name}.{c["name"]}: explicit nullability required')
        module=''.join(p.title() for p in name.split('_'))+'Row'
        out.extend([f'defmodule Campfire.Generated.{module} do','  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."',
                    '  defstruct ['+', '.join(':'+c['name'] for c in cols)+']',
                    '  def table, do: '+literal(name),'  def primary_key, do: '+literal(table.get('primary_key')),
                    '  def columns, do: '+literal(cols),'end',''])
    path=generated_path(root,output);write(path,'\n'.join(out),force=force)
    return {'output':str(path),'tables':len(data),'reference_sha':envelope['reference_sha']}

def routes(root,source='vectors/routes.json',output='lib/campfire/generated/routes.ex',*,force=False):
    root,envelope=vector(root,source,'routes')
    data=envelope['data']
    if len({r['ordinal'] for r in data}) != len(data):raise Error('duplicate route ordinals')
    # Keep constraints and opaque endpoints visible rather than inventing a matcher.
    out=f'''# Generated from {source}; Rails {envelope['reference_sha']}.
defmodule Campfire.Generated.Routes do
  @moduledoc "Ordered reference route contracts. Recognition must implement constraints explicitly."
  def contracts, do: {literal(data)}
end
'''
    path=generated_path(root,output);write(path,out,force=force)
    return {'output':str(path),'routes':len(data),'reference_sha':envelope['reference_sha']}

def contract_test(root,kind,source,output,*,force=False):
    root,envelope=vector(root,source,kind)
    for row in envelope['data']:
        if 'input' not in row or 'expected' not in row:raise Error('contract test requires input/expected cases')
    out=f'''defmodule Campfire.Generated.ContractTest do
  use ExUnit.Case
  test {literal(kind+' reference contracts')} do
    for row <- {literal(envelope['data'])} do
      assert adapt(row["input"]) == row["expected"]
    end
  end
  defp adapt(_input), do: flunk("Implement this contract adapter before claiming parity")
end
'''
    path=generated_path(root,output);write(path,out,force=force)
    return {'output':str(path),'cases':len(envelope['data'])}
