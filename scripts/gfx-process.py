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
import numpy
from PIL import Image

#******************************************************************************
# Helper functions and classes for graphics processing script
#

def GenerateCocoPalettes(ColorsUsed, ImagePalette):
    global CocoLuvByRGB, CocoLuvByCMP
    # copy the image palette to a Python object
    PalSize = len(ImagePalette) / 3
    Palette444 = [ ord(ImagePalette[i]) for i in range(PalSize*3) ]
    # convert colors used in our input image into Luv
    NumColorsUsed = len(ColorsUsed)
    PaletteLuv = []
    for idx in ColorsUsed:
        PaletteLuv.append(ConvertRGBtoLuv(Palette444[idx*3+0], Palette444[idx*3+1], Palette444[idx*3+2]))
    # for each color used in the input image, choose RGB,CMP Coco colors with closest match
    # the elements of these arrays contain a tuple: (Lightness value, Image Palette Index 0-255, Coco Color Index 0-63)
    ClosestRGB = []
    ClosestCMP = []
    for i in range(NumColorsUsed):
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
    # add black and white to the image palette if they weren't already there
    bHasBlack = False
    bHasWhite = False
    for i in range(NumColorsUsed):
        if ClosestRGB[i][2] == 0:
            bHasBlack = True
        if ClosestRGB[i][2] == 63:
            bHasWhite = True
    if NumColorsUsed < 16 and bHasBlack == False:
        ClosestRGB.append((0.0, -1, 0))
        ClosestCMP.append((0.0, -1, 0))
        NumColorsUsed += 1
    if NumColorsUsed < 16 and bHasWhite == False:
        ClosestRGB.append((100.0, -1, 63))
        ClosestCMP.append((100.0, -1, 63))
        NumColorsUsed += 1
    # sort the proposed RGB and CMP palettes by their lightness values
    ClosestRGB.sort()
    ClosestCMP.sort()
    # generate the output objects
    CMPPalette = []
    RGBPalette = []
    ImageToCocoMap = { }
    for i in range(NumColorsUsed):
        RGBPalette.append(ClosestRGB[i][2])
        CMPPalette.append(ClosestCMP[i][2])
        if ClosestRGB[i][1] != -1:
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
    """ This is the 'ideal' algorithm
    r = (((palidx >> 4) & 2) | ((palidx >> 2) & 1)) * 0x55
    g = (((palidx >> 3) & 2) | ((palidx >> 1) & 1)) * 0x55
    b = (((palidx >> 2) & 2) | ((palidx >> 0) & 1)) * 0x55
    return (r,g,b)
    """
    # these colors are emperically based on a real CM8 monitor
    CM8Colors = [ [4, 3, 1],      [5, 8, 62],     [11, 54, 13],   [15, 69, 73],   [42, 2, 1],     [39, 7, 57],    [46, 56, 12],   [45, 64, 66], \
                  [22, 28, 159],  [63, 65, 223],  [25, 70, 159],  [65, 103, 225], [53, 31, 157],  [84, 61, 221],  [57, 72, 155],  [88, 99, 224], \
                  [42, 153, 51],  [52, 167, 106], [79, 208, 99],  [95, 220, 143], [69, 151, 54],  [74, 164, 100], [104, 206, 101],[111, 217, 138],\
                  [45, 151, 170], [86, 171, 230], [77, 205, 186], [105, 215, 237],[73, 149, 169], [102, 170, 230],[99, 197, 180], [120, 213, 234],\
                  [148, 11, 4],   [133, 12, 52],  [148, 63, 13],  [133, 60, 59],  [230, 32, 11],  [213, 23, 47],  [228, 74, 17],  [209, 64, 54],  \
                  [135, 40, 159], [146, 62, 220], [136, 77, 161], [146, 92, 220], [214, 55, 156], [199, 66, 217], [212, 88, 160], [200, 93, 217], \
                  [153, 154, 51], [144, 155, 86], [167, 210, 102],[158, 212, 125],[225, 161, 52], [204, 155, 78], [228, 213, 100],[208, 210, 114],\
                  [139, 150, 166],[154, 163, 224],[151, 199, 178],[161, 209, 229],[211, 155, 167],[197, 155, 215],[211, 201, 177],[202, 207, 223] ]
    RGB = CM8Colors[palidx]
    return (RGB[0], RGB[1], RGB[2])

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
        if BestIdx == None or IDistCMP < BestDist:
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

