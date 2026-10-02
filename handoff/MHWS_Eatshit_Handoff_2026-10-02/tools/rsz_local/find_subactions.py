import sys
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry

def val(x): return x.value if hasattr(x,'value') else str(x)
reg=TypeRegistry(sys.argv[1]);r=RszFile();r.filepath=sys.argv[2];r.type_registry=reg;r.game_version='MHWilds';r.read(Path(sys.argv[2]).read_bytes(),skip_data=False)
for idx,obj in r.parsed_elements.items():
 if isinstance(obj,dict) and '_Class' in obj:
  c=val(obj['_Class']).replace('\x00','')
  if any(k in c.lower() for k in ['item','use','eat','drink','potion','heal','status']): print(idx,c)
