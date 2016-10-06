#!/usr/bin/env python
#********************************************************************************
# DynoSprite - scripts/gfx-process.py
# Copyright (c) 2016, Richard Goedeken
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#********************************************************************************

import os
import sys
import math
from PIL import Image

#******************************************************************************
# Helper functions for image building script
#

def GenerateCocoPalettes(ColorsUsed, ImagePalette):
    global CocoLuvByRGB, CocoLuvByCMP
    # copy the image palette to a Python object and add 2 extra colors at the end (black and white)
    PalSize = len(ImagePalette) / 3
    Palette444 = [ ord(ImagePalette[i]) for i in range(PalSize*3) ]
    Palette444.append(0)
    Palette444.append(0)
    Palette444.append(0)
    Palette444.append(255)
    Palette444.append(255)
    Palette444.append(255)
    # add black and white to the image palette if they weren't already there
    bHasBlack = False
    bHasWhite = False
    for idx in ColorsUsed:
        rgbsum = Palette444[idx*3+0] + Palette444[idx*3+1] + Palette444[idx*3+2]
        if rgbsum == 0:
            bHasBlack = True
        if rgbsum == 255*3:
            bHasWhite = True
    if len(ColorsUsed) < 16 and bHasBlack == False:
        ColorsUsed.append(PalSize)
    if len(ColorsUsed) < 16 and bHasWhite == False:
        ColorsUsed.append(PalSize+1)
    # convert colors used in our input image into Luv
    PaletteLuv = []
    for idx in ColorsUsed:
        PaletteLuv.append(ConvertRGBtoLuv(Palette444[idx*3+0], Palette444[idx*3+1], Palette444[idx*3+2]))
    # for each color used in the input image, choose RGB,CMP Coco colors with closest match
    # the elements of these arrays contain a tuple: (Lightness value, Image Palette Index 0-255, Coco Color Index 0-63)
    ClosestRGB = []
    ClosestCMP = []
    for i in range(len(ColorsUsed)):
        idx = ColorsUsed[i]
        BestRGBIdx = None
        BestCMPIdx = None
        BestRGBDist = -1
        BestCMPDist = -1
        for j in range(64):
            JDistRGB = Vector3Distance(PaletteLuv[i], CocoLuvByRGB[j])
            JDistCMP = Vector3Distance(PaletteLuv[i], CocoLuvByCMP[j])
            if BestRGBIdx == None or JDistRGB <= BestRGBDist:
                BestRGBIdx = j
                BestRGBDist = JDistRGB
            if BestCMPIdx == None or JDistCMP <= BestCMPDist:
                BestCMPIdx = j
                BestCMPDist = JDistCMP
        # we must sort our Coco palettes in the same way, so that the source image pixels get
        # mapped to the same index in both the RGB and CMP palettes
        Lightness = CocoLuvByCMP[BestCMPIdx][0]
        ClosestRGB.append((Lightness, idx, BestRGBIdx))
        ClosestCMP.append((Lightness, idx, BestCMPIdx))
    # sort the proposed RGB and CMP palettes by their lightness values
    ClosestRGB.sort()
    ClosestCMP.sort()
    # generate the output objects
    CMPPalette = []
    RGBPalette = []
    ImageToCocoMap = { }
    for i in range(len(ColorsUsed)):
        RGBPalette.append(ClosestRGB[i][2])
        CMPPalette.append(ClosestCMP[i][2])
        ImageToCocoMap[ClosestRGB[i][1]] = i;
    # pad them out to 16 colors if necessary
    while len(CMPPalette) < 16:
        CMPPalette.append(63)
        RGBPalette.append(63)
    # all done
    return (CMPPalette, RGBPalette, ImageToCocoMap)

def BuildCocoColors():
    global CocoLuvByRGB, CocoLuvByCMP
    CocoLuvByRGB = []
    CocoLuvByCMP = []
    for i in range(64):
        (r,g,b) = GetRGBColor(i)
        CocoLuvByRGB.append(ConvertRGBtoLuv(r,g,b))
        (r,g,b) = GetCompositeColor(i)
        CocoLuvByCMP.append(ConvertRGBtoLuv(r,g,b))

def GetRGBColor(palidx):
    r = (((palidx >> 4) & 2) | ((palidx >> 2) & 1)) * 0x55
    g = (((palidx >> 3) & 2) | ((palidx >> 1) & 1)) * 0x55
    b = (((palidx >> 2) & 2) | ((palidx >> 0) & 1)) * 0x55
    return (r,g,b)

def GetCompositeColor(palidx):
    if palidx == 0:
        r = g = b = 0
    elif palidx == 16:
        r = g = b = 47
    elif palidx == 32:
        r = g = b = 120
    elif palidx == 48 or palidx == 63:
        r = g = b = 255
    else:
        w = .4195456981879*1.01
        contrast = 70
        saturation = 92
        brightness = -50
        brightness += ((palidx / 16) + 1) * contrast
        offset = (palidx % 16) - 1 + (palidx / 16)*15
        r = math.cos(w*(offset +  9.2)) * saturation + brightness
        g = math.cos(w*(offset + 14.2)) * saturation + brightness
        b = math.cos(w*(offset + 19.2)) * saturation + brightness
        if r < 0:
            r = 0
        elif r > 255:
            r = 255
        if g < 0:
            g = 0
        elif g > 255:
            g = 255
        if b < 0:
            b = 0
        elif b > 255:
            b = 255
    return (r,g,b)

