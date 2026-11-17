# LUTs per module instance of a netlist made with keep_hierarchy:
#   netgen -ofmt verilog -w <x>.ngc x.v; python3 tools/lutcount.py x.v emu 3
# (XST prints no per-module numbers). Used for the Ф0 breakdown in docs/PLAN.md.
import re,sys
src=open(sys.argv[1]).read()
mods={}
for m in re.finditer(r'^module\s+(\S+)\s*\((.*?)^endmodule',src,re.M|re.S):
    name,body=m.group(1),m.group(2)
    luts=len(re.findall(r'^\s*(?:X_)?LUT[1-6]\b',body,re.M))
    insts=re.findall(r'^\s*([A-Za-z_][\w$]*)\s+(\\\S+|\w+)\s*\(',body,re.M)
    mods[name]=(luts,[(t,i) for t,i in insts if not re.match(r'(X_)?(LUT|FD|MUX|XOR|INV|VCC|GND|BUF|RAM|DSP|ROM|SRL|CARRY|OBUF|IBUF|IOBUF|OBUFT)',t)])
memo={}
def tot(n):
    if n in memo: return memo[n]
    l,ch=mods.get(n,(0,[]))
    s=l+sum(tot(t) for t,i in ch if t in mods)
    memo[n]=s; return s
top=sys.argv[2]
def show(n,inst,d,maxd):
    t=tot(n)
    if t<150 and d>0: return
    print('  '*d+f'{inst} ({n}): {t}  own {mods[n][0]}')
    if d<maxd:
        for ty,i in sorted(mods[n][1],key=lambda x:-tot(x[0]) if x[0] in mods else 0):
            if ty in mods: show(ty,i,d+1,maxd)
show(top,top,0,int(sys.argv[3]))
