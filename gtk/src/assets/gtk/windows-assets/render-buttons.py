#!/usr/bin/env python3
"""Render GTK titlebutton PNGs for FluidSur: monochrome line icons, no traffic lights.

Fills all five asset directories the GTK installer can pick from:
  titlebutton            default,      standard palette
  titlebutton-alt        --alt,        standard palette
  titlebutton-alt-small  --alt small,  standard palette
  titlebutton-nord       --scheme nord
  titlebutton-alt-nord   --alt + nord

Each directory needs 4 icons x 5 states x light/dark x 1x/2x = 80 PNGs.
"""

import os
import cairo
import gi
gi.require_version("Rsvg", "2.0")
from gi.repository import Rsvg

ROOT = os.path.join(os.path.expanduser("~"), ".themes-src", "FluidSur-kde",
                    "gtk", "src", "assets", "gtk", "windows-assets")

W = H = 16

# variant dir -> (light stroke, dark stroke, stroke width, icon scale)
# The -alt directories keep their historically smaller glyph so the two
# installer styles still look different without either being a coloured dot.
VARIANTS = {
    "titlebutton":           ("#6e6e6e", "#d4d4d4", 1.35, 1.00),
    "titlebutton-alt":       ("#6e6e6e", "#d4d4d4", 1.25, 0.86),
    "titlebutton-alt-small": ("#6e6e6e", "#d4d4d4", 1.20, 0.76),
    # Nord palette: polar night for light, snow storm for dark.
    "titlebutton-nord":      ("#4c566a", "#d8dee9", 1.35, 1.00),
    "titlebutton-alt-nord":  ("#4c566a", "#d8dee9", 1.25, 0.86),
}

# Geometry in a 16x16 box, centred on (8,8) so scaling stays centred.
ICONS = {
    "close": '<path d="m5.2 5.2 5.6 5.6m0-5.6-5.6 5.6"/>',
    "minimize": '<path d="M4.4 8h7.2"/>',
    "maximize": '<rect x="4.7" y="4.7" width="6.6" height="6.6" rx="1"/>',
    # Front square low-left, back square's corner peeking out top-right.
    # The two must not touch or the glyph turns to mush at 16px.
    "restore": ('<path d="M4.6 6.8h4.9v4.7H4.6z"/>'
                '<path d="M7.2 4.6h4.2v4.2"/>'),
}

# state suffix -> glyph opacity.  "backdrop" is GTK's unfocused window.
STATES = {
    "": 1.0,
    "-backdrop": 0.45,
    "-backdrop-hover": 0.6,
    "-hover": 1.0,
    "-active": 1.0,
}

# Plate opacity behind the glyph, for click feedback.
PLATE = {"-hover": 0.11, "-backdrop-hover": 0.08, "-active": 0.2}

SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"
     viewBox="0 0 16 16">
{plate}  <g transform="translate({tx} {tx}) scale({scale})"
     fill="none" stroke="{stroke}" stroke-width="{sw}"
     stroke-linecap="round" stroke-linejoin="round" opacity="{opacity}">
    {icon}
  </g>
</svg>"""

PLATE_TAG = ('  <rect width="16" height="16" rx="4" fill="{colour}"'
             ' opacity="{opacity}"/>\n')


def build_svg(icon, stroke, sw, scale, opacity, plate_opacity):
    plate = ""
    if plate_opacity:
        plate = PLATE_TAG.format(colour=stroke, opacity=plate_opacity)
    # Keep the glyph centred while scaling about (8,8).
    tx = round(8 * (1 - scale), 4)
    # Compensate the stroke so a scaled-down glyph is not also thinner.
    return SVG.format(plate=plate, tx=tx, scale=scale, stroke=stroke,
                      sw=round(sw / scale, 4), opacity=opacity, icon=icon)


def render(svg_str, scale, out_path):
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, W * scale, H * scale)
    ctx = cairo.Context(surface)
    ctx.scale(scale, scale)
    handle = Rsvg.Handle.new_from_data(svg_str.encode("utf-8"))
    rect = Rsvg.Rectangle()
    rect.x, rect.y, rect.width, rect.height = 0, 0, W, H
    handle.render_document(ctx, rect)
    surface.write_to_png(out_path)


def main():
    total = 0
    for vdir, (light, dark, sw, gscale) in VARIANTS.items():
        dest = os.path.join(ROOT, vdir)
        os.makedirs(dest, exist_ok=True)
        for name, icon in ICONS.items():
            for state, opacity in STATES.items():
                for suffix, stroke in (("", light), ("-dark", dark)):
                    svg = build_svg(icon, stroke, sw, gscale, opacity,
                                    PLATE.get(state))
                    base = f"titlebutton-{name}{state}{suffix}"
                    for tag, factor in (("", 1), ("@2", 2)):
                        render(svg, factor,
                               os.path.join(dest, base + tag + ".png"))
                        total += 1
        print(f"  {vdir}: 80")
    print(f"{total} PNG written")


if __name__ == "__main__":
    main()
