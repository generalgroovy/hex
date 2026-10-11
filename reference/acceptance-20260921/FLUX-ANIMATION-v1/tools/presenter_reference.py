"""Offline reference of supplied direction/region math, not executable GDScript.
Based on wireframe_body_presenter.gd:97-132 and eight_direction_resolver.gd:31-43.
No simulation, animation-clock or native engine behavior is emulated.
"""
import math
ROWS=['grounded','jump','cast','hit','walk','sprint','slide','roll','walk_b','sprint_b']
def classify(x:int,y:int,fallback:int=0)->int:
    fallback=fallback if 0<=fallback<8 else 0
    if x==0 and y==0:return fallback
    if abs(x)*1000000<=abs(y)*414214:return 0 if y>=0 else 4
    if abs(y)*1000000<=abs(x)*414214:return 2 if x>=0 else 6
    if x>=0:return 1 if y>=0 else 3
    return 7 if y>=0 else 5

def region(travel:int,aim:int,phase:int):
    if not all(0<=v<8 for v in [travel,aim,phase]):return None
    i=(travel*8+aim)*8+phase
    return ((i%16)*96,(i//16)*96,96,96)

def frame(state:str,aim:tuple[int,int],travel:tuple[int,int],phase:float):
    if state not in ROWS:return None
    a=classify(*aim);t=classify(*travel,a);p=0;bank='base'
    rect=(a*96,ROWS.index(state)*96,96,96)
    stem=state[:-2] if state.endswith('_b') else state
    if stem in ['walk','sprint'] and travel!=(0,0):
        if not math.isfinite(phase):return None
        p=min(7,math.floor((phase%1.0)*8));rect=region(t,a,p);bank='locomotion' if stem=='walk' else 'sprint'
    return {'bank':bank,'region':rect,'aim_index':a,'travel_index':t,'phase':p}
