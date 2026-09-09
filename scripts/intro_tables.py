#!/usr/bin/env python3
"""Build the procedural flag intro and its font strip; no external image assets."""
import math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
TEXT='STUNT CAR RACER PERFORMANCE 50 HZ / 50 FPS EMULATOR PATCH  -  https://github.com/timoheimonen/amiga-stunt-car-racer-060-performance-patch'
# Original 5x7 pixel alphabet; rows are five-bit masks, MSB on the left.
GLYPHS={
'A':[14,17,17,31,17,17,17],'B':[30,17,17,30,17,17,30],
'C':[14,17,16,16,16,17,14],'D':[30,17,17,17,17,17,30],
'E':[31,16,16,30,16,16,31],'F':[31,16,16,30,16,16,16],
'G':[14,17,16,23,17,17,15],'H':[17,17,17,31,17,17,17],
'I':[14,4,4,4,4,4,14],'J':[7,2,2,2,18,18,12],
'K':[17,18,20,24,20,18,17],'L':[16,16,16,16,16,16,31],
'M':[17,27,21,21,17,17,17],'N':[17,25,21,19,17,17,17],
'O':[14,17,17,17,17,17,14],'P':[30,17,17,30,16,16,16],
'Q':[14,17,17,17,21,18,13],'R':[30,17,17,30,20,18,17],
'S':[15,16,16,14,1,1,30],'T':[31,4,4,4,4,4,4],
'U':[17,17,17,17,17,17,14],'V':[17,17,17,17,17,10,4],
'W':[17,17,17,21,21,21,10],'X':[17,17,10,4,10,17,17],
'Y':[17,17,10,4,4,4,4],'Z':[31,1,2,4,8,16,31],
'0':[14,17,19,21,25,17,14],'5':[31,16,16,30,1,1,30],
'6':[14,16,16,30,17,17,14],'/':[1,2,2,4,8,8,16],
' ': [0]*7,'-':[0,0,0,31,0,0,0],'.':[0,0,0,0,0,12,12],
',':[0,0,0,0,4,4,8],'@':[14,17,23,21,23,16,14],
'e':[0,0,14,17,31,16,14],'h':[16,16,30,17,17,17,17],
'i':[4,0,12,4,4,4,14],'m':[0,0,26,21,21,21,21],
'n':[0,0,30,17,17,17,17],'o':[0,0,14,17,17,17,14],
'p':[0,0,30,17,30,16,16],'r':[0,0,22,25,16,16,16],
't':[8,8,30,8,8,9,6],
'a':[0,0,14,1,15,17,15],'b':[16,16,30,17,17,17,30],
'c':[0,0,14,17,16,17,14],'d':[1,1,15,17,17,17,15],
'f':[6,9,8,28,8,8,8],'g':[0,15,17,17,15,1,14],
'l':[12,4,4,4,4,4,14],'s':[0,0,15,16,14,1,30],
'u':[0,0,17,17,17,19,13],':':[0,12,12,0,12,12,0]}

def tables():
    cycle=320+len(TEXT)*12
    stride=((cycle+320+31)//16)*2
    rows=bytearray(stride*8)
    for i,ch in enumerate(TEXT):
        for y,row in enumerate(GLYPHS[ch]):
            for x in range(5):
                if row & (16>>x):
                    for dx in range(2):
                        px=320+i*12+x*2+dx
                        rows[y*stride+px//8]|=128>>(px%8)
    sine=bytes(round(127*math.sin(i*2*math.pi/256))&255 for i in range(256))
    return cycle,stride,rows,sine

def curved_edges():
    """Cylinder end projection: compressed edges and foreshortened glyph height."""
    columns=[]
    for x in list(range(8,48))+list(range(272,312)):
        left=x if x<160 else 319-x
        t=(48-left)/40
        source=48-round(40*math.asin(t)/(math.pi/2))
        if x>=160:source=319-source
        height=8+round(8*math.sqrt(1-t*t))
        columns.append((source,(226-height//2)*40+x//8,128>>(x%8),height))
    return columns

def write_tables(path):
    cycle,stride,rows,sine=tables()
    def dc(data):
        return '\n'.join(' dc.b '+','.join('$%02x'%v for v in data[i:i+24]) for i in range(0,len(data),24))
    text='SCROLL_CYCLE equ %d\nSCROLL_STRIDE equ %d\nsine:\n%s\nscroll_data:\n%s\n even\n'%(cycle,stride,dc(sine),dc(rows))
    text+='scroll_edges:\n'+''.join(' dc.w %d,%d,%d,%d\n'%c for c in curved_edges())
    text+='scroll_row_offsets:\n'
    for height in range(8,17):
        text+=' dc.w '+','.join(str((y*8//height)*stride if y<height else 0) for y in range(16))+'\n'
    path.write_text(text)
