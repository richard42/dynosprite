#!/usr/bin/env python
#********************************************************************************
# DynoSprite - scripts/build-images.py
# Copyright (c) 2014, Richard Goedeken
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
from compression import *
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

def parseDescription(descFilename):
    f = open(descFilename, "r").read()
    ImageColorDict = { }
    curImage = None
    for line in f.split("\n"):
        # remove comments and whitespace from line
        pivot = line.find("*")
        if pivot != -1:
            line = line[:pivot]
        line = line.strip()
        if len(line) < 1:
            continue
        # handle new sections
        if len(line) > 7 and line[:6].lower() == '[image' and line[-1] == ']':
            # create new object for this section and put it in the dictionary
            curImage = ImageColors()
            ImageNum = int(line[6:-1])
            ImageColorDict[ImageNum] = curImage
            continue
        # handle color parameters
        pivot = line.find("=")
        if curImage is not None and pivot != -1:
            key = line[:pivot].strip().lower()
            value = line[pivot+1:].strip()
            iValue = int(value, 16)
            r = (iValue >> 16) & 0xff
            g = (iValue >> 8) & 0xff
            b = (iValue & 0xff)
            LuvColor = ConvertRGBtoLuv(r,g,b)
            if key.lower() == "backgroundcolor":
                curImage.back = LuvColor
            elif key.lower() == "foregroundcolor":
                curImage.fore = LuvColor
            elif key.lower() == "progresscolor":
                curImage.bar = LuvColor
            else:
                print "****Error: invalid key '%s' in line '%s' in file '%s'" % (key, line, descFilename)
                sys.exit(1)
            continue
        # anything else is unexpected
        print "****Error: invalid line '%s' in file '%s'" % (line, descFilename)
        sys.exit(1)
    return ImageColorDict

#******************************************************************************
# main function for standard script execution
#