def ConvertRGBtoLuv(r,g,b):
    # calculate liner color components
    RGBLog = (r, g, b)
    RGBLinear = [0, 0, 0]
    for j in range(3):
        fVal = RGBLog[j] / 255.0;
        if fVal <= 0.04045:
            RGBLinear[j] = fVal / 12.92;
        else:
            RGBLinear[j] = math.pow((fVal + 0.055) / 1.055, 2.4);
    # convert to XYZ
    fX = 0.4124 * RGBLinear[0] + 0.3576 * RGBLinear[1] + 0.1805 * RGBLinear[2];
    fY = 0.2126 * RGBLinear[0] + 0.7152 * RGBLinear[1] + 0.0722 * RGBLinear[2];
    fZ = 0.0193 * RGBLinear[0] + 0.1192 * RGBLinear[1] + 0.9505 * RGBLinear[2];
    # convert to L*u*v*
    if fY <= 0.008856:
        fL = fY * 24389 / 27
    else:
        fL = 116.0 * math.pow(fY, 1.0/3.0) - 16.0;
    if fX == 0.0 and fY == 0.0 and fZ == 0.0:
        fU_ = 0.0
        fV_ = 0.0
    else:
        fU_ = 4 * fX / (fX + 15 * fY + 3 * fZ);
        fV_ = 9 * fY / (fX + 15 * fY + 3 * fZ);
    Luv = (fL, 13 * fL * (fU_ - 0.2009), 13 * fL * (fV_ - 0.4610))
    return Luv

def Vector3Distance(v1, v2):
    diff = (v1[0]-v2[0], v1[1]-v2[1], v1[2]-v2[2])
    return diff[0]*diff[0] + diff[1]*diff[1] + diff[2]*diff[2]

def ClosestColorOf16(LuvColor, CocoPalette, PaletteColorset):
    global CocoLuvByRGB, CocoLuvByCMP
    BestIdx = None
    BestDist = -1
    for i in range(16):
        IDistCMP = Vector3Distance(LuvColor, PaletteColorset[CocoPalette[i]])
        if BestIdx == None or IDistCMP <= BestDist:
            BestIdx = i
            BestDist = IDistCMP
    return BestIdx

class ImageColors:
    def __init__(self):
        self.back = None
        self.fore = None
        self.bar = None
        self.indices = None

class TilesetInfo:
    def __init__(self):
        self.filename = ""
        self.tilesetStart = [0, 0]
        self.tilesetSize = [0, 0]
        self.tiledesc_lines = [ ]
        
def parseTilesetDescription(descFilename):
    f = open(descFilename, "r").read()
    info = TilesetInfo()
    for line in f.split("\n"):
        info.tiledesc_lines.append(line)
        # remove comments and whitespace from line
        pivot = line.find("*")
        if pivot != -1:
            line = line[:pivot]
        line = line.strip()
        if len(line) < 1:
            continue
        # handle parameters
        pivot = line.find("=")
        if pivot != -1:
            key = line[:pivot].strip().lower()
            value = line[pivot+1:].strip()
            if key == "image":
                info.filename = value
            elif key == "tilesetstart":
                info.tilesetStart = [ int(c) for c in value.split(",") ]
            elif key == "tilesetsize":
                info.tilesetSize = [ int(c) for c in value.split(",") ]
            else:
                print "****Error: unknown parameter %s in tileset description file %s" % (key, descFilename)
                sys.exit(2)
            continue
        # anything else is unexpected
        print "****Error: invalid line '%s' in tileset description file '%s'" % (line, descFilename)
        sys.exit(2)
    return info

def PrintUsage():
    print "****Usage: %s <command> [arguments]" % sys.argv[0]
    print "    Commands:"
    print "        mixtiles <input_mapdesc_txt> <output_image_file>"
    print "        gentileset <input_tiledesc_txt> <output_palette_file> <output_tileset_file>"
    print "        gentilemap <input_leveldesc_txt> <output_tilemap_file>"
    print "        gensprites <input_spritedesc_txt> <input_palette_file> <output_sprite_file>"
    sys.exit(1)

#******************************************************************************
# main function for standard script execution
#

