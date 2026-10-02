import sys,json
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry

def val(x):
    if x is None:return None
    if hasattr(x,'value'): return x.value
    if hasattr(x,'values'): return [val(v) for v in x.values]
    return str(x)
reg=TypeRegistry(sys.argv[1]); r=RszFile(); r.filepath=sys.argv[2]; r.type_registry=reg; r.game_version='MHWilds'; r.read(Path(sys.argv[2]).read_bytes(),skip_data=False)
keys=['_Index','_ItemId','_SortId','_Type','_ItemGroup','_TextType','_IconType','_MaxCount','_EnableOnRaptor','_Eatable','_Window','_Infinit','_Heal','_Battle','_Special','_ForMoney','_OutBox','_NonLevelShell']
for idx,obj in r.parsed_elements.items():
 if isinstance(obj,dict) and val(obj.get('_ItemId')) in (5,99,101): print(json.dumps({'instance':idx,**{k:val(obj.get(k)) for k in keys}},ensure_ascii=False))
