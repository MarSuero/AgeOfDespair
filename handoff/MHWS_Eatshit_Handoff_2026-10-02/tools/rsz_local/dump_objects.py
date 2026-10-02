import sys,json
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry

def val(x):
 if x is None:return None
 if hasattr(x,'value'): return x.value
 if hasattr(x,'values'): return [val(v) for v in x.values]
 if hasattr(x,'guid'): return str(x)
 return str(x)
reg=TypeRegistry(sys.argv[1]);
for p in sys.argv[2:]:
 r=RszFile();r.filepath=p;r.type_registry=reg;r.game_version='MHWilds';r.read(Path(p).read_bytes(),skip_data=False)
 print('FILE',Path(p).name,'instances',len(r.parsed_elements))
 for idx,obj in r.parsed_elements.items():
  if isinstance(obj,dict):
   fields={k:val(v) for k,v in obj.items()}
   text=json.dumps(fields,ensure_ascii=False)
   if any(s in text for s in ['99','101','5','98','Item','Use','Status','Heal']): print(idx,text[:3000])
