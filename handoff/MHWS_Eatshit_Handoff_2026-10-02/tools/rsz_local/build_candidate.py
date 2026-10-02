from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry

def v(x): return x.value if hasattr(x,'value') else None
reg=TypeRegistry('D:/mhws-eatshit/tools/rsz_local/resources/data/dumps/rszmhwilds.json')
p=Path('D:/mhws-eatshit/extracted/base/natives/stm/gamedesign/common/item/itemdata.user.3')
r=RszFile(); r.filepath=str(p); r.type_registry=reg; r.game_version='MHWilds'; r.read(p.read_bytes(),skip_data=False)
rows={v(o.get('_ItemId')):o for o in r.parsed_elements.values() if isinstance(o,dict) and '_ItemId' in o}
target=rows[99]; source=rows[5]
for k in ['_TextType','_Window','_Eatable','_Heal','_EnableOnRaptor','_OutBox','_Battle','_Special','_ForMoney','_NonLevelShell']:
    target[k].value=source[k].value
out=Path('D:/mhws-eatshit/extracted/candidate/itemdata.user.3'); out.parent.mkdir(parents=True,exist_ok=True); out.write_bytes(r.build())
print(out, out.stat().st_size)
print({k:v(target[k]) for k in ['_ItemId','_TextType','_Window','_Eatable','_Heal','_EnableOnRaptor','_OutBox']})