if __name__ == "__main__":
    global CocoLuvByRGB, CocoLuvByCMP
    print "DynoSprite Splash Image Builder script"
    # get input paths
    if len(sys.argv) != 4:
        print "****Usage: %s <in_png_folder> <out_cc3_folder> <out_asm_folder>" % sys.argv[0]
        sys.exit(1)
    imgdir = sys.argv[1]
    cc3dir = sys.argv[2]
    asmdir = sys.argv[3]
    # parse description file
    ImageColorDict = parseDescription(os.path.join(imgdir, "images.txt"))
    # make list of input image files found
    filelist = os.listdir(imgdir)
    imgPngFiles = [name for name in filelist if name[-4:].lower() == ".png"]
    imgPngFiles.sort()
    imgPngNumbers = [int(name[0:2]) for name in imgPngFiles]
    numImages = len(imgPngFiles)
    minNumber = min(imgPngNumbers)
    maxNumber = max(imgPngNumbers)
    print "    Found %i image files, numbered from %i to %i" % (numImages, minNumber, maxNumber)
    # Build Luv palettes for all of the colors in the Coco's 64-color palette for RGB and Composite modes
    BuildCocoColors()
    # read input images, extract metadata, and compress them
    allCompImageData = ""
    allImageSizes = [ ]     # each element is a tuple: (Width, Height, Compressed Bytes)
    for i in range(maxNumber+1):
        if i not in imgPngNumbers:
            allImageSizes.append((0, 0, 0))
            continue
        idx = imgPngNumbers.index(i)
        # create PIL Image object and get the resolution
        im = Image.open(os.path.join(imgdir, imgPngFiles[idx]))
        width = im.size[0]
        height = im.size[1]
        ImgData = im.getdata()
        # validate image parameters
        if (width & 1) != 0:
            print "Error: width of image '%s' is not divisible by 2." % imgPngFiles[idx]
            sys.exit(2)
        if im.mode != 'P':
            print "Error: image '%s' is not a palette (indexed color) image" % imgPngFiles[idx]
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
            print "Error: image '%s' uses more than 16 colors! (actual=%i)" % (imgPngFiles[idx], len(NewPalette))
            sys.exit(4)
        # generate palettes and palette mappings for both Composite and RGB mode on Coco
        (CMPPalette, RGBPalette, ImageToCocoMap) = GenerateCocoPalettes(NewPalette, im.palette.getdata()[1])
        # find indices for foreground/background colors as specified in text file
        if i not in ImageColorDict:
            print "Error: image '%s' missing in images.txt file!" % imgPngFiles[idx]
            sys.exit(5)
        SpecialColors = ImageColorDict[i]
        BKIdx = ClosestColorOf16(SpecialColors.back, CMPPalette, CocoLuvByCMP)
        FGIdx = ClosestColorOf16(SpecialColors.fore, CMPPalette, CocoLuvByCMP)
        BarIdx = ClosestColorOf16(SpecialColors.bar, CMPPalette, CocoLuvByCMP)
        SpecialColors.indices = (BKIdx, FGIdx, BarIdx)
        # generate packed pixel data (Coco format) of image
        CocoImgData = ""
        for i in range(0,width*height,2):
            lpix = ImageToCocoMap[ImgData[i]]
            rpix = ImageToCocoMap[ImgData[i+1]]
            CocoImgData += chr((lpix << 4) + rpix)
        # compress the Coco pixel data
        comp = Compressor(CocoImgData)
        compImgData = comp.Deflate(bPrintInfo=False, bUseGzip=True)
        allImageSizes.append((width, height, len(compImgData)))
        # put the palettes, special color indices, and compressed image data into our output stream
        for i in range(16):
            allCompImageData += chr(CMPPalette[i])
        for i in range(16):
            allCompImageData += chr(RGBPalette[i])
        allCompImageData += chr(BKIdx) + chr(FGIdx) + chr(BarIdx)
        allCompImageData += compImgData
        # print message
        print "    Image '%s'  width=%i  height=%i  compressed bytes=%i" % (imgPngFiles[idx], width, height, len(compImgData))
        print "        CMP Palette: " + " ".join([("%02i" % i) for i in CMPPalette])
        print "        RGB Palette: " + " ".join([("%02i" % i) for i in RGBPalette])
    # write out the data file
    f = open(os.path.join(cc3dir, "IMAGES.DAT"), "wb")
    f.write(allCompImageData)
    f.close()
    # write image directory table to include in DynoSprite core
    f = open(os.path.join(asmdir, "gamedir-images.asm"), "w")
    f.write("Gamedir_Images\n")
    s = str(maxNumber+1)
    f.write((" " * 24) + "fcb     " + s + (" " * (16 - len(s))) + "* number of splash images in directory\n")
    for i in range(maxNumber+1):
        if i not in imgPngNumbers:
            f.write((" " * 24) + ("* Image: %02i - [empty]\n" % i))
            f.write((" " * 24) + "fdb     " + "0,0\n")
            f.write((" " * 24) + "fcb     " + "0,0,0\n")
            continue
        idx = imgPngNumbers.index(i)
        SpecialColors = ImageColorDict[i]
        f.write((" " * 24) + ("* Image: %02i - %s\n" % (i, imgPngFiles[idx][3:-4])))
        s = str(allImageSizes[i][0] / 2)
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* width of image (in bytes)\n")
        s = str(allImageSizes[i][1])
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* height of image\n")
        s = str(allImageSizes[i][2])
        f.write((" " * 24) + "fdb     " + s + (" " * (16-len(s))) + "* Compressed size in bytes\n")
        """ The special color indices could alteratively be put in the Gamedir_Images instead of the file
        s = str(SpecialColors.indices[0])
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* Background color index\n")
        s = str(SpecialColors.indices[1])
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* Foreground color index\n")
        s = str(SpecialColors.indices[2])
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* Progress bar color index\n")
        """
    f.close()

