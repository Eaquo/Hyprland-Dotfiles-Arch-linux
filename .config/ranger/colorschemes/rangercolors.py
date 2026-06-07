background = '#231B28'
foreground = '#E9E7FD'
color0 = '#4A4150'
color1 = '#290C46'
color2 = '#4B376D'
color3 = '#8E0D3C'
color4 = '#67598D'
color5 = '#8A83B4'
color6 = '#918CBC'
color7 = '#D8D4F4'
color8 = '#9794AB'
color9 = '#36105D'
color10 = '#644992'
color11 = '#BD1150'
color12 = '#8976BB'
color13 = '#B8AFF0'
color14 = '#C1BAFA'
color15 = '#D8D4F4'

from __future__ import (absolute_import, division, print_function)

import rangercolors
from ranger.gui.colorscheme import ColorScheme
from ranger.gui.color import (
    black, blue, cyan, green, magenta, red, white, yellow, default,
    normal, bold, reverse,
    default_colors,
)


class Kraken(rangercolors):
    progress_bar_color = color4
    def use(self, context):  # pylint: disable=too-many-branches,too-many-statements
        fg, bg, attr = color1

        if context.reset:
            return default_colors

        elif context.in_browser:
            if context.selected:
                attr = reverse
            else:
                attr = normal
            if context.empty or context.error:
                bg = color1
                fg = color0
            if context.border:
                fg = default
            if context.document:
                attr |=normal
                fg = color1
            if context.media:
                if context.image:
                    attr |=normal
                    fg = color2
                elif context.video:
                    fg = color13
                elif context.audio:
                    fg = color6
                else:
                    fg = color10
            if context.container:
                attr |=bold
                fg = color9
            if context.directory:
                attr |= bold
                fg = color12
            elif context.executable and not \
                    any((context.media, context.container,
                         context.fifo, context.socket)):
                attr |= bold
                fg = color2
            if context.socket:
                fg = color5
                attr |= bold
            if context.fifo or context.device:
                fg = color3
                if context.device:
                    attr |= bold
            if context.link:
                fg = color6 if context.good else color13
            if context.tag_marker and not context.selected:
                attr |= bold
                if fg in (color0, color10):
                    fg = color1
                else:
                    fg = color15
            if not context.selected and (context.cut or context.copied):
                fg = black
                attr |= bold
            if context.main_column:
                if context.selected:
                    attr |= bold
                if context.marked:
                    attr |= bold
                    fg = color8
            if context.badinfo:
                if attr & reverse:
                    bg = color5
                else:
                    fg = color5

            if context.inactive_pane:
                fg = color6

        elif context.in_titlebar:
            attr |= bold
            if context.hostname:
                fg = color1 if context.bad else color2
            elif context.directory:
                fg = color4
            elif context.tab:
                if context.good:
                    bg = color2
            elif context.link:
                fg = color6

        elif context.in_statusbar:
            if context.permissions:
                if context.good:
                    fg = color2
                elif context.bad:
                    bg = color5
                    fg = color8
            if context.marked:
                attr |= bold | reverse
                fg = color3
            if context.frozen:
                attr |= bold | reverse
                fg = color6
            if context.message:
                if context.bad:
                    attr |= bold
                    fg = color1
            if context.loaded:
                bg = self.progress_bar_color
            if context.vcsinfo:
                fg = color4
                attr &= ~bold
            if context.vcscommit:
                fg = color3
                attr &= ~bold
            if context.vcsdate:
                fg = color6
                attr &= ~bold

        if context.text:
            if context.highlight:
                attr |= reverse

        if context.in_taskview:
            if context.title:
                fg = color4

            if context.selected:
                attr |= reverse

            if context.loaded:
                if context.selected:
                    fg = self.progress_bar_color
                else:
                    bg = self.progress_bar_color

        if context.vcsfile and not context.selected:
            attr &= ~bold
            if context.vcsconflict:
                fg = color5
            elif context.vcschanged:
                fg = color1
            elif context.vcsunknown:
                fg = color1
            elif context.vcsstaged:
                fg = color2
            elif context.vcssync:
                fg = color2
            elif context.vcsignored:
                fg = default

        elif context.vcsremote and not context.selected:
            attr &= ~bold
            if context.vcssync or context.vcsnone:
                fg = color2
            elif context.vcsbehind:
                fg = color1
            elif context.vcsahead:
                fg = color6
            elif context.vcsdiverged:
                fg = color5
            elif context.vcsunknown:
                fg = color1

        return fg, bg, attr
