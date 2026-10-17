#!/usr/bin/env python3
"""Conservative Motorola 68000 ROM entry/control-flow probe (no emulator).

Designed for analysis of 68000 Sega Mega Drive ROMs; DOES NOT execute ROM code,
resolve indirect branches globally, or perform static recompilation. An unknown
opcode terminates the current path rather than guessing instruction length.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict, deque
from dataclasses import asdict, dataclass
import hashlib
import json
from pathlib import Path
import struct

class BadInstruction(Exception):
    pass

def i16(x): return x-0x10000 if x & 0x8000 else x
def i8(x): return x-0x100 if x & 0x80 else x

@dataclass
class Inst:
    pc: int
    opcode: int
    length: int
    mnemonic: str
    operands: str = ''
    kind: str = 'linear'
    targets: list[int] | None = None
    indirect: bool = False
    note: str = ''
    def as_dict(self):
        return asdict(self)

class Decoder:
    def __init__(self,b:bytes): self.b=b
    def word(self,a):
        if a<0 or a+2>len(self.b) or a%2: raise BadInstruction(f'out of ROM/unaligned 0x{a:X}')
        return int.from_bytes(self.b[a:a+2],'big')
    def long(self,a):
        if a<0 or a+4>len(self.b) or a%2: raise BadInstruction(f'out of ROM/unaligned 0x{a:X}')
        return int.from_bytes(self.b[a:a+4],'big')
    def ea(self,pos,mode,reg,size):
        if mode==0: return pos, f'D{reg}'
        if mode==1: return pos, f'A{reg}'
        if mode==2: return pos, f'(A{reg})'
        if mode==3: return pos, f'(A{reg})+'
        if mode==4: return pos, f'-(A{reg})'
        if mode==5: return pos+2, f'{i16(self.word(pos))}(A{reg})'
        if mode==6: return pos+2, f'indexed(A{reg},0x{self.word(pos):04X})'
        if mode==7:
            if reg==0: return pos+2, f'${self.word(pos):04X}.W'
            if reg==1: return pos+4, f'${self.long(pos):08X}.L'
            if reg==2: return pos+2, f'{i16(self.word(pos))}(PC)'
            if reg==3: return pos+2, f'indexed(PC,0x{self.word(pos):04X})'
            if reg==4:
                if size==4:return pos+4,f'#${self.long(pos):08X}'
                return pos+2,f'#${self.word(pos):04X}'
        raise BadInstruction(f'illegal EA {mode}/{reg}')
    def decode(self,pc):
        o=self.word(pc)
        p=pc+2
        def done(name,operands='',kind='linear',targets=None,indirect=False,note=''):
            if p>len(self.b): raise BadInstruction('past ROM')
            return Inst(pc,o,p-pc,name,operands,kind,targets,indirect,note)
        def ea(size=2, mode=None,reg=None):
            nonlocal p
            if mode is None:mode=(o>>3)&7
            if reg is None:reg=o&7
            p,t=self.ea(p,mode,reg,size)
            return t
        # Dedicated core controls
        if o==0x4E71: return done('NOP')
        if o==0x4E75: return done('RTS',kind='return')
        if o==0x4E73: return done('RTE',kind='return')
        if o==0x4E77: return done('RTR',kind='return')
        if o==0x4E70: return done('RESET')
        if o==0x4E72:
            v=self.word(p);p+=2
            return done('STOP',f'#${v:04X}',kind='stop')
        if o==0x4AFC: return done('ILLEGAL',kind='stop')
        if (o & 0xFFF0)==0x4E40: return done('TRAP',f'#{o&15}',kind='stop')
        if (o & 0xFFF8)==0x4E50:
            v=i16(self.word(p));p+=2
            return done('LINK',f'A{o&7},#{v}')
        if (o & 0xFFF8)==0x4E58: return done('UNLK',f'A{o&7}')
        if (o & 0xFFF0)==0x4E60: return done('MOVE_USP',f'A{o&7}')
        if (o & 0xFFC0) in (0x4E80,0x4EC0):
            s=ea(4);kind='call' if (o&0x0040)==0 else 'jump';targets=[];indirect=True
            mode=(o>>3)&7; reg=o&7
            if mode==7 and reg==1:
                t=self.long(pc+2);targets=[t];indirect=False
            elif mode==7 and reg==0:
                t=i16(self.word(pc+2))&0xffffff;targets=[t];indirect=False
            elif mode==7 and reg==2:
                t=(pc+2+i16(self.word(pc+2)))&0xffffff;targets=[t];indirect=False
            elif mode==7 and reg==3: pass
            return done('JSR' if kind=='call' else 'JMP',s,kind,targets,indirect)
        if (o & 0xF000)==0x6000:
            cc=(o>>8)&15; d=o&255
            if d==0: d=i16(self.word(p));p+=2
            else:d=i8(d)
            target=(pc+2+d)&0xFFFFFF
            return done('BSR' if cc==1 else 'BRA' if cc==0 else 'B'+str(cc), f'${target:06X}',
                        'call' if cc==1 else 'jump' if cc==0 else 'branch', [target])
        if (o & 0xF0F8)==0x50C8:
            d=i16(self.word(p));p+=2
            target=(pc+2+d)&0xffffff
            return done('DBcc', f'D{o&7},${target:06X}','branch',[target])
        if (o & 0xF000)==0x5000:
            if (o&0x00C0)==0x00C0:
                s=ea(1)
                return done('Scc',s)
            size={0:1,1:2,2:4}.get((o>>6)&3)
            if size is None: raise BadInstruction('ADDQ/SUBQ invalid size')
            s=ea(size)
            return done('SUBQ' if o&0x100 else 'ADDQ',s)
        if (o & 0xF100)==0x7000:
            return done('MOVEQ',f'#{i8(o&255)},D{(o>>9)&7}')
        if (o & 0xC000)==0 and (o&0x3000):
            top=(o>>12)&3
            size={1:1,2:4,3:2}.get(top)
            if size is not None:
                src=ea(size)
                dstmode=(o>>6)&7; dstreg=(o>>9)&7
                dst=ea(size,dstmode,dstreg)
                return done('MOVEA' if dstmode==1 else 'MOVE', f'{src},{dst}',note='immediate-to-An' if dstmode==1 and src.startswith('#') else '')
        if (o & 0xF1C0)==0x41C0:
            s=ea(4)
            return done('LEA',f'{s},A{(o>>9)&7}')
        if (o & 0xFB80)==0x4880:
            mask=self.word(p);p+=2
            size=4 if o&0x40 else 2
            s=ea(size)
            return done('MOVEM',f'${mask:04X},{s}')
        if (o & 0xFFF8)==0x4840: return done('SWAP',f'D{o&7}')
        if (o & 0xFFF8) in (0x4880,0x48C0):return done('EXT',f'D{o&7}')
        if (o&0xFFC0)==0x4840: return done('PEA',ea(4))
        if (o&0xFFC0)==0x4800: return done('NBCD',ea(1))
        if o in (0x46FC,0x44FC,0x40FC):
            immediate=self.word(p);p+=2
            return done('MOVE_TO_SR_OR_CCR',f'#${immediate:04X}')
        if (o & 0xFFC0) in (0x40C0,0x42C0,0x44C0,0x46C0):return done('MOVE_SR_CCR',ea(2))
        if (o & 0xFF00) in (0x4000,0x4200,0x4400,0x4600,0x4A00):
            size={0:1,1:2,2:4}.get((o>>6)&3)
            if size is None: raise BadInstruction('unary invalid size')
            s=ea(size)
            return done({0x4000:'NEGX',0x4200:'CLR',0x4400:'NEG',0x4600:'NOT',0x4A00:'TST'}[o&0xFF00],s)
        if (o & 0xFFC0)==0x4AC0:return done('TAS',ea(1))
        # ORI, ANDI, SUBI, ADDI, EORI, CMPI including CCR/SR variants
        if (o & 0xFF00) in (0x0000,0x0200,0x0400,0x0600,0x0A00,0x0C00):
            size={0:1,1:2,2:4}.get((o>>6)&3)
            if size is None: raise BadInstruction('immediate invalid size')
            if size==4: v=self.long(p);p+=4
            else: v=self.word(p);p+=2
            s=ea(size)
            return done({0x0000:'ORI',0x0200:'ANDI',0x0400:'SUBI',0x0600:'ADDI',0x0A00:'EORI',0x0C00:'CMPI'}[o&0xFF00], f'#${v:X},{s}')
        if (o & 0xF138)==0x0108:
            disp=i16(self.word(p));p+=2
            return done('MOVEP',f'{disp}(A{o&7})')
        if (o & 0xF100)==0x0100:
            s=ea(1)
            return done('BIT_REG',s)
        if (o & 0xFF00)==0x0800:
            bit=self.word(p);p+=2
            return done('BIT_IMM',f'#{bit},{ea(1)}')
        # Single-operand math/logic operations (and register-only variants)
        if (o & 0xF000) in (0x8000,0x9000,0xB000,0xC000,0xD000):
            top=o&0xF000
            # exception: 8xxx SBCD; 9xxx SUBX; Cxxx ABCD/EXG; Dxxx ADDX
            if (o&0xF1F0) in (0x8100,0x9100,0xC100,0xD100) or (o&0xF130)==0xC100:
                return done('REG_ARITH')
            opmode=(o>>6)&7
            if opmode in (0,4):size=1
            elif opmode in (1,3,5):size=2
            elif opmode in (2,6,7):size=4
            else:raise BadInstruction('arith invalid opmode')
            s=ea(size)
            return done({0x8000:'OR_DIV',0x9000:'SUB',0xB000:'CMP_EOR',0xC000:'AND_MUL',0xD000:'ADD'}[top],s)
        if (o & 0xF000)==0xE000:
            if (o&0x00C0)==0x00C0: return done('SHIFT_MEM',ea(2))
            return done('SHIFT_REG')
        raise BadInstruction(f'unsupported instruction 0x{o:04X}')


def analyze(b:bytes, roots:list[int], max_instructions:int=50000):
    d=Decoder(b); q=deque((r,'root') for r in roots)
    insts={}; rejects={}; edges=[]; dynamic=[]; visited=set(); owner={}
    while q and len(insts)<max_instructions:
        pc,reason=q.popleft()
        if pc in visited:continue
        visited.add(pc)
        if pc >= len(b) or pc<0 or pc&1:
            rejects[pc]='invalid / outside ROM';continue
        try:
            ins=d.decode(pc)
            if any(w in owner and owner[w]!=pc for w in range(pc,pc+ins.length,2)):
                rejects[pc]='instruction overlaps prior decoded area';continue
        except BadInstruction as exc:
            rejects[pc]=str(exc);continue
        insts[pc]=ins
        for w in range(pc,pc+ins.length,2): owner[w]=pc
        nx=pc+ins.length
        if ins.indirect:
            dynamic.append(pc)
            # only resolve immediately adjacent MOVEA.L #imm,An followed by JMP (An)
            # using already decoded preceding instruction; this avoids pretending to have
            # reliable global register dataflow analysis.
            prev=[i for i in insts.values() if i.pc+i.length==pc and i.pc<pc]
            if prev and ins.mnemonic in ('JMP','JSR') and ins.operands.startswith('(A'):
                prev=prev[0]
                if prev.mnemonic=='MOVEA' and prev.operands.endswith(','+ins.operands[1:-1]):
                    raw=prev.operands.split(',',1)[0]
                    if raw.startswith('#$'):
                        t=int(raw[2:],16)
                        if 0<=t<len(b) and t%2==0:
                            ins.targets=[t]
                            ins.indirect=False
                            ins.note='resolved adjacent immediate MOVEA followed by indirect JMP/JSR'
                            dynamic.pop()
        if ins.kind in ('linear','branch','call'):
            if nx<len(b):
                edges.append((pc,nx,'fallthrough' if ins.kind=='linear' else 'return-site' if ins.kind=='call' else 'not-taken'))
                q.append((nx,'fallthrough'))
        for t in ins.targets or []:
            edges.append((pc,t,ins.kind));q.append((t,ins.kind))
    return dict(instructions=insts,rejected=rejects,edges=edges,dynamic=dynamic,queue_remaining=len(q),roots=roots)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('rom',type=Path)
    ap.add_argument('--out',type=Path,default=Path('rom_probe.json'))
    ap.add_argument('--limit',type=int,default=50000)
    args=ap.parse_args()
    b=args.rom.read_bytes()
    if b[0x100:0x10F]!=b'SEGA MEGA DRIVE':
        raise SystemExit('Expected linear BIN with SEGA MEGA DRIVE at 0x100; use SMD converter first')
    u32=lambda p:int.from_bytes(b[p:p+4],'big')
    sp,reset=u32(0),u32(4)
    # 7 core exception vectors and IRQ 4/6, only valid aligned in ROM
    vector_indices=[0,1,2,3,4,5,6,7,8,9,10,11,24,25,26,27,28,29,30,31]
    vectors=[dict(index=i,target=u32(i*4)) for i in vector_indices]
    roots=list(dict.fromkeys(v['target'] for v in vectors if 0x200 <= v['target'] < len(b) and v['target']%2==0))
    a=analyze(b,roots,args.limit)
    ins=a['instructions'];cnt=Counter(i.mnemonic for i in ins.values())
    by_kind=Counter(i.kind for i in ins.values())
    indirect=[dict(pc=f'0x{i.pc:06X}',opcode=f'0x{i.opcode:04X}',operand=i.operands) for i in ins.values() if i.indirect]
    direct_calls=sorted(set(t for i in ins.values() if i.kind=='call' for t in (i.targets or []) if t in ins))
    out={
        'warning':'Experimental conservative static analysis only. Decode graph is NOT instruction coverage measured by execution or a runnable recompile.',
        'rom':{'size':len(b),'sha256':hashlib.sha256(b).hexdigest(),'reset_sp':f'0x{sp:08X}', 'reset_pc':f'0x{reset:08X}', 'vectors':vectors},
        'static_graph':{'root_count':len(roots),'roots':[f'0x{x:06X}' for x in roots],
            'decoded_instructions':len(ins),'decoded_bytes':sum(i.length for i in ins.values()),
            'direct_call_targets':len(direct_calls),'indirect_transfers':len(indirect),'static_decode_stops':len(a['rejected']),
            'queue_remaining':a['queue_remaining'],'kinds':dict(by_kind), 'top_mnemonics':cnt.most_common(25)},
        'decoder_stop_examples':[{'pc':f'0x{k:06X}','reason':v} for k,v in list(sorted(a['rejected'].items()))[:60]],
        'indirect_transfers':indirect[:100],
        'instruction_examples':{},
    }
    # Focus on important boot/interrupt regions, provide a bounded listing
    for label,start,end in [('reset_entry',0x200,0x290),('init_after_data',0x2F4,0x385),('vertical_irq',0x1130,0x11B0),('game_entry',0x39F4,0x3A70)]:
        out['instruction_examples'][label]=[i.as_dict() for i in sorted(ins.values(),key=lambda x:x.pc) if start<=i.pc<end][:65]
    args.out.parent.mkdir(exist_ok=True,parents=True)
    args.out.write_text(json.dumps(out,indent=2,ensure_ascii=False),encoding='utf8')
    print('Saved', args.out)
    print('Roots',len(roots),'instructions',len(ins),'bytes',out['static_graph']['decoded_bytes'],'direct calls',len(direct_calls),'indirect',len(indirect),'stops',len(a['rejected']))
    for label,lines in out['instruction_examples'].items():
        print('\n'+label)
        for x in lines[:32]: print(f"{x['pc']:06X}  {x['opcode']:04X}  {x['mnemonic']:<12} {x['operands']:<26} {x['note']}")
    print('\nIndirect',indirect[:15]);print('Stops',list(sorted(a['rejected'].items()))[:15])

if __name__=='__main__':main()
