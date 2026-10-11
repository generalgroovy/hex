param([Parameter(Mandatory=$true)][string]$ImagePath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
public static class LandingCandidateAudit {
    public static object Inspect(byte[] pixels, int width, int height, int stride) {
        long transparent=0, partial=0, opaque=0, paletteMiss=0;
        var colors = new HashSet<int>();
        var palette = new HashSet<int> { 0x16212a,0x403424,0x98805a,0xe2d4a7 };
        var frames = new List<object>();
        int cellWidth=width/3, cellHeight=height/2;
        for(int frame=0;frame<6;frame++) {
            int cx=(frame%3)*cellWidth, cy=(frame/3)*cellHeight;
            int minX=cellWidth,minY=cellHeight,maxX=-1,maxY=-1;
            long visible=0, centerPixels=0;
            for(int y=0;y<cellHeight;y++) for(int x=0;x<cellWidth;x++) {
                int offset=(cy+y)*stride+(cx+x)*4;
                int b=pixels[offset],g=pixels[offset+1],r=pixels[offset+2],a=pixels[offset+3];
                if(a==0) { transparent++; continue; }
                if(a==255) opaque++; else partial++;
                int rgb=(r<<16)|(g<<8)|b;
                colors.Add((a<<24)|rgb);
                if(!palette.Contains(rgb)) paletteMiss++;
                visible++;
                minX=Math.Min(minX,x);minY=Math.Min(minY,y);maxX=Math.Max(maxX,x);maxY=Math.Max(maxY,y);
                if(x>=224 && x<288) centerPixels++;
            }
            int nonuniformBlocks=0;
            for(int by=0;by<cellHeight;by+=16) for(int bx=0;bx<cellWidth;bx+=16) {
                int first=-1; bool varied=false;
                for(int y=by;y<Math.Min(by+16,cellHeight);y++) for(int x=bx;x<Math.Min(bx+16,cellWidth);x++) {
                    int i=(cy+y)*stride+(cx+x)*4;
                    int rgba=pixels[i+3]==0 ? 0 : (pixels[i+3]<<24)|(pixels[i+2]<<16)|(pixels[i+1]<<8)|pixels[i];
                    if(first==-1) first=rgba; else if(first!=rgba) varied=true;
                }
                if(varied) nonuniformBlocks++;
            }
            frames.Add(new { frame=frame, visible_pixels=visible, alpha_bounds=new[]{minX,minY,maxX,maxY}, open_center_nontransparent_pixels=centerPixels, nonuniform_16px_blocks=nonuniformBlocks });
        }
        return new { width=width,height=height,transparent_pixels=transparent,partial_alpha_pixels=partial,opaque_pixels=opaque,unique_visible_rgba=colors.Count,pixels_outside_exact_palette=paletteMiss,frames=frames };
    }
}
'@
$candidateImage = [System.Drawing.Bitmap]::new((Resolve-Path -LiteralPath $ImagePath).Path)
try {
    $candidateRect = [System.Drawing.Rectangle]::new(0,0,$candidateImage.Width,$candidateImage.Height)
    $candidateData = $candidateImage.LockBits($candidateRect,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        if ($candidateData.Stride -le 0) { throw 'Unexpected nonpositive stride' }
        $candidateBytes = [byte[]]::new($candidateData.Stride*$candidateImage.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($candidateData.Scan0,$candidateBytes,0,$candidateBytes.Length)
        [LandingCandidateAudit]::Inspect($candidateBytes,$candidateImage.Width,$candidateImage.Height,$candidateData.Stride) | ConvertTo-Json -Depth 8
    } finally { $candidateImage.UnlockBits($candidateData) }
} finally { $candidateImage.Dispose() }
