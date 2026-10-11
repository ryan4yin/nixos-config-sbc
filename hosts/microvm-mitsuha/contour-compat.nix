{
  nixpkgs.overlays = [
    (_: prev: {
      # Contour 0.6.3 uses SIMD TS APIs; GCC 16's <simd> implements the newer C++26 API.
      contour =
        if prev.stdenv.hostPlatform.isAarch64 && prev.contour.version == "0.6.3.8249" then
          prev.contour.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace src/vtbackend/Image.cpp \
                --replace-fail '#if __has_include(<simd>)' '#if 0'
            '';
          })
        else
          prev.contour;
    })
  ];
}