class LevelInfo:
    def __init__(self):
        # this LevelInfo class doesn't store everything from the level description file, only those
        # parameters which are needed for generating the tilemap
        self.mapfilename = ""
        self.tilesetidx = -1
        self.tilemapStart = None
        self.tilemapSize = None
        
def parseLevelDescription(descFilename):
    f = open(descFilename, "r").read()
    info = LevelInfo()
    section = ""
    for line in f.split("\n"):
        # remove comments and whitespace from line
        pivot = line.find("*")
        if pivot != -1:
            line = line[:pivot]
        line = line.strip()
        if len(line) < 1:
            continue
        # handle new sections
        if len(line) > 2 and line[0] == '[' and line[-1] == ']':
            section = line[1:-1].lower()
            continue
        # the only section we care about is "Level"
        if section != "level":
            continue
        # handle parameters
        pivot = line.find("=")
        if pivot != -1:
            key = line[:pivot].strip().lower()
            value = line[pivot+1:].strip()
            if key == "tileset":
                info.tilesetidx = int(value)
            elif key == "tilemapimage":
                info.mapfilename = value
            elif key == "tilemapstart":
                info.tilemapStart = [ int(c) for c in value.split(",") ]
            elif key == "tilemapsize":
                info.tilemapSize = [ int(c) for c in value.split(",") ]
            continue
        # anything else is unexpected
        print "****Error: invalid line '%s' in level description file '%s'" % (line, descFilename)
        sys.exit(2)
    return info

def parsePaletteRGB(paletteFilename):
    f = open(paletteFilename, "r").read()
    section = ""
    matrix = [ ]
    for line in f.split("\n"):
        # remove comments and whitespace from line
        pivot = line.find("*")
        if pivot != -1:
            line = line[:pivot]
        line = line.strip()
        if len(line) < 1:
            continue
        # handle new sections
        if len(line) > 2 and line[0] == '[' and line[-1] == ']':
            section = line[1:-1].lower()
            continue
        # the only section we care about is the RGB palette
        if section != "palette-rgb":
            continue
        # handle palette values
        newvalues = [int(v) for v in line.split()]
        matrix.extend(newvalues)
    # validate result
    if len(matrix) != 16:
        print "****Error: invalid RGB palette values in %s" % paletteFilename
    return matrix

class SpriteInfo:
    def __init__(self):
        self.name = ""
        self.location = [0, 0]
        self.singlepixelpos = False
        self.pixArray = [ ]
        self.hotspot = [0, 0]

class SpriteGroupInfo:
    def __init__(self):
        self.imagefilename = ""
        self.groupidx = -1
        self.paletteidx = -1
        self.transparentRGB = [0,0,0]
        self.sprites = [ ]
        
def parseSpriteDescription(descFilename):
    f = open(descFilename, "r").read()
    info = SpriteGroupInfo()
    curSprite = SpriteInfo()
    section = None
    for line in f.split("\n"):
        # remove comments and whitespace from line
        pivot = line.find("*")
        if pivot != -1:
            line = line[:pivot]
        line = line.strip()
        if len(line) < 1:
            continue
        # handle new sections
        if len(line) > 2 and line[0] == '[' and line[-1] == ']':
            # save sprite currently being defined
            if section != None:
                info.sprites.append(curSprite)
                curSprite = SpriteInfo()
            # set new section name
            section = line[1:-1].lower()
            curSprite.name = section
            continue
        # handle parameters
        pivot = line.find("=")
        if pivot != -1:
            key = line[:pivot].strip().lower()
            value = line[pivot+1:].strip()
            # global parameters
            if section == None:
                if key == "group":
                    info.groupidx = int(value)
                elif key == "image":
                    info.imagefilename = value
                elif key == "transparent":
                    info.transparentRGB = [int(v.strip()) for v in value.split(",")]
                elif key == "palette":
                    info.paletteidx = int(value)
                else:
                    print "****Error: invalid global parameter definition '%s' in sprite description file '%s'" % (line, descFilename)
                    sys.exit(2)
                continue
            # sprite parameters
            if key == "location":
                curSprite.location = [int(v.strip()) for v in value.split(",")]
            elif key == "singlepixelposition":
                if value.lower() == "true":
                    curSprite.singlepixelpos = True
                elif value.lower() == "false":
                    curSprite.singlepixelpos = False
                else:
                    print "****Error: invalid boolean value for SinglePixelPosition parameter in line '%s' in sprite description file '%s'" % (line, descFilename)
                    sys.exit(2)
            else:
                print "****Error: invalid sprite parameter definition '%s' in sprite description file '%s'" % (line, descFilename)
                sys.exit(2)
            continue
        # anything else is unexpected
        print "****Error: invalid line '%s' in sprite description file '%s'" % (line, descFilename)
        sys.exit(2)
    # save sprite currently being defined
    info.sprites.append(curSprite)
    return info

