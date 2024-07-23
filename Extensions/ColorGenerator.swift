//
// MIT License
//
// Copyright (c) 2023 Sophiestication Software
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import SwiftUI

extension Color {
    init(
        _ colorSpace: Color.RGBColorSpace = .displayP3,
        luminance: Double,
        chroma: Double,
        hue: Double,
        opacity: Double = 1.0)
    {
        let rgb = lch_to_rgb((luminance, chroma, hue))

        self.init(
            colorSpace,
            red: rgb.0 / 256.0,
            green: rgb.1 / 256.0,
            blue: rgb.2 / 256.0,
            opacity: opacity
        )
    }
}

//
// [CIELAB color space](https://en.wikipedia.org/wiki/CIELAB_color_space)
//      derived from [chroma.js](https://github.com/gka/chroma.js)
//
fileprivate let LabKn = 18 // Corresponds roughly to RGB brighter/darker

fileprivate let LabXYZ = ( // D65 standard
    Xn: 0.950470,
    Yn: 1.0,
    Zn: 1.088830
)

fileprivate let Labt = (
    0.137931034, // t0: 4 / 29
    0.206896552, // t1: // 6 / 29
    0.12841855, // t2: 3 * t1 * t1
    0.008856452 // t3: t1 * t1 * t1
)

fileprivate func lch_to_rgb(
    _ lch: (luminance: Double, chroma: Double, hue: Double)) -> (Double, Double, Double) {
    let lab = lch_to_lab((lch.luminance, lch.chroma, lch.hue))
    let rgb = lab_to_rgb(lab)
    return rgb
}

fileprivate func lch_to_lab(
    _ lch: (luminance: Double, chroma: Double, hue: Double)) -> (Double, Double, Double) {
    let l = lch.luminance
    let c = lch.chroma
    let h = lch.hue * (Double.pi / 180.0)
    
    return (l, cos(h) * c, sin(h) * c)
}

fileprivate func lab_to_rgb(_ lab: (L: Double, a: Double, b: Double)) -> (Double, Double, Double) {
    let L = lab.L
    let a = lab.a
    let b = lab.b
    
    var y = (L + 16) / 116
    var x = y + a / 500
    var z = y - b / 200
    
    y = LabXYZ.Yn * lab_xyz(y)
    x = LabXYZ.Xn * lab_xyz(x)
    z = LabXYZ.Zn * lab_xyz(z)
    
    let r = xyz_rgb(3.2404542 * x - 1.5371385 * y - 0.4985314 * z);  // D65 -> sRGB
    let g = xyz_rgb(-0.9692660 * x + 1.8760108 * y + 0.0415560 * z);
    let b_ = xyz_rgb(0.0556434 * x - 0.2040259 * y + 1.0572252 * z);
    
    return (r, g, b_)
}

fileprivate func xyz_rgb(_ r: Double) -> Double {
    255 * (r <= 0.00304 ? 12.92 * r : 1.055 * pow(r, 1 / 2.4) - 0.055)
}

fileprivate func lab_xyz(_ t: Double) -> Double {
    t > Labt.1 ? t * t * t : Labt.2 * (t - Labt.0)
}



struct ColorGenerator {

  static func color(from string: String, chroma: Double = 0.5, luminance: Double = 0.5) -> SwiftUICore.Color {
    let hash = hashString(string)
    let hue = Double(hash % 256) / 256.0
    return Color(luminance: luminance * 100.0, chroma: chroma * 100.0, hue: hue * 360.0, opacity: 1.0)  }

  private static func hashString(_ string: String) -> Int {
    return string.unicodeScalars.map { Int($0.value) }.reduce(0, +)
  }
}

