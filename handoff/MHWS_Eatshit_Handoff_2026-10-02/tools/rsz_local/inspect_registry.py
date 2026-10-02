import sys
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry
reg=TypeRegistry(sys.argv[1])
for p in sys.argv[2:]:
 r=RszFile(); r.filepath=p; r.type_registry=reg; r.game_version='MHWilds'; r.read(Path(p).read_bytes(),skip_data=False)
 print('FILE',Path(p).name,'instances',len(r.instance_infos),'elements',len(r.parsed_elements))
 for k,v in list(r.parsed_elements.items())[:5]: print('ELEM',k,type(v),getattr(v,'__dict__',v))
