import sys,json
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry

def v(x):
 if x is None:return None
 if hasattr(x,'value'):return x.value
 if hasattr(x,'guid_str'):return x.guid_str
 return str(x)
reg=TypeRegistry(sys.argv[1]);
r=RszFile();r.filepath=sys.argv[2];r.type_registry=reg;r.game_version='MHWilds';r.read(Path(sys.argv[2]).read_bytes(),skip_data=False)
for i,f in r.parsed_elements.items():
 if not isinstance(f,dict): continue
 n=(reg.get_type_info(r.instance_infos[i].type_id) or {}).get('name','')
 if 'UseItemJudge' in n or 'NotUseItemJudge' in n:
  print(i,n,{k:v(x) for k,x in f.items()})
