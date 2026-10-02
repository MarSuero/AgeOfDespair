import sys,json
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry

def val(x):
 if x is None:return None
 if hasattr(x,'value'): return x.value
 return str(x)
reg=TypeRegistry(sys.argv[1]);
for p in sys.argv[2:]:
 r=RszFile();r.filepath=p;r.type_registry=reg;r.game_version='MHWilds';r.read(Path(p).read_bytes(),skip_data=False)
 print('FILE',Path(p).name)
 for idx,obj in r.parsed_elements.items():
  if isinstance(obj,dict):
   c=str(val(obj.get('_Class','')))
   if any(k.lower() in c.lower() for k in ['item','use','eat','drink','potion','heal','status']): print(idx,c)
