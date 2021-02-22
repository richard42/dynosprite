import math

from wand.color import Color
from wand.drawing import Drawing
from wand.image import Image


def __GetCompositeColor(palidx):
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
        brightness += ((palidx // 16) + 1) * contrast
        offset = (palidx % 16) - 1 + (palidx // 16)*15
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


# Maps Color Computer 3 RGB palette value to corresponding CMP palette value
COCO_RGB_TO_CMP = [0, 13, 4, 14, 8, 9, 4, 16, 11, 27, 13, 27, 10, 27, 13, 27, 2, 2,
  34, 34, 2, 2, 34, 34, 30, 44, 33, 62, 30, 44, 33, 62, 7, 8, 5, 8, 22, 38, 38,
  38, 25, 26, 25, 42, 39, 41, 39, 41, 20, 20, 34, 34, 37, 37, 52, 52, 32, 43,
  33, 62, 38, 57, 52, 48]

# Maps Color Computer 3 CMP palette value to corresponding RGB palette value
COCO_CMP_TO_RGB = [0, 16, 16, 16, 6, 34, 32, 32, 33, 5, 12, 8, 8, 10, 3, 17, 7, 26,
  19, 20, 48, 34, 36, 35, 42, 40, 12, 9, 10, 25, 24, 21, 56, 58, 51, 50, 62,
  52, 60, 46, 45, 45, 43, 57, 29, 59, 27, 26, 63, 58, 62, 62, 62, 62, 60, 61,
  61, 61, 61, 57, 59, 59, 59, 63]


# Color Computer 3 RGB colors - Modified from Dynosprite
COCO_RGB_RGB8_COLORS = [
     (4, 3, 1),      (5, 8, 62),     (11, 54, 13),   (15, 69, 73),   (42, 2, 1),     (39, 7, 57),    (46, 56, 12),   (45, 64, 66), \
     (22, 28, 159),  (63, 65, 223),  (25, 70, 159),  (65, 103, 225), (53, 31, 157),  (84, 61, 221),  (57, 72, 155),  (88, 99, 224), \
     (42, 153, 51),  (52, 167, 106), (79, 208, 99),  (95, 220, 143), (69, 151, 54),  (74, 164, 100), (104, 206, 101),(111, 217, 138),\
     (45, 151, 170), (86, 171, 230), (77, 205, 186), (105, 215, 237),(73, 149, 169), (102, 170, 230),(99, 197, 180), (120, 213, 234),\
     (148, 11, 4),   (133, 12, 52),  (148, 63, 13),  (133, 60, 59),  (230, 32, 11),  (213, 23, 47),  (228, 74, 17),  (209, 64, 54),  \
     (135, 40, 159), (146, 62, 220), (136, 77, 161), (146, 92, 220), (214, 55, 156), (199, 66, 217), (212, 88, 160), (200, 93, 217), \
     (153, 154, 51), (144, 155, 86), (167, 210, 102),(158, 212, 125),(225, 161, 52), (204, 155, 78), (228, 213, 100),(208, 210, 114),\
     (139, 150, 166),(154, 163, 224),(151, 199, 178),(161, 209, 229),(211, 155, 167),(197, 155, 215),(211, 201, 177),(255, 255, 255)
]

# Color Computer 3 CMP colors
COCO_CMP_RGB8_COLORS = [
    __GetCompositeColor(ii) for ii in range(0, 64)
]

# Maps RGB8 colors to Color Computer 3 RGB colors
RGB8_TO_COCO_RGB_COLORS = {
    COCO_RGB_RGB8_COLORS[ii]: ii for ii in range(0, len(COCO_RGB_RGB8_COLORS))
}

# Maps RGB8 colors to Color Computer 3 CMP colors
RGB8_TO_COCO_CMP_COLORS = {
    COCO_CMP_RGB8_COLORS[ii]: ii for ii in range(0, len(COCO_CMP_RGB8_COLORS))
}


# Color used for transparency
COCO_TRANSPARENT_COLOR = (254, 0, 254)


def create_color_map_image(cmp=False, alpha=False):
  """
  Creates an Image that contains the entire Color Computer 3 palette.
  :param cmp: if False, generate an RGB color map. Otherwise generate a CMP
              color map.
  :param alpha: whether or not to include the transparent color
  """
  colors = COCO_CMP_RGB8_COLORS if cmp else COCO_RGB_RGB8_COLORS
  image = Image(
      width=len(colors) + (1 if alpha else 0),
      height=1,
  )
  with Drawing() as draw:
    for ii, color in enumerate(colors):
      draw.fill_color = Color('#{:02x}{:02x}{:02x}'.format(*color))
      draw.point(ii, 0)
    if alpha:
      draw.fill_color = Color('#{:02x}{:02x}{:02x}'.format(*COCO_TRANSPARENT_COLOR))
      draw.point(len(colors), 0)
    draw(image)
  return image


