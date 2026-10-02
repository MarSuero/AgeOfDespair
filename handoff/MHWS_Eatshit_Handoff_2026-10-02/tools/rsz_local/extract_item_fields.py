import sys,json
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry

def val(x):
    if x is None:return None
    if hasattr(x,'value'): return x.value
    if hasattr(x,'values'): return [val(v) for v in x.values]
    return str(x)
reg=TypeRegistry(sys.argv[1]); p=sys.argv[2]
r=RszFile(); r.filepath=p; r.type_registry=reg; r.game_version='MHWilds'; r.read(Path(p).read_bytes(),skip_data=False)
for idx,obj in r.parsed_elements.items():
    if not isinstance(obj,dict): continue
    item_id=val(obj.get('_ItemId'))
    if item_id in (1,4,5,98,100):
        print(json.dumps({'instance':idx,'item_id':item_id,**{k:val(obj.get(k)) for k in ['_Index','_SortId','_Type','_ItemGroup','_TextType','_IconType','_MaxCount','_EnableOnRaptor','_Eatable','_Window','_Infinit','_Heal','_Battle','_Special','_ForMoney','_OutBox','_NonLevelShell']}},ensure_ascii=False))