def RecursivePaint(ImgData, Width, Height, x, y, transparentIdx, pixCoordColorList):
    # return if coordinates are output image boundary
    if x < 0 or y < 0 or x >= Width or y >= Height:
        return
    # return if pixel at current coordinate is transparent
    pixColor = ImgData[y][x]
    if pixColor == transparentIdx:
        return
    # we have a non-transparent pixel, so record the color and coordinate
    pixCoordColorList.append((x, y, pixColor))
    # then make this pixel transparent to avoid processing it again
    ImgData[y][x] = transparentIdx
    # and then search all around it, in the 8-neighborhood
    RecursivePaint(ImgData, Width, Height, x-1, y-1, transparentIdx, pixCoordColorList)
    RecursivePaint(ImgData, Width, Height,   x, y-1, transparentIdx, pixCoordColorList)
    RecursivePaint(ImgData, Width, Height, x+1, y-1, transparentIdx, pixCoordColorList)
    RecursivePaint(ImgData, Width, Height, x+1, y,   transparentIdx, pixCoordColorList)
    RecursivePaint(ImgData, Width, Height, x+1, y+1, transparentIdx, pixCoordColorList)
    RecursivePaint(ImgData, Width, Height,   x, y+1, transparentIdx, pixCoordColorList)
    RecursivePaint(ImgData, Width, Height, x-1, y+1, transparentIdx, pixCoordColorList)
    RecursivePaint(ImgData, Width, Height, x-1, y,   transparentIdx, pixCoordColorList)

def FindSpritePixels(sprite, ImgData, Width, Height, ImageToCocoColor, transparentIdx):
    # start by searching around the starting point in a spiral pattern until we find a non-transparent pixel
    # direction is up, right, down, left
    x = sprite.location[0]
    y = sprite.location[1]
    dir = 0
    totalSteps = 1
    curSteps = 0
    while totalSteps < 20:
        # test for opaque pixel
        if x >= 0 and y >= 0 and x < Width and y < Height and ImgData[y][x] != transparentIdx:
            break
        # take a step
        if dir == 0:
            y -= 1
        elif dir == 1:
            x += 1
        elif dir == 2:
            y += 1
        elif dir == 3:
            x -= 1
        # advance state
        curSteps += 1
        if curSteps == totalSteps:
            curSteps = 0
            dir = (dir + 1) % 4
            if dir == 0 or dir == 2:
                totalSteps += 1
    if totalSteps >= 20:
        print "****Error: sprite %s not found within 10 pixels of location %i,%i" % (sprite.name, sprite.location[0], sprite.location[1])
        sys.exit(2)
    # now we apply a recursive painting algoritm to produce a list of all of the touching non-transparent pixels
    pixCoordColorList = [ ]
    RecursivePaint(ImgData, Width, Height, x, y, transparentIdx, pixCoordColorList)
    # get lists of all X coordinates and Y coordinates, then calculate width and height of sprite matrix
    Xcoords = [ v[0] for v in pixCoordColorList ]
    Ycoords = [ v[1] for v in pixCoordColorList ]
    minX = min(Xcoords)
    minY = min(Ycoords)
    matrixWidth = max(Xcoords) - minX + 1
    matrixHeight = max(Ycoords) - minY + 1
    # generate the matrix
    pixMatrix = [ [ -1 ] * matrixWidth for y in range(matrixHeight) ]
    for coordColor in pixCoordColorList:
        x = coordColor[0] - minX
        y = coordColor[1] - minY
        color = ImageToCocoColor[coordColor[2]]
        pixMatrix[y][x] = color
    # set the matrix and the hotspot in the sprite info struct and we're done!
    sprite.pixArray = pixMatrix
    sprite.hotspot = [sprite.location[0] - minX, sprite.location[1] - minY]

