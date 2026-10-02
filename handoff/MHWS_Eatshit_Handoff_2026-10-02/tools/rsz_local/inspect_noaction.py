import sys,json
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry

def v(x):
 if x is None:return None
 if hasattr(x,"value"): return x.value
 return x
reg=TypeRegistry(sys.argv[1]);
for p in sys.argv[2:]:
 r=RszFile();r.filepath=p;r.type_registry=reg;r.game_version='MHWilds';r.read(Path(p).read_bytes(),skip_data=False)
 print('FILE',Path(p).name)
 for i,f in r.parsed_elements.items():
  if not isinstance(f,dict):continue
  n=(reg.get_type_info(r.instance_infos[i].type_id) or {}).get('name','')
  if 'NoActionJudgeCaseArg' in n or n.endswith('cItemIDJudgeCaseArg'):
   out={'i':i,'name':n}
   for k,x in f.items():
    val=v(x)
    if isinstance(val,int) and val in r.parsed_elements and isinstance(r.parsed_elements[val],dict):
     val=v(r.parsed_elements[val].get('_Value',val))
    out[k]=val
   print(json.dumps(out,ensure_ascii=False,default=str))


