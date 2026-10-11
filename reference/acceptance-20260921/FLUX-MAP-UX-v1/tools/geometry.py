"""Offline integer port of the supplied geometry. Not a Godot collision test."""
from __future__ import annotations
import math
from typing import Iterable
SCALE=1000
HW,HH,RP,CP=32000,36950,55425,64000
LOCAL=((0,-HH),(HW,-HH//2),(HW,HH//2),(0,HH),(-HW,HH//2),(-HW,-HH//2))
# HH is even; preserve the source's exact vertices, never use sqrt(3).
def center(cell):
 q,r=cell;return (CP*q+HW*r,RP*r)
def vertices(cell):
 x,y=center(cell);return [(x+a,y+b) for a,b in LOCAL]
def cross(a,b,p):return (b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0])
def inside(p,poly):return all(cross(poly[i],poly[(i+1)%len(poly)],p)>=0 for i in range(len(poly)))
def owner(p):
 x,y=p; sr=y//RP;sq=(2*RP*x-CP*y)//(2*CP*RP)
 owners=[(q,r) for q in range(sq-2,sq+3) for r in range(sr-2,sr+3) if inside(p,vertices((q,r)))]
 return min(owners) if owners else (sq,sr)
def sat_overlap(poly,rect):
 x,y,w,h=rect; corn=[(x,y),(x+w,y),(x+w,y+h),(x,y+h)]
 axes=[(1,0),(0,1)]+[(-(poly[(i+1)%len(poly)][1]-poly[i][1]),poly[(i+1)%len(poly)][0]-poly[i][0]) for i in range(len(poly))]
 for a,b in axes:
  pa=[x*a+y*b for x,y in poly]; pb=[x*a+y*b for x,y in corn]
  if max(pa)<=min(pb) or max(pb)<=min(pa):return False
 return True

def eligible(layout):
 """Reconstruct HexWorldDefinition.from_campus's visible building-only topology."""
 width,height=layout['canvas_size']; top=layout['reserved_ui_top']
 points=[(0,top*SCALE),(width*SCALE,height*SCALE),(width*SCALE,top*SCALE),(0,height*SCALE)]
 cells=[owner(p) for p in points];lo=[min(c[i] for c in cells) for i in (0,1)];hi=[max(c[i] for c in cells) for i in (0,1)]
 rectangles=[]
 for b in layout['buildings']:
  x,y,w,h=b['bounds'];rectangles.append(((x-18)*SCALE,(y-18)*SCALE,(w+36)*SCALE,(h+36)*SCALE))
 out=[]
 for q in range(lo[0]-2,hi[0]+3):
  for r in range(lo[1]-2,hi[1]+3):
   poly=vertices((q,r))
   if any(x<0 or x>width*SCALE or y<top*SCALE or y>height*SCALE for x,y in poly):continue
   if any(sat_overlap(poly,rect) for rect in rectangles):continue
   out.append((q,r))
 return sorted(out)

def point_segment_strict(p,a,b,r):
 dx,dy=b[0]-a[0],b[1]-a[1];ox,oy=p[0]-a[0],p[1]-a[1]; ll=dx*dx+dy*dy;proj=ox*dx+oy*dy
 if not ll or proj<=0:return ox*ox+oy*oy<r*r
 if proj>=ll:return (p[0]-b[0])**2+(p[1]-b[1])**2<r*r
 return (ox*dy-oy*dx)**2<r*r*ll

def selected_disk(c,r,allowed):
 if r==0:return [owner(c)] if owner(c) in allowed else []
 return [cell for cell in allowed if inside(c,vertices(cell)) or any(point_segment_strict(c,vertices(cell)[i],vertices(cell)[(i+1)%6],r) for i in range(6))]

def point_clearance(p,buildings):
 x,y=p; ds=[]
 for b in buildings:
  a,c,w,h=b['bounds'];dx=max(a-x,0,x-a-w);dy=max(c-y,0,y-c-h);ds.append(math.hypot(dx,dy))
 return min(ds,default=math.inf)

def point_segment_distance(p,a,b):
 dx,dy=b[0]-a[0],b[1]-a[1];ll=dx*dx+dy*dy
 if not ll:return math.dist(p,a)
 t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/ll))
 return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)
def segments_intersect(a,b,c,d):
 def orient(x,y,z):return cross(x,y,z)
 def on(x,y,z):return min(x[0],y[0])<=z[0]<=max(x[0],y[0]) and min(x[1],y[1])<=z[1]<=max(x[1],y[1])
 o1,o2,o3,o4=orient(a,b,c),orient(a,b,d),orient(c,d,a),orient(c,d,b)
 return (o1*o2<0 and o3*o4<0) or (o1==0 and on(a,b,c)) or (o2==0 and on(a,b,d)) or (o3==0 and on(c,d,a)) or (o4==0 and on(c,d,b))
def segment_rect_distance(a,b,rect):
 x,y,w,h=rect;corn=[(x,y),(x+w,y),(x+w,y+h),(x,y+h)]
 if any(x<=p[0]<=x+w and y<=p[1]<=y+h for p in [a,b]):return 0.0
 for i in range(4):
  if segments_intersect(a,b,corn[i],corn[(i+1)%4]):return 0.0
 return min([point_segment_distance(p,a,b) for p in corn]+[point_segment_distance(p,corn[i],corn[(i+1)%4]) for p in [a,b] for i in range(4)])
def route_clearance(points,buildings):
 return min((segment_rect_distance(a,b,ob['bounds']) for a,b in zip(points,points[1:]) for ob in buildings),default=math.inf)