if __name__ == "__main__":
    global CocoLuvByRGB, CocoLuvByCMP
    print "DynoSprite Graphics Processing script"
    # get script mode
    commandList = [ "mixtiles", "gentileset", "gentilemap", "gensprites" ]
    if len(sys.argv) < 2:
        PrintUsage()
    command = sys.argv[1]
    if command not in commandList:
        print "****Error: invalid command '%s'" % command
        PrintUsage()
    modeIdx = commandList.index(command)
    # handle each command
    if modeIdx == 0:
        # mixtiles
        print "****Error: mixtiles not yet supported!"
        sys.exit(2)
    elif modeIdx == 1:
        # gentileset
        if len(sys.argv) != 5:
            print "****Error: wrong number of arguments!"
            PrintUsage()
        tiledesc_fname = sys.argv[2]
        palette_fname = sys.argv[3]
        tileset_fname = sys.argv[4]
        # parse tileset description file
        info = parseTilesetDescription(tiledesc_fname)
        # validate tileset parameters
        if (info.tilesetStart[0] & 15) != 0 or (info.tilesetStart[1] & 15) != 0:
            print "****Error: tilemap starting coordinates are not divisible by 16!"
            sys.exit(3)
        if (info.tilesetSize[0] & 15) != 0 or (info.tilesetSize[1] & 15) != 0:
            print "****Error: tilemap size not divisible by 16!"
            sys.exit(3)
        ImageFilename = os.path.join(os.path.dirname(tiledesc_fname), info.filename)
        if os.path.exists(ImageFilename) == False:
            print "****Error: image file '%s' for tileset doesn't exist!" % ImageFilename
            sys.exit(3)
        # Build Luv palettes for all of the colors in the Coco's 64-color palette for RGB and Composite modes
        BuildCocoColors()
        # create PIL Image object and get the resolution
        im = Image.open(ImageFilename)
        width = im.size[0]
        height = im.size[1]
        ImgData = im.getdata()
        # validate image parameters
        if (width & 15) != 0:
            print "****Error: width of image '%s' is not divisible by 16." % ImageFilename
            sys.exit(2)
        if im.mode != 'P':
            print "****Error: image '%s' is not a palette (indexed color) image" % ImageFilename
            sys.exit(3)
        # make a histogram of the palette entries
        ColorHist = [ 0 for j in range(256) ]
        for j in range(width*height):
            pix = ImgData[j]
            ColorHist[pix] = ColorHist[pix] + 1
        # make a new palette which will only contain the colors which are used in this input image
        NewPalette = []
        for j in range(256):
            if ColorHist[j] > 0:
                NewPalette.append(j)
        # we cannot make a Coco image out of this if it uses more than 16 colors
        if len(NewPalette) > 16:
            print "****Error: image '%s' uses more than 16 colors! (actual=%i)" % (ImageFilename, len(NewPalette))
            sys.exit(4)
        # generate palettes and palette mappings for both Composite and RGB mode on Coco
        (CMPPalette, RGBPalette, ImageToCocoMap) = GenerateCocoPalettes(NewPalette, im.palette.getdata()[1])
        # write out palette description file
        f = open(palette_fname, "w")
        f.write("* The contents of this file were automatically generated with\n* gfx-process.py by processing the tileset description file below.\n* Path: %s\n*\n" % tiledesc_fname)
        f.write("\n".join(["* " + line for line in info.tiledesc_lines]))
        f.write("\n")
        f.write("[Palette-CMP]\n")
        for i in range(16):
            if (i & 3) != 3:
                f.write("%02i " % CMPPalette[i])
            else:
                f.write("%02i\n" % CMPPalette[i])
        f.write("\n")
        f.write("[Palette-RGB]\n")
        for i in range(16):
            if (i & 3) != 3:
                f.write("%02i " % RGBPalette[i])
            else:
                f.write("%02i\n" % RGBPalette[i])
        f.close()
        # generate a list of all the unique tiles
        TileList = [ ]
        for y0 in range(0,height,16):
            if y0 < info.tilesetStart[1] or y0 >= info.tilesetStart[1]+info.tilesetSize[1]:
                continue
            for x0 in range(0,width,16):
                if x0 < info.tilesetStart[0] or x0 >= info.tilesetStart[0]+info.tilesetSize[0]:
                    continue;
                tilePix = [ ]
                for y in range(y0,y0+16):
                    for x in range(x0,x0+16):
                        imgPix = ImgData[y*width+x]
                        tilePix.append(ImageToCocoMap[imgPix])
                if tilePix not in TileList:
                    TileList.append(tilePix)
        # write out tilemap file
        f = open(tileset_fname, "w")
        f.write("* The contents of this file were automatically generated with\n* gfx-process.py by processing the tileset description file below.\n* Path: %s\n*\n" % tiledesc_fname)
        f.write("\n".join(["* " + line for line in info.tiledesc_lines]))
        f.write("\n")
        idx = 0
        for tilePix in TileList:
            f.write("* Tile %i\n" % idx)
            idx += 1
            for i in range(256):
                if (i & 15) != 15:
                    f.write("%x " % tilePix[i])
                else:
                    f.write("%x\n" % tilePix[i])
            f.write("\n")
        f.close()
        # all done!
        print "Tileset %s generated, with %i tiles, containing %i unique colors" % (ImageFilename, idx, len(NewPalette))
    elif modeIdx == 2:
        # gentilemap
        print "Error: gentilemap not yet supported!"
        sys.exit(2)
    else:
        # gensprites
        print "Error: gensprites not yet supported!"
        sys.exit(2)

