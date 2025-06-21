This project has achieved a simple glass reflection and refraction effect based on urp.

Reflection: Create a CubeMap and sample the reflected color from the Cubemap.

Refraction: Create a rendererTexture, add a RefractCamera in the scene, and assign the created rendered Texture to the Target Texture of the camera. Here, the position of the RefractCamera needs to be consistent with that of the MainCamera in the scene. Sample and calculate the refraction of the created rendererTexture.

Finally, mix reflection and refraction.
