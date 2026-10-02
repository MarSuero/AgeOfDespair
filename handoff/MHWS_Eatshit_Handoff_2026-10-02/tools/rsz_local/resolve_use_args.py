import sys,json
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry
from file_handlers.rsz.rsz_data_types import GuidData

def v(x):
 if x is None:return None
 if isinstance(x,GuidData):return x.guid_str
 if hasattr(x,"value"):return x.value
 return str(x)
def resolve(r,x):
 y=v(x)
 if isinstance(y,int) and isinstance(r.parsed_elements.get(y),dict):
  d=r.parsed_elements[y]
  if '_Value' in d:return v(d['_Value'])
 return y
reg=TypeRegistry(sys.argv[1]);
for path in sys.argv[2:]:
 r=RszFile();r.filepath=path;r.type_registry=reg;r.game_version='MHWilds';r.read(Path(path).read_bytes(),skip_data=False)
 print('FILE',Path(path).name)
 for i,f in r.parsed_elements.items():
  if not isinstance(f,dict):continue
  n=(reg.get_type_info(r.instance_infos[i].type_id) or {}).get('name','')
  if n.endswith('cUseItemJudgeCaseArg') or n.endswith('cItemIDJudgeCaseArg') or n.endswith('cUseItemNoActionJudgeCaseArg'):
   print(i,n,{k:resolve(r,x) for k,x in f.items()})