def PrintUsage():
    print "****Usage: %s <command> [arguments]" % sys.argv[0]
    print "    Commands:"
    print "        mixtiles <input_mapdesc_txt> <output_image_file>"
    print "        gentileset <input_tiledesc_txt> <output_palette_file> <output_tileset_file>"
    print "        gentilemap <input_leveldesc_txt> <input_tileset_path> <output_tilemap_file>"
    print "        gensprites <input_spritedesc_txt> <input_palette_path> <output_sprite_file>"
    sys.exit(1)

#******************************************************************************
# functions for primary commands
#

def GenerateTileset(tiledesc_fname, palette_fname, tileset_fname):
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
    # validate that there are no duplicate RGB palette entries (this would cause problems with tilesets and sprites)
    ColorDupList = [ ]
    for i in range(len(NewPalette)):
        ColorIdx = RGBPalette[i]
        if ColorIdx in ColorDupList:
            print "****Error: multiple colors in image file %s map to the same color %i in the CoCo 3 RGB Palette." % (ImageFilename, ColorIdx)
            sys.exit(2)
        ColorDupList.append(ColorIdx)
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
    # write out tileset file
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
    print "Tileset %s generated from image %s, with %i tiles, containing %i unique colors" % (tileset_fname, ImageFilename, idx, len(NewPalette))

