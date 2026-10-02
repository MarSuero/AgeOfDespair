import sys, json
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry
reg=TypeRegistry(sys.argv[1])
for p in sys.argv[2:]:
    r=RszFile(); r.filepath=p; r.type_registry=reg; r.game_version='MHWilds'
    data=Path(p).read_bytes(); r.read(data, skip_data=False)
    print('FILE',Path(p).name,'instances',len(r.instance_infos),'parsed',len(r.parsed_instances))
    for i,obj in enumerate(r.parsed_instances[:8]):
        print('INSTANCE',i,type(obj).__name__,getattr(obj,'fields',obj))
