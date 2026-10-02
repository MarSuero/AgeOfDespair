import sys,json
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry

def val(x):
 if x is None:return None
 if hasattr(x,'value'): return x.value
 if hasattr(x,'values'): return [val(v) for v in x.values]
 if hasattr(x,'guid_str'): return x.guid_str
 return str(x)
reg=TypeRegistry(sys.argv[1]);
for p in sys.argv[2:]:
 r=RszFile();r.filepath=p;r.type_registry=reg;r.game_version='MHWilds'
 try:r.read(Path(p).read_bytes(),skip_data=False)
 except Exception as e: print('ERR',p,e)
 print('FILE',p)
 for i,fields in r.parsed_elements.items():
  if not isinstance(fields,dict): continue
  name=(reg.get_type_info(r.instance_infos[i].type_id) or {}).get('name','')
  if 'UseItem' in name or 'ItemIDJudgeCase' in name or 'NoActionJudge' in name:
   print(i,name,json.dumps({k:val(v) for k,v in fields.items()},ensure_ascii=False)[:2500])