def GenerateTilemap(leveldesc_fname, tileset_path, tilemap_fname):
    # parse tileset description file
    info = parseLevelDescription(leveldesc_fname)
    # validate tilemap parameters
    if info.tilesetidx < 0:
        print "****Error: missing tileset index in level description file %s" % leveldesc_fname
        sys.exit(3)
    if (info.tilemapStart[0] & 15) != 0 or (info.tilemapStart[1] & 15) != 0:
        print "****Error: tilemap starting coordinates are not divisible by 16!"
        sys.exit(3)
    if (info.tilemapSize[0] & 15) != 0 or (info.tilemapSize[1] & 15) != 0:
        print "****Error: tilemap size not divisible by 16!"
        sys.exit(3)
    ImageFilename = os.path.join(os.path.dirname(leveldesc_fname), info.mapfilename)
    if os.path.exists(ImageFilename) == False:
        print "****Error: image file '%s' for tilemap doesn't exist!" % ImageFilename
        sys.exit(3)
    # find the palette and tileset files
    tileset_fname = None
    palette_fname = None
    filelist = os.listdir(tileset_path)
    for fname in filelist:
        if fname[:7] == "palette" and int(fname[7:9]) == info.tilesetidx and fname[-4:] == ".txt":
            palette_fname = fname
        elif fname[:7] == "tileset" and int(fname[7:9]) == info.tilesetidx and fname[-4:] == ".txt":
            tileset_fname = fname
    if tileset_fname == None:
        print "****Error: couldn't find tileset %i file in directory %s" % (info.tilesetidx, tileset_path)
        sys.exit(3)
    if palette_fname == None:
        print "****Error: couldn't find palette %i file in directory %s" % (info.tilesetidx, tileset_path)
        sys.exit(3)
    # read the RGB palette from the palette file
    CocoPaletteRGB = parsePaletteRGB(os.path.join(tileset_path, palette_fname))
    # load tileset
    f = open(os.path.join(tileset_path, tileset_fname), "r").read()
    Tileset = [ ]
    matrix = [ ]
    for line in f.split("\n"):
        # remove comments and whitespace from line
        pivot = line.find("*")
        if pivot != -1:
            line = line[:pivot]
        line = line.strip()
        if len(line) < 1:
            continue
        # handle tile pixel values (hex)
        pix = "".join(line.split())
        if (len(pix) & 1) == 1:
            print "****Error: invalid tile pixel line length (%i) in tileset '%s'" % (len(pix), filename)
            sys.exit(1)
        for i in range(0, len(pix)):
            v = int(pix[i], 16)
            matrix.append(v)
        if len(matrix) == 256:
            Tileset.append(matrix)
            matrix = [ ]
    # Build Luv palettes for all of the colors in the Coco's 64-color palette for RGB and Composite modes
    BuildCocoColors()
    # load the tilemap image and build a map to convert each color in the tilemap to the closest 4-bit Coco color index
    # into the RGB palette we just loaded
    im = Image.open(ImageFilename)
    width = im.size[0]
    height = im.size[1]
    ImgData = im.getdata()
    PalData = im.getpalette()
    PalSize = len(PalData) / 3
    ImageToCocoColor = [ ]
    for i in range(PalSize):
        thisRGB = (PalData[i*3], PalData[i*3+1], PalData[i*3+2])
        thisLuv = ConvertRGBtoLuv(thisRGB[0], thisRGB[1], thisRGB[2])
        CocoColor = ClosestColorOf16(thisLuv, CocoPaletteRGB, CocoLuvByRGB)
        ImageToCocoColor.append(CocoColor)
    # finally, generate a tilemap by looping through the tilemap image, generating a 16x16
    # tile texture at each position, then finding the index of the texture within the tileset
    TileMap = [ ]
    for y0 in range(0,height,16):
        if y0 < info.tilemapStart[1] or y0 >= info.tilemapStart[1]+info.tilemapSize[1]:
            continue
        TileLine = [ ]
        for x0 in range(0,width,16):
            if x0 < info.tilemapStart[0] or x0 >= info.tilemapStart[0]+info.tilemapSize[0]:
                continue;
            tilePix = [ ]
            for y in range(y0,y0+16):
                for x in range(x0,x0+16):
                    imgPix = ImgData[y*width+x]
                    tilePix.append(ImageToCocoColor[imgPix])
            if tilePix not in Tileset:
                print "****Error: tile at location %i,%i in map file %s is not present in tileset!" % (x0, y0, ImageFilename)
                sys.exit(2)
            tileIdx = Tileset.index(tilePix)
            TileLine.append(tileIdx)
        TileMap.append(TileLine)
    # now write out the tilemap file
    f = open(tilemap_fname, "w")
    f.write("* The contents of this file were automatically generated with\n* gfx-process.py by processing the tilemap image file %s\n*\n" % ImageFilename)
    for tileLine in TileMap:
        f.write(" ".join(["%02x" % v for v in tileLine]))
        f.write("\n")
    f.close()
    # all done!
    print "Tilemap %s generated from image %s, with size %ix%i" % (tilemap_fname, ImageFilename, len(TileMap[0]), len(TileMap))


