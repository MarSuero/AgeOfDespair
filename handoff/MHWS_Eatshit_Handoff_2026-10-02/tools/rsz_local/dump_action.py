import sys,json
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry

def val(x):
 if x is None:return None
 if hasattr(x,'value'): return x.value
 if hasattr(x,'values'): return [val(v) for v in x.values]
 return str(x)
reg=TypeRegistry(sys.argv[1]);
for p in sys.argv[2:]:
 r=RszFile();r.filepath=p;r.type_registry=reg;r.game_version='MHWilds';r.read(Path(p).read_bytes(),skip_data=False)
 print('FILE',Path(p).name,'instances',len(r.parsed_elements))
 for idx,obj in list(r.parsed_elements.items())[:40]:
  if isinstance(obj,dict): print(idx,json.dumps({k:val(v) for k,v in obj.items()},ensure_ascii=False)[:1200])
