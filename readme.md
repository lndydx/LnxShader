# Lnx Shader

A Minecraft shader pack (Iris/OptiFine) featuring dynamic wetness & puddles, 
procedural night sky, screen-space reflections, volumetric-style god rays, 
lens flare, and wind-animated foliage.

Built on top of [null511](https://github.com/null511)'s shader template.

## Screenshots

### Night Sky & Reflections
<img width="1920" height="1080" alt="2026-07-20_13 52 38" src="https://github.com/user-attachments/assets/37131789-9f29-4f60-a523-449e1987f106" />
<img width="1920" height="1080" alt="2026-07-20_13 52 21" src="https://github.com/user-attachments/assets/f7518372-defe-4661-a976-34b2cced9966" />

### Puddles & Godrays
<img width="1920" height="1080" alt="2026-07-20_13 55 24" src="https://github.com/user-attachments/assets/eb888479-9c3b-46c9-b0b2-05ab96c980bb" />
<img width="1920" height="1080" alt="2026-07-20_13 54 26" src="https://github.com/user-attachments/assets/8ea4418f-6884-4f25-b340-8be7982d79b9" />

## Features

- Shadows with distortion, colored shadows (stained glass), and dynamic bias
- Screen-space reflections (SSR) on water, with denoise blur pass
- Rain wetness system — surface darkening + ripple puddles on flat/upward-facing blocks
- Procedural night sky: hand-placed constellations, galaxy band, twinkling stars
- Volumetric-style god rays (shadow-map raymarch) + anamorphic lens flare
- Wind-animated foliage (leaves, grass, vines, crops, dripleaf, litter)
- SSAO, bloom, auto exposure, ACES tonemap, color grading
- Nether & End dimension support *(work in progress — visuals still being tuned)*

## Requirements

- Minecraft with [Iris](https://irisshaders.dev/) or OptiFine
- Minecraft Java Edition 1.21.11

## Installation

1. Download the latest release / clone this repo
2. Drop the `Lnx` folder into `.minecraft/shaderpacks`
3. Select it in your shader pack menu

## Credits

- Based on the shader template by **null511 (Joshua Miller)**
- Lndydx

## License

 MIT — see [LICENSE](LICENSE). 