def GenerateSprites(spritedesc_fname, palette_path, sprite_fname):
    # parse sprite description file
    info = parseSpriteDescription(spritedesc_fname)
    # validate sprite parameters
    if info.groupidx < 0:
        print "****Error: missing group number in sprite description file %s" % spritedesc_fname
        sys.exit(3)
    if info.paletteidx < 0:
        print "****Error: missing palette number in sprite description file %s" % spritedesc_fname
        sys.exit(3)
    if info.imagefilename == "":
        print "****Error: missing image filename in sprite description file %s" % spritedesc_fname
        sys.exit(3)
    for i in range(len(info.sprites)):
        sprite = info.sprites[i]
        if sprite.name == "":
            print "****Error: missing sprite #%i name in sprite description file %s" % (i+1, spritedesc_fname)
            sys.exit(3)
    ImageFilename = os.path.join(os.path.dirname(spritedesc_fname), info.imagefilename)
    if os.path.exists(ImageFilename) == False:
        print "****Error: image file '%s' for sprite group doesn't exist!" % ImageFilename
        sys.exit(3)
    # find the palette file
    palette_fname = None
    filelist = os.listdir(palette_path)
    for fname in filelist:
        if fname[:7] == "palette" and int(fname[7:9]) == info.paletteidx and fname[-4:] == ".txt":
            palette_fname = fname
    if palette_fname == None:
        print "****Error: couldn't find palette %i file in directory %s" % (info.paletteidx, palette_path)
        sys.exit(3)
    # read the RGB palette from the palette file
    CocoPaletteRGB = parsePaletteRGB(os.path.join(palette_path, palette_fname))
    # Build Luv palettes for all of the colors in the Coco's 64-color palette for RGB and Composite modes
    BuildCocoColors()
    # load the spritesheet image and build a map to convert each color in the tilemap to the closest 4-bit Coco color index
    # into the RGB palette we just loaded
    im = Image.open(ImageFilename)
    width = im.size[0]
    height = im.size[1]
    ImgData = numpy.array(im)
    PalData = im.getpalette()
    PalSize = len(PalData) / 3
    ImageToCocoColor = [ ]
    for i in range(PalSize):
        thisRGB = (PalData[i*3], PalData[i*3+1], PalData[i*3+2])
        thisLuv = ConvertRGBtoLuv(thisRGB[0], thisRGB[1], thisRGB[2])
        CocoColor = ClosestColorOf16(thisLuv, CocoPaletteRGB, CocoLuvByRGB)
        ImageToCocoColor.append(CocoColor)
    # figure out which color index in the sprite image is considered to be transparent
    transparentIdx = None
    for i in range(PalSize):
        if PalData[i*3] == info.transparentRGB[0] and PalData[i*3+1] == info.transparentRGB[1] and PalData[i*3+2] == info.transparentRGB[2]:
            transparentIdx = i
            break
    if transparentIdx == None:
        print "****Error: transparent RGB color %s not found in sprite image %s" % (str(info.transparentRGB), ImageFilename)
        sys.exit(3)
    # find and read pixel data, generating a pixel array, for each sprite in the group
    for sprite in info.sprites:
        FindSpritePixels(sprite, ImgData, width, height, ImageToCocoColor, transparentIdx)
    # write out sprite text file
    pixValMap = { -1:"-", 0:"0", 1:"1", 2:"2", 3:"3", 4:"4", 5:"5", 6:"6", 7:"7", 8:"8", 9:"9", 10:"A", 11:"B", 12:"C", 13:"D", 14:"E", 15:"F" }
    f = open(sprite_fname, "w")
    f.write("* The contents of this file were automatically generated with\n* gfx-process.py by processing the sprite image file %s\n*\n" % ImageFilename)
    f.write("group = %i\n" % info.groupidx)
    for sprite in info.sprites:
        f.write("[%s]\n" % sprite.name)
        f.write("Width = %i\n" % len(sprite.pixArray[0]))
        f.write("Height = %i\n" % len(sprite.pixArray))
        f.write("SinglePixelPosition = %s\n" % str(sprite.singlepixelpos))
        f.write("* Hotspot = (%i,%i)\n" % (sprite.hotspot[0], sprite.hotspot[1]))
        for pixLine in sprite.pixArray:
            f.write(" ".join([pixValMap[v] for v in pixLine]))
            f.write("\n")
        f.write("\n")
    f.close()
    # all done!
    print "Sprite file %s generated from image %s, containing %i sprites" % (sprite_fname, ImageFilename, len(info.sprites))

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
        GenerateTileset(tiledesc_fname, palette_fname, tileset_fname)
    elif modeIdx == 2:
        # gentilemap
        if len(sys.argv) != 5:
            print "****Error: wrong number of arguments!"
            PrintUsage()
        leveldesc_fname = sys.argv[2]
        tileset_path = sys.argv[3]
        tilemap_fname = sys.argv[4]
        GenerateTilemap(leveldesc_fname, tileset_path, tilemap_fname)
    else:
        # gensprites
        spritedesc_fname = sys.argv[2]
        palette_path = sys.argv[3]
        sprite_fname = sys.argv[4]
        GenerateSprites(spritedesc_fname, palette_path, sprite_fname)


