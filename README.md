# Production Ready Atmosphere Rendering

![Example Render](./Render.png)

An atmospheric scattering implementation based on a paper with the the same name, written by Sébastien Hillaire.

This Gigi render technique implements the entire pipeline described in "A Scalable and Production Ready Sky and Atmosphere Rendering Technique":
- Precomputed atmospheric transmittance based on "Precomputed Atmospheric Scattering" by Bruneton and Neyret.
- Multiple Scattering LUT
- Sky View LUT
- Aerial Perspective LUT

The Gigi technique exposes the Aerial Perspective LUT and color target containing the rendered sky.
These can be used by other techniques to shade geometry using atmospheric scattering.

IMPORTANT:

This implementation does not support aerial views of
earth-scale planets due to floating-point precision breaking down.

To get planet-scale atmosphere rendering, the planet surface
and atmosphere radii need to be reduced.

## License

This is an open-source implementation of the original paper under the MIT license. This implementation does not use any code of the original work.
