import json,statistics,sys,collections
d=collections.defaultdict(list); cpu=collections.defaultdict(list)
f=sys.argv[1]; labels=sys.argv[2].split(',')
for l in open(f):
  r=json.loads(l); k=(r['workload'],r['conc'],r['label']); d[k].append(r['rps'])
  cpu[k].append(sum(v for n,v in r['cpu_us_by_role'].items() if 'beam' in n.lower() or 'campfire' in n.lower() or 'elixir' in n.lower()))
print('| workload | c | '+' | '.join(labels)+' |'); print('|---|---:|'+'---:|'*len(labels))
for w in ['room','messages','sidebar','search','up','post']:
  for c in [1,16]:
    b=statistics.median(d[(w,c,labels[0])])
    cells=[]
    for l in labels:
      v=d[(w,c,l)]
      if not v: cells.append('-'); continue
      m=statistics.median(v); cells.append(f"{m:,.0f} ({m/b:.2f}×, {min(v):,.0f}–{max(v):,.0f})")
    print(f"| {w} | {c} | "+' | '.join(cells)+' |')
print(); print('BEAM cpu us/request (median), c=16')
for w in ['room','messages','sidebar','search','up','post']:
  print(w, {l: round(statistics.median(cpu[(w,16,l)])) for l in labels if cpu[(w,16,l)]})
