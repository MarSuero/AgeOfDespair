import sys,json
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry

def val(x):
 if x is None:return None
 if hasattr(x,'value'): return x.value
 if hasattr(x,'values'): return [val(v) for v in x.values]
 return str(x)
reg=TypeRegistry(sys.argv[1]);r=RszFile();r.filepath=sys.argv[2];r.type_registry=reg;r.game_version='MHWilds';r.read(Path(sys.argv[2]).read_bytes(),skip_data=False)
for idx,obj in r.parsed_elements.items():
 if isinstance(obj,dict):
  s=json.dumps({k:val(v) for k,v in obj.items()},ensure_ascii=False)
  if idx in range(40,50) or any(k in s.lower() for k in ['item','motion','action']): print(idx,s[:2500])
