import sys, json
from pathlib import Path
from file_handlers.rsz.rsz_file import RszFile
for p in sys.argv[1:]:
    data=Path(p).read_bytes()
    r=RszFile(); r.filepath=p
    try:
        r.read(data, skip_data=True)
        print('FILE',p,'bytes',len(data),'usr',r.is_usr,'instances',len(r.instance_infos),'userdata',len(r.userdata_infos),'rsz_userdata',len(r.rsz_userdata_infos))
        print('TYPES',[getattr(x,'type_id',None) for x in r.instance_infos[:40]])
        print('HEADER',r.header.__dict__ if hasattr(r.header,'__dict__') else r.header)
    except Exception as e:
        print('ERROR',p,type(e).__name__,e)
