"""Compile the driver's real group-selection prefix and exhaustively check its old binding contract."""
from pathlib import Path
import subprocess,sys
source=Path(sys.argv[1]).read_text(encoding='utf-8')
start=source.index('void RenderingDeviceDriverWebGPU::_flush_bind_groups(')
end=source.index('\n\t\tUniformSetInfo *set =',start)
body=source[start:end].replace('void RenderingDeviceDriverWebGPU::_flush_bind_groups','uint32_t selected').replace('\n\t\treturn;','\n\t\treturn 0;')
body=body.replace('const ShaderInfo *shader =','uint32_t result = 0;\n\tconst ShaderInfo *shader =')+'\nresult |= 1u << i;\n}\nreturn result;\n}\n'
preamble='''#include <stdint.h>
#include <stdio.h>
#include <algorithm>
#define MIN(a,b) std::min<uint32_t>(a,b)
constexpr uint32_t MAX_BIND_GROUPS=4;
struct Sizes {uint32_t count; uint32_t size()const{return count;}};
struct ShaderInfo {Sizes bind_group_layouts,layout_bindings;uint32_t push_constant_set_mask;};
struct CommandBufferInfo {ShaderInfo *current_shader;uint32_t bind_group_dirty_mask;bool push_constant_dirty;void *pending_bind_groups[4];};
'''
main='''int main(){unsigned cases=0;ShaderInfo shader;CommandBufferInfo cb{};cb.current_shader=&shader;
for(unsigned layouts=0;layouts<=4;layouts++)for(unsigned reflected=0;reflected<=4;reflected++)for(unsigned dirty=0;dirty<16;dirty++)for(unsigned pc=0;pc<16;pc++)for(unsigned nulls=0;nulls<16;nulls++)for(unsigned pushed=0;pushed<2;pushed++){
shader.bind_group_layouts.count=layouts;shader.layout_bindings.count=reflected;shader.push_constant_set_mask=pc;cb.bind_group_dirty_mask=dirty;cb.push_constant_dirty=pushed;unsigned expected=0;
for(unsigned i=0;i<4;i++){cb.pending_bind_groups[i]=(nulls&(1u<<i))?nullptr:&shader;if(i<layouts&&((dirty&(1u<<i))||(pushed&&(i<reflected?bool(pc&(1u<<i)):cb.pending_bind_groups[i]==nullptr))))expected|=1u<<i;}
if(selected(&cb)!=expected){printf("FAIL %u %u %u %u %u %u\\n",layouts,reflected,dirty,pc,nulls,pushed);return 1;}cases++;}
cb.current_shader=nullptr;if(selected(&cb)!=0)return 2;printf("PASS %u binding-state combinations plus null shader\\n",cases);}
'''
out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True);(out/'mask.cpp').write_text(preamble+body+main,encoding='utf-8')
subprocess.run([sys.executable,'C:/Users/davta/emsdk/upstream/emscripten/em++.py',str(out/'mask.cpp'),'-O2','-sSINGLE_FILE=1','-sENVIRONMENT=node','-o',str(out/'mask.js')],check=True)
subprocess.run(['node',str(out/'mask.js')],check=True)
