local Draw = require("Core/Draw")

local RGBA = Draw.RGBA

local Themes = {
    {
        Id = "default",
        Colors = {
            Background = RGBA(26, 26, 26, 245),
            BackgroundLight = RGBA(34, 34, 34, 245),
            Accent = RGBA(58, 110, 165),
            Text = RGBA(255, 255, 255),
            TextSoft = RGBA(255, 255, 255, 175),
            TextDisabled = RGBA(120, 140, 160),
            Border = RGBA(80, 90, 110),
            Overlay = RGBA(255, 255, 255)
        }
    },
    {
        Id = "nightcity",
        Colors = {
            Background = RGBA(12, 16, 26, 245),
            BackgroundLight = RGBA(20, 27, 42, 245),
            Accent = RGBA(0, 190, 255),
            Text = RGBA(232, 244, 255),
            TextSoft = RGBA(232, 244, 255, 175),
            TextDisabled = RGBA(105, 130, 160),
            Border = RGBA(40, 58, 86),
            Overlay = RGBA(190, 225, 255)
        }
    },
    {
        Id = "arasaka",
        Colors = {
            Background = RGBA(18, 12, 13, 245),
            BackgroundLight = RGBA(30, 19, 21, 245),
            Accent = RGBA(214, 38, 52),
            Text = RGBA(255, 238, 236),
            TextSoft = RGBA(255, 238, 236, 175),
            TextDisabled = RGBA(150, 108, 110),
            Border = RGBA(86, 46, 50),
            Overlay = RGBA(255, 220, 218)
        }
    },
    {
        Id = "militech",
        Colors = {
            Background = RGBA(21, 22, 19, 245),
            BackgroundLight = RGBA(31, 33, 28, 245),
            Accent = RGBA(228, 158, 42),
            Text = RGBA(242, 238, 226),
            TextSoft = RGBA(242, 238, 226, 175),
            TextDisabled = RGBA(140, 138, 116),
            Border = RGBA(74, 76, 62),
            Overlay = RGBA(245, 236, 212)
        }
    },
    {
        Id = "kangtao",
        Colors = {
            Background = RGBA(13, 21, 20, 245),
            BackgroundLight = RGBA(20, 32, 30, 245),
            Accent = RGBA(38, 204, 164),
            Text = RGBA(230, 250, 245),
            TextSoft = RGBA(230, 250, 245, 175),
            TextDisabled = RGBA(98, 146, 136),
            Border = RGBA(38, 78, 70),
            Overlay = RGBA(200, 255, 238)
        }
    },
    {
        Id = "afterlife",
        Colors = {
            Background = RGBA(19, 13, 25, 245),
            BackgroundLight = RGBA(30, 20, 39, 245),
            Accent = RGBA(226, 62, 196),
            Text = RGBA(250, 240, 255),
            TextSoft = RGBA(250, 240, 255, 175),
            TextDisabled = RGBA(146, 116, 166),
            Border = RGBA(74, 50, 92),
            Overlay = RGBA(240, 218, 255)
        }
    },
    {
        Id = "netrunner",
        Colors = {
            Background = RGBA(9, 13, 10, 245),
            BackgroundLight = RGBA(15, 22, 16, 245),
            Accent = RGBA(118, 250, 96),
            Text = RGBA(222, 255, 216),
            TextSoft = RGBA(222, 255, 216, 175),
            TextDisabled = RGBA(98, 148, 100),
            Border = RGBA(38, 72, 42),
            Overlay = RGBA(200, 255, 190)
        }
    },
    {
        Id = "badlands",
        Colors = {
            Background = RGBA(25, 19, 15, 245),
            BackgroundLight = RGBA(37, 28, 21, 245),
            Accent = RGBA(238, 116, 46),
            Text = RGBA(255, 242, 228),
            TextSoft = RGBA(255, 242, 228, 175),
            TextDisabled = RGBA(166, 134, 108),
            Border = RGBA(94, 68, 50),
            Overlay = RGBA(255, 232, 210)
        }
    },
    {
        Id = "corpo",
        Colors = {
            Background = RGBA(17, 19, 25, 245),
            BackgroundLight = RGBA(26, 29, 38, 245),
            Accent = RGBA(212, 172, 82),
            Text = RGBA(244, 242, 234),
            TextSoft = RGBA(244, 242, 234, 175),
            TextDisabled = RGBA(128, 134, 150),
            Border = RGBA(64, 70, 86),
            Overlay = RGBA(238, 232, 216)
        }
    },
    {
        Id = "neon",
        Colors = {
            Background = RGBA(20, 14, 34, 245),
            BackgroundLight = RGBA(31, 22, 50, 245),
            Accent = RGBA(255, 84, 156),
            Text = RGBA(250, 240, 255),
            TextSoft = RGBA(250, 240, 255, 175),
            TextDisabled = RGBA(148, 124, 184),
            Border = RGBA(76, 58, 108),
            Overlay = RGBA(235, 214, 255)
        }
    },
    {
        Id = "monochrome",
        Colors = {
            Background = RGBA(16, 16, 16, 245),
            BackgroundLight = RGBA(27, 27, 27, 245),
            Accent = RGBA(232, 232, 232),
            Text = RGBA(255, 255, 255),
            TextSoft = RGBA(255, 255, 255, 170),
            TextDisabled = RGBA(128, 128, 128),
            Border = RGBA(66, 66, 66),
            Overlay = RGBA(255, 255, 255)
        }
    },
    {
        Id = "david",
        Group = "season1",
        Colors = {
            Background = RGBA(16, 16, 18, 245),
            BackgroundLight = RGBA(27, 27, 30, 245),
            Accent = RGBA(255, 206, 46),
            Text = RGBA(255, 250, 235),
            TextSoft = RGBA(255, 250, 235, 175),
            TextDisabled = RGBA(96, 176, 166),
            Border = RGBA(52, 92, 88),
            Overlay = RGBA(255, 244, 210)
        }
    },
    {
        Id = "lucy",
        Group = "season1",
        Colors = {
            Background = RGBA(17, 14, 30, 245),
            BackgroundLight = RGBA(28, 24, 48, 245),
            Accent = RGBA(122, 236, 226),
            Text = RGBA(240, 240, 255),
            TextSoft = RGBA(240, 240, 255, 175),
            TextDisabled = RGBA(156, 136, 192),
            Border = RGBA(66, 56, 104),
            Overlay = RGBA(226, 220, 255)
        }
    },
    {
        Id = "rebecca",
        Group = "season1",
        Colors = {
            Background = RGBA(15, 14, 17, 245),
            BackgroundLight = RGBA(26, 23, 29, 245),
            Accent = RGBA(84, 236, 172),
            Text = RGBA(240, 255, 248),
            TextSoft = RGBA(240, 255, 248, 175),
            TextDisabled = RGBA(214, 112, 156),
            Border = RGBA(86, 48, 72),
            Overlay = RGBA(214, 255, 236)
        }
    },
    {
        Id = "talia",
        Group = "season2",
        Colors = {
            Background = RGBA(21, 23, 27, 245),
            BackgroundLight = RGBA(33, 36, 42, 245),
            Accent = RGBA(255, 118, 186),
            Text = RGBA(244, 246, 250),
            TextSoft = RGBA(244, 246, 250, 175),
            TextDisabled = RGBA(150, 156, 170),
            Border = RGBA(82, 88, 100),
            Overlay = RGBA(255, 228, 242)
        }
    },
    {
        Id = "d",
        Group = "season2",
        Colors = {
            Background = RGBA(11, 15, 28, 245),
            BackgroundLight = RGBA(19, 25, 44, 245),
            Accent = RGBA(226, 50, 62),
            Text = RGBA(232, 238, 255),
            TextSoft = RGBA(232, 238, 255, 175),
            TextDisabled = RGBA(108, 124, 164),
            Border = RGBA(40, 52, 88),
            Overlay = RGBA(205, 218, 255)
        }
    },
    {
        Id = "kingsley",
        Group = "season2",
        Colors = {
            Background = RGBA(25, 21, 19, 245),
            BackgroundLight = RGBA(37, 31, 27, 245),
            Accent = RGBA(244, 206, 118),
            Text = RGBA(255, 247, 234),
            TextSoft = RGBA(255, 247, 234, 175),
            TextDisabled = RGBA(170, 148, 122),
            Border = RGBA(98, 82, 64),
            Overlay = RGBA(255, 238, 212)
        }
    },
    {
        Id = "roman",
        Group = "season2",
        Colors = {
            Background = RGBA(20, 19, 17, 245),
            BackgroundLight = RGBA(32, 30, 27, 245),
            Accent = RGBA(140, 206, 96),
            Text = RGBA(248, 246, 236),
            TextSoft = RGBA(248, 246, 236, 175),
            TextDisabled = RGBA(196, 176, 120),
            Border = RGBA(78, 74, 60),
            Overlay = RGBA(240, 248, 220)
        }
    }
}

return Themes
